#!/usr/bin/env bash
# BACKEND — git verbs (cmd_*) that run where the store lives: on the box over
# ssh (shared), or in-process (WT_BACKEND=1; tests today, local mode in M2).
# These operate purely on $ROOT / $REPOS / $WORK with `git -C`.

_canon(){ printf '%s' "$REPOS/$1"; }
_default_branch(){ local b; b=$(git -C "$(_canon "$1")" symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null); b=${b#origin/}; printf '%s' "${b:-main}"; }
_repos_all(){ for d in "$REPOS"/*/; do [ -d "${d}.git" ] && basename "$d"; done; }
_ensure_relpaths(){ git -C "$(_canon "$1")" config worktree.useRelativePaths true 2>/dev/null; }
_is_agent(){ echo " $VALID_AGENTS " | grep -q " $1 "; }
_pick_city(){ local dir="$WORK/$1/$2" arr n c t=0; arr=($CITIES); n=${#arr[@]}
  while [ $t -lt 300 ]; do c=${arr[$((RANDOM % n))]}; [ -e "$dir/$c" ] || { printf '%s' "$c"; return 0; }; t=$((t+1)); done
  printf '%s%s' "${arr[$((RANDOM % n))]}" "$RANDOM"; }
cmd_repos(){ _repos_all; }
cmd_worktrees(){ local r d
  for r in $(_repos_all); do d=$(_canon "$r")
    git -C "$d" worktree list --porcelain 2>/dev/null | awk '/^worktree /{print $2}' | while read -r wt; do
      case "$wt" in "$WORK"/*) ;; *) continue;; esac; [ -e "$wt/.git" ] || continue
      local rel=${wt#"$WORK"/} ag city; ag=${rel%%/*}; city=${rel##*/}; _is_agent "$ag" || continue
      printf '%s\t%s\t%s\t%s\t%s\n' "$ag" "$r" "$city" "$wt" "$(git -C "$wt" branch --show-current 2>/dev/null)"
    done; done; }
cmd_new(){ local agent="${1:-}" repo="${2:-}" feature="${3:-}"
  [ -n "$agent" ] && [ -n "$repo" ] || die "usage: new <agent> <repo> [feature]"
  local d; d=$(_canon "$repo"); [ -d "${d}/.git" ] || die "no canonical repo: $repo"; _ensure_relpaths "$repo"
  local city; city=$(_pick_city "$agent" "$repo"); local feat="${feature:-$city}" branch="$agent/${feature:-$city}" wtdir="$WORK/$agent/$repo/$city"
  # New feature branches should not track the default branch. Tracking is set
  # when the user first pushes their feature branch with `git push -u`.
  mkdir -p "$(dirname "$wtdir")"; git -C "$d" worktree add -b "$branch" --no-track "$wtdir" "origin/$(_default_branch "$repo")" >&2 || die "worktree add failed"
  local ex; ex=$(git -C "$wtdir" rev-parse --git-path info/exclude 2>/dev/null)
  [ -n "$ex" ] && for cdir in $CACHE_DIRS; do grep -qxF "/$cdir" "$ex" 2>/dev/null || printf '/%s\n' "$cdir" >> "$ex"; done
  printf 'workspace: %s\nbranch: %s\ncity: %s\n' "$wtdir" "$branch" "$city"; }
cmd_rename(){ local wt="${1:-}" feature="${2:-}"; [ -n "$wt" ] && [ -n "$feature" ] || die "usage: rename <path> <feature>"
  case "$wt" in "$WORK"/*) ;; *) die "not a wt worktree: $wt";; esac; [ -e "$wt/.git" ] || die "not a worktree: $wt"
  local rel=${wt#"$WORK"/} agent repo; agent=${rel%%/*}; repo=$(printf '%s' "$rel" | cut -d/ -f2); _is_agent "$agent" || die "not a wt-managed worktree"
  feature=$(printf '%s' "$feature" | tr ' ' '-' | tr '[:upper:]' '[:lower:]'); local oldbr newbr="$agent/$feature"; oldbr=$(git -C "$wt" branch --show-current 2>/dev/null)
  [ "$oldbr" = "$newbr" ] && { printf 'branch already %s\n' "$newbr"; return 0; }
  git -C "$(_canon "$repo")" branch -m "$oldbr" "$newbr" || die "branch rename failed"; printf 'renamed: %s -> %s\n' "$oldbr" "$newbr"; }
cmd_clone(){ local spec="${1:-}"; [ -n "$spec" ] || die "usage: clone <owner/repo>"; local url repo
  case "$spec" in http*|git@*) url=$spec; repo=$(basename "$spec");; */*) url="https://github.com/$spec.git"; repo=$(basename "$spec");; *) url="https://github.com/$DEFAULT_ORG/$spec.git"; repo=$spec;; esac
  repo=${repo%.git}; local dest="$REPOS/$repo"; [ -e "$dest" ] && die "already have repos/$repo"
  git clone --progress "$url" "$dest" >&2 || die "clone failed (auth or url?)"
  git -C "$dest" remote set-head origin -a >/dev/null 2>&1; git -C "$dest" config worktree.useRelativePaths true
  printf 'cloned: %s (default %s)\n' "$repo" "$(_default_branch "$repo")"; }
cmd_delrepo(){ local repo="${1:-}" force="${2:-}"; [ -n "$repo" ] || die "usage: delrepo <repo>"
  local d; d=$(_canon "$repo"); [ -d "${d}/.git" ] || die "no canonical repo: $repo"; local risky=0 wt
  for wt in $(git -C "$d" worktree list --porcelain 2>/dev/null | awk '/^worktree /{print $2}'); do
    [ "$wt" = "$d" ] && continue; [ -e "$wt/.git" ] || continue
    local dirty unpushed; dirty=$(git -C "$wt" status --porcelain 2>/dev/null | wc -l | tr -d ' '); unpushed=$(git -C "$wt" log --branches --not --remotes --oneline 2>/dev/null | wc -l | tr -d ' ')
    if [ "$dirty" != 0 ] || [ "$unpushed" != 0 ]; then risky=$((risky+1)); printf '  at-risk: %s (dirty=%s unpushed=%s)\n' "${wt#"$WORK"/}" "$dirty" "$unpushed"; fi; done
  if [ "$risky" -gt 0 ] && [ "$force" != "--force" ]; then printf 'REFUSED: %s worktree(s) hold uncommitted/unpushed work\n' "$risky"; return 3; fi
  for wt in $(git -C "$d" worktree list --porcelain 2>/dev/null | awk '/^worktree /{print $2}'); do [ "$wt" = "$d" ] && continue; git -C "$d" worktree remove --force "$wt" 2>/dev/null; rm -rf "$wt" 2>/dev/null; done
  rm -rf "$d"; printf 'deleted repo: %s\n' "$repo"; }
cmd_sync(){ local target="${1:---all}" repos; if [ "$target" = "--all" ]; then repos=$(_repos_all); else repos="$target"; fi
  for r in $repos; do local d; d=$(_canon "$r"); [ -d "${d}/.git" ] || { warn "skip $r (no canonical)"; continue; }
    if git -C "$d" fetch --all --prune --quiet 2>/dev/null; then git -C "$d" remote set-head origin -a >/dev/null 2>&1; git -C "$d" maintenance run --auto --quiet 2>/dev/null; ok "synced $r"; else err "failed $r (auth?)"; fi; done; }
cmd_clean(){ local force="${1:-}"
  for r in $(_repos_all); do local d; d=$(_canon "$r"); git -C "$d" fetch --prune --quiet 2>/dev/null || { warn "skip $r (fetch failed)"; continue; }
    git -C "$d" worktree list --porcelain 2>/dev/null | awk '/^worktree /{print $2}' | while read -r wt; do
      case "$wt" in "$WORK"/*) ;; *) continue;; esac; local rel=${wt#"$WORK"/}; _is_agent "${rel%%/*}" || continue
      if [ ! -e "$wt/.git" ]; then printf '  %sorphan%s   %s\n' "$YEL" "$N" "$wt"; [ "$force" = "--yes" ] && rm -rf "$wt"; continue; fi
      [ -n "$(git -C "$wt" status --porcelain 2>/dev/null)" ] && continue
      local br up_remote up_merge rc unpushed; br=$(git -C "$wt" branch --show-current 2>/dev/null)
      up_remote=$(git -C "$wt" config --get "branch.$br.remote" 2>/dev/null || true)
      up_merge=$(git -C "$wt" config --get "branch.$br.merge" 2>/dev/null || true)
      # A new worktree starts from origin/main but must never be treated as a
      # deleted feature branch. Only branches that explicitly track themselves
      # on origin are cleanup candidates.
      [ "$up_remote" = origin ] && [ "$up_merge" = "refs/heads/$br" ] || continue
      git -C "$d" ls-remote --exit-code --heads origin "$br" >/dev/null 2>&1; rc=$?
      if [ "$rc" = 2 ]; then
        # A disappeared remote does not prove there is no local-only work
        # (for example after a squash merge followed by more local commits).
        unpushed=$(git -C "$wt" log "$br" --not --remotes --oneline 2>/dev/null | wc -l | tr -d ' ')
        if [ "$unpushed" != 0 ]; then
          printf '  %sskip%s     %s %s(%s local-only commit(s))%s\n' "$YEL" "$N" "$wt" "$DIM" "$unpushed" "$N"
          continue
        fi
        printf '  %sremote gone%s  %s %s(%s)%s\n' "$GRN" "$N" "$wt" "$DIM" "$br" "$N"
        [ "$force" = "--yes" ] && git -C "$d" worktree remove --force "$wt" && git -C "$d" branch -D "$br" >/dev/null 2>&1 && printf '%s  removed %s (%s)\n' "$(date '+%F %T')" "$wt" "$br" >> "$LOGDIR/wt-clean.log" 2>/dev/null
      fi
    done; done; [ "$force" = "--yes" ] || printf '  %s(dry run — wt clean --yes to remove)%s\n' "$DIM" "$N"; }
# archive: remove the worktree FOLDER but KEEP the branch (Conductor-style — restorable).
cmd_archive(){ local wt="${1:-}" force="${2:-}"; [ -n "$wt" ] || die "usage: archive <path>"; case "$wt" in "$WORK"/*) ;; *) die "refusing: not under workspaces/";; esac
  local rel=${wt#"$WORK"/}; _is_agent "${rel%%/*}" || die "not a wt-managed worktree"; [ -e "$wt/.git" ] || die "not a worktree: $wt"
  [ -n "$(git -C "$wt" status --porcelain 2>/dev/null)" ] && [ "$force" != "--yes" ] && { printf 'DIRTY: uncommitted changes — commit first, or archive --yes to discard them\n'; return 3; }
  local repo; repo=$(printf '%s' "$rel" | cut -d/ -f2); local br; br=$(git -C "$wt" branch --show-current 2>/dev/null)
  git -C "$(_canon "$repo")" worktree remove --force "$wt" || die "worktree remove failed"; printf 'archived: %s\n' "$br"; }
# archived: branches with an agent prefix that have NO worktree (the "archive" list).
cmd_archived(){ local r d
  for r in $(_repos_all); do d=$(_canon "$r")
    local checked; checked=$(git -C "$d" worktree list --porcelain 2>/dev/null | awk '/^branch /{sub("refs/heads/","",$2); print $2}')
    git -C "$d" for-each-ref --format='%(refname:short)' refs/heads 2>/dev/null | while read -r br; do
      _is_agent "${br%%/*}" || continue; printf '%s\n' "$checked" | grep -qxF "$br" && continue
      printf '%s\t%s\t%s\t%s\n' "${br%%/*}" "$r" "$br" "$(git -C "$d" log -1 --format='%cr' "$br" 2>/dev/null)"
    done; done; }
# restore: recreate a worktree on an EXISTING (archived) branch, in a fresh city folder.
cmd_restore(){ local repo="${1:-}" branch="${2:-}"; [ -n "$repo" ] && [ -n "$branch" ] || die "usage: restore <repo> <branch>"
  local d; d=$(_canon "$repo"); [ -d "${d}/.git" ] || die "no canonical repo: $repo"
  git -C "$d" show-ref --verify --quiet "refs/heads/$branch" || die "no such branch: $branch"
  local agent=${branch%%/*}; _is_agent "$agent" || die "not an agent branch: $branch"; _ensure_relpaths "$repo"
  local city; city=$(_pick_city "$agent" "$repo"); local wtdir="$WORK/$agent/$repo/$city"
  mkdir -p "$(dirname "$wtdir")"; git -C "$d" worktree add "$wtdir" "$branch" >&2 || die "worktree add failed"
  local ex; ex=$(git -C "$wtdir" rev-parse --git-path info/exclude 2>/dev/null)
  [ -n "$ex" ] && for cdir in $CACHE_DIRS; do grep -qxF "/$cdir" "$ex" 2>/dev/null || printf '/%s\n' "$cdir" >> "$ex"; done
  printf 'workspace: %s\nbranch: %s\ncity: %s\n' "$wtdir" "$branch" "$city"; }
# rmbranch: permanently delete an ARCHIVED branch (must have no worktree).
cmd_rmbranch(){ local repo="${1:-}" branch="${2:-}"; [ -n "$repo" ] && [ -n "$branch" ] || die "usage: rmbranch <repo> <branch>"
  local d; d=$(_canon "$repo"); [ -d "${d}/.git" ] || die "no canonical repo: $repo"; _is_agent "${branch%%/*}" || die "not an agent branch: $branch"
  git -C "$d" worktree list --porcelain 2>/dev/null | awk '/^branch /{sub("refs/heads/","",$2); print $2}' | grep -qxF "$branch" && die "branch is active (worktree exists) — archive it first"
  git -C "$d" branch -D "$branch" >/dev/null 2>&1 && printf 'removed branch: %s\n' "$branch" || die "branch delete failed"; }
cmd_list(){ local rows; rows=$(cmd_worktrees)
  printf '  %s%-8s %-12s %-22s %-6s %-9s %s%s\n' "$W" AGENT REPO FEATURE DIRTY AHD/BEH CITY "$N"
  [ -z "$rows" ] && { printf '  %sno worktrees yet — try: wt new%s\n' "$DIM" "$N"; return; }
  printf '%s\n' "$rows" | while IFS=$'\t' read -r ag repo city wt br; do local base; base=$(_default_branch "$repo")
    local feat dv dc dcell ab; feat=${br#*/}; [ ${#feat} -gt 22 ] && feat="${feat:0:20}.."
    if [ -n "$(git -C "$wt" status --porcelain 2>/dev/null)" ]; then dv=yes; dc=$YEL; else dv="-"; dc=$DIM; fi; printf -v dcell '%-6s' "$dv"
    ab=$(git -C "$wt" rev-list --left-right --count "origin/$base...HEAD" 2>/dev/null | awk '{printf "+%s/-%s",$2,$1}')
    printf '  %s%-8s%s %-12s %s%-22s%s %s%s%s %-9s %s%s%s\n' "$GRN" "$ag" "$N" "$repo" "$W" "$feat" "$N" "$dc" "$dcell" "$N" "${ab:-?}" "$DIM" "$city" "$N"; done; }
cmd_status(){ local n; n=$(cmd_worktrees | wc -l | tr -d ' '); printf 'worktrees: %s\ncanonicals:\n' "$n"
  local r; for r in $(_repos_all); do printf '  %-14s %s\n' "$r" "$(git -C "$(_canon "$r")" log -1 --format='%h %cr' 2>/dev/null)"; done
  printf 'disk: %s\n' "$(df -h "$ROOT" 2>/dev/null | awk 'NR==2{print $3" used / "$2}')"; }
cmd_doctor(){ local r first missing=0; first=$(_repos_all | head -1)
  if [ -n "$first" ] && git -C "$(_canon "$first")" ls-remote origin >/dev/null 2>&1; then ok "GitHub auth (PAT) valid"; else err "GitHub auth failing — re-run: sudo /usr/local/sbin/set-agents-token"; fi
  local t; for t in wt-sync wt-clean; do systemctl is-active "$t.timer" >/dev/null 2>&1 && ok "$t.timer active" || err "$t.timer inactive"; done
  for r in $(_repos_all); do [ "$(git -C "$(_canon "$r")" config --get worktree.useRelativePaths 2>/dev/null)" = true ] || { err "relpaths off: $r"; missing=1; }; done
  [ "$missing" = 0 ] && ok "relative worktrees set on all canonicals"; }

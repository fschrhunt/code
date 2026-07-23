#!/usr/bin/env bash
# BACKEND — git verbs (cmd_*) that run where the store lives: on the box over
# ssh (shared), or in-process (local profile / WT_BACKEND=1).
# These operate purely on $ROOT / $REPOS / $WORK with `git -C`.

# Repo folder names stay inside $REPOS — no slashes, no "." / "..".
_repo_name_ok(){
  case "$1" in
    ""|"."|".."|*/*|*\\*) return 1;;
    *[!A-Za-z0-9._-]*) return 1;;
  esac
  return 0
}
_canon(){
  _repo_name_ok "$1" || die "invalid repo name '$1'"
  # REPOS is assigned in config.sh (linted as a separate top-level file).
  # shellcheck disable=SC2153
  printf '%s' "$REPOS/$1"
}
# Last path segment of a clone URL/spec (https, git@host:owner/repo, owner/repo).
_clone_repo_name(){
  local spec=$1 name
  name=$(printf '%s' "$spec" | sed 's#\.git$##')
  name=$(printf '%s' "$name" | sed 's#.*[:/]##')
  printf '%s' "$name"
}
_prog(){ printf 'wt-progress:%s:%s\n' "$1" "$2" >&2; }
_default_branch(){ local b; b=$(git -C "$(_canon "$1")" symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null); b=${b#origin/}; printf '%s' "${b:-main}"; }
_repos_all(){ for d in "$REPOS"/*/; do [ -d "${d}.git" ] && basename "$d"; done; }
_ensure_relpaths(){ git -C "$(_canon "$1")" config worktree.useRelativePaths true 2>/dev/null; }

# Wider than $RANDOM alone (15-bit) so sampling ~1e5 cities stays uniform.
_city_rand(){ printf '%s' $(( (RANDOM << 15 | RANDOM) & 0x3FFFFFFF )); }

# Procedural place-name fallback when the world list is missing or exhausted.
_gen_city_name(){
  local -a pre=(al an ar ba be bi bo bra bri ca chi co da de do el fa fi ga ge go
    ha he hi ho ka ke ki ko ku la le li lo lu ma me mi mo na ne ni no pa pe
    pi po ra re ri ro sa se shi so su ta te ti to tu va ve vi wa ya yo za)
  local -a mid=(ba be bi bo da de di do ga ge gi go ka ke ki ko la le li lo
    ma me mi mo na ne ni no pa pe pi po ra re ri ro sa se si so ta te ti to
    va ve vi)
  local -a suf=(ba city dale don ford grad ham ia in ka ki la land ley
    lin nia pol porto ra rid ski stan ton town ville ya)
  local p m s
  p=${pre[$(( $(_city_rand) % ${#pre[@]} ))]}
  m=${mid[$(( $(_city_rand) % ${#mid[@]} ))]}
  s=${suf[$(( $(_city_rand) % ${#suf[@]} ))]}
  printf '%s%s%s' "$p" "$m" "$s"
}

# Unique folder label under $WORK/<agent>/<repo>/. Samples lib/cities.txt
# (world place names); on collision exhaustion, syllable names, then a suffix.
_pick_city(){
  local dir="$WORK/$1/$2"
  local file="${WT_LIB:-}/cities.txt"
  local n c t=0 idx
  if [ -f "$file" ]; then
    n=$(wc -l < "$file" | tr -d '[:space:]')
    if [ "${n:-0}" -gt 0 ] 2>/dev/null; then
      while [ "$t" -lt 64 ]; do
        idx=$(( $(_city_rand) % n + 1 ))
        c=$(awk -v n="$idx" 'NR==n{print; exit}' "$file")
        [ -n "$c" ] && [ ! -e "$dir/$c" ] && { printf '%s' "$c"; return 0; }
        t=$((t + 1))
      done
    fi
  fi
  t=0
  while [ "$t" -lt 64 ]; do
    c=$(_gen_city_name)
    [ ! -e "$dir/$c" ] && { printf '%s' "$c"; return 0; }
    t=$((t + 1))
  done
  printf '%s%s' "$(_gen_city_name)" "$(_city_rand)"
}
cmd_repos(){ _repos_all; }
cmd_worktrees(){ local r d
  for r in $(_repos_all); do d=$(_canon "$r")
    git -C "$d" worktree list --porcelain 2>/dev/null | awk '/^worktree /{print $2}' | while read -r wt; do
      case "$wt" in "$WORK"/*) ;; *) continue;; esac; [ -e "$wt/.git" ] || continue
      local rel=${wt#"$WORK"/} ag city; ag=${rel%%/*}; city=${rel##*/}; _is_agent "$ag" || continue
      printf '%s\t%s\t%s\t%s\t%s\n' "$ag" "$r" "$city" "$wt" "$(git -C "$wt" branch --show-current 2>/dev/null)"
    done; done; }
cmd_new(){ local agent="${1:-}" repo="${2:-}" feature="${3:-}"
  [ -n "$agent" ] && [ -n "$repo" ] && [ -n "$feature" ] || die "usage: new <agent> <repo> <feature>"
  _is_agent "$agent" || die "unknown agent '$agent' — configure with: wt agents add $agent"
  feature=$(printf '%s' "$feature" | tr ' ' '-' | tr '[:upper:]' '[:lower:]')
  local d; d=$(_canon "$repo")
  [ -d "${d}/.git" ] || die "no repo '$repo' — clone first: wt clone owner/repo"
  _ensure_relpaths "$repo"
  local city branch="$agent/$feature" wtdir existing
  # Archive keeps the branch; reuse needs restore, not a second -b create.
  if git -C "$d" show-ref --verify --quiet "refs/heads/$branch" 2>/dev/null; then
    existing=$(git -C "$d" worktree list --porcelain 2>/dev/null | awk -v want="refs/heads/$branch" '
      /^worktree /{wt=$2; next}
      /^branch /{ if ($2==want) { print wt; exit } }
    ')
    if [ -n "$existing" ]; then
      die "branch '$branch' is already active at $existing"
    fi
    die "branch '$branch' is archived — restore with: wt restore $repo $branch"
  fi
  city=$(_pick_city "$agent" "$repo"); wtdir="$WORK/$agent/$repo/$city"
  # New feature branches should not track the default branch. Tracking is set
  # when the user first pushes their feature branch with `git push -u`.
  mkdir -p "$(dirname "$wtdir")"
  git -C "$d" worktree add -b "$branch" --no-track "$wtdir" "origin/$(_default_branch "$repo")" >&2 || die "worktree add failed"
  local ex; ex=$(git -C "$wtdir" rev-parse --git-path info/exclude 2>/dev/null)
  [ -n "$ex" ] && for cdir in $CACHE_DIRS; do grep -qxF "/$cdir" "$ex" 2>/dev/null || printf '/%s\n' "$cdir" >> "$ex"; done
  printf 'workspace: %s\nbranch: %s\ncity: %s\n' "$wtdir" "$branch" "$city"; }
cmd_rename(){ local wt="${1:-}" feature="${2:-}"; [ -n "$wt" ] && [ -n "$feature" ] || die "usage: rename <path> <feature>"
  case "$wt" in "$WORK"/*) ;; *) die "not a wt worktree: $wt";; esac; [ -e "$wt/.git" ] || die "not a worktree: $wt"
  local rel=${wt#"$WORK"/} agent repo; agent=${rel%%/*}; repo=$(printf '%s' "$rel" | cut -d/ -f2); _is_agent "$agent" || die "not a wt-managed worktree"
  feature=$(printf '%s' "$feature" | tr ' ' '-' | tr '[:upper:]' '[:lower:]'); local oldbr newbr="$agent/$feature"; oldbr=$(git -C "$wt" branch --show-current 2>/dev/null)
  [ "$oldbr" = "$newbr" ] && { printf 'branch already %s\n' "$newbr"; return 0; }
  git -C "$(_canon "$repo")" branch -m "$oldbr" "$newbr" || die "branch rename failed"; printf 'renamed: %s -> %s\n' "$oldbr" "$newbr"; }
cmd_clone(){ local spec="${1:-}"; [ -n "$spec" ] || die "usage: clone <owner/repo|url|path>"; local url repo
  case "$spec" in
    http*|git@*|file://*) url=$spec; repo=$(_clone_repo_name "$spec");;
    *)
      # Existing local paths (absolute/relative/bare) pass through to git clone.
      if [ -e "$spec" ]; then
        url=$spec; repo=$(_clone_repo_name "$spec")
      else
        case "$spec" in
          */*) url="https://github.com/$spec.git"; repo=$(_clone_repo_name "$spec");;
          *)
            [ -n "$DEFAULT_ORG" ] || die "no default org — pass owner/repo, or set default_org in ~/.wt/config"
            url="https://github.com/$DEFAULT_ORG/$spec.git"; repo=$spec
            ;;
        esac
      fi
      ;;
  esac
  _repo_name_ok "$repo" || die "invalid repo name '$repo'"
  local dest="$REPOS/$repo"; [ -e "$dest" ] && die "already have repos/$repo"
  git clone --progress "$url" "$dest" >&2 || die "clone failed (auth or url?)"
  git -C "$dest" remote set-head origin -a >/dev/null 2>&1; git -C "$dest" config worktree.useRelativePaths true
  printf 'cloned: %s (default %s)\n' "$repo" "$(_default_branch "$repo")"; }
cmd_delrepo(){
  local repo="" force=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --force|-f) force=--force; shift;;
      --yes|-y) shift;; # CLI parity with frontend; no soft confirm on backend
      -*) die "unknown flag: $1 (usage: delrepo <repo> [--force])";;
      *) [ -z "$repo" ] || die "usage: delrepo <repo> [--force]"; repo=$1; shift;;
    esac
  done
  [ -n "$repo" ] || die "usage: delrepo <repo> [--force]"
  local d; d=$(_canon "$repo"); [ -d "${d}/.git" ] || die "no canonical repo: $repo"; local risky=0 wt
  _prog "checking worktrees" 10
  for wt in $(git -C "$d" worktree list --porcelain 2>/dev/null | awk '/^worktree /{print $2}'); do
    [ "$wt" = "$d" ] && continue; [ -e "$wt/.git" ] || continue
    local dirty unpushed; dirty=$(git -C "$wt" status --porcelain 2>/dev/null | wc -l | tr -d ' '); unpushed=$(git -C "$wt" log --branches --not --remotes --oneline 2>/dev/null | wc -l | tr -d ' ')
    if [ "$dirty" != 0 ] || [ "$unpushed" != 0 ]; then risky=$((risky+1)); printf '  at-risk: %s (dirty=%s unpushed=%s)\n' "${wt#"$WORK"/}" "$dirty" "$unpushed"; fi; done
  _prog "checking worktrees" 30
  if [ "$risky" -gt 0 ] && [ "$force" != "--force" ]; then printf 'REFUSED: %s worktree(s) hold uncommitted/unpushed work\n' "$risky"; return 3; fi
  local -a rm_wts=()
  for wt in $(git -C "$d" worktree list --porcelain 2>/dev/null | awk '/^worktree /{print $2}'); do
    [ "$wt" = "$d" ] && continue; rm_wts+=("$wt"); done
  local n=${#rm_wts[@]} i=0
  for wt in "${rm_wts[@]}"; do
    i=$((i+1)); [ "$n" -gt 0 ] && _prog "removing worktrees" $(( 30 + i * 50 / n )) || _prog "removing worktrees" 50
    git -C "$d" worktree remove --force "$wt" 2>/dev/null; rm -rf "$wt" 2>/dev/null; done
  _prog "deleting repo" 90; rm -rf "$d"; _prog "finishing" 100
  printf 'deleted repo: %s\n' "$repo"; }
# Fast-forward a canonical's checked-out branch to its upstream, but only when it
# is unambiguously safe: attached HEAD, has an upstream, strictly behind, clean tree.
# A dirty or diverged canonical is the user's to resolve — we report and move on.
# Runs backend-side (on the box), so the checkout never goes over the SMB mount,
# where git's unlink/rename churn is unreliable.
_ff_canon(){ local d=$1 r=$2 counts ahead behind
  git -C "$d" symbolic-ref --quiet HEAD >/dev/null 2>&1 || { ok "synced $r (detached)"; return; }
  git -C "$d" rev-parse --quiet --verify '@{upstream}' >/dev/null 2>&1 || { ok "synced $r"; return; }
  counts=$(git -C "$d" rev-list --left-right --count 'HEAD...@{upstream}' 2>/dev/null) || { ok "synced $r"; return; }
  ahead=${counts%%[[:space:]]*}; behind=${counts##*[[:space:]]}
  [ "$behind" = 0 ] && { ok "synced $r"; return; }
  [ "$ahead" = 0 ] || { warn "synced $r (diverged +$ahead/-$behind, left alone)"; return; }
  [ -n "$(git -C "$d" status --porcelain 2>/dev/null)" ] && { warn "synced $r (behind $behind, dirty — left alone)"; return; }
  if git -C "$d" merge --ff-only --quiet '@{upstream}' 2>/dev/null; then ok "synced $r (+$behind)"; else warn "synced $r (ff failed)"; fi; }
cmd_sync(){ local target="${1:---all}" repos; if [ "$target" = "--all" ]; then repos=$(_repos_all); else repos="$target"; fi
  local -a repo_list=(); local r; for r in $repos; do repo_list+=("$r"); done
  local n=${#repo_list[@]} i=0
  for r in "${repo_list[@]}"; do i=$((i+1)); local d; d=$(_canon "$r")
    [ "$n" -gt 0 ] && _prog "syncing repos" $(( i * 100 / n )) || _prog "syncing $r" 50
    [ -d "${d}/.git" ] || { warn "skip $r (no canonical)"; continue; }
    if git -C "$d" fetch --all --prune --quiet 2>/dev/null; then git -C "$d" remote set-head origin -a >/dev/null 2>&1; git -C "$d" maintenance run --auto --quiet 2>/dev/null; _ff_canon "$d" "$r"; else err "failed $r (auth?)"; fi; done; }
cmd_clean(){ local force="${1:-}"; local -a repo_list=(); local r; for r in $(_repos_all); do repo_list+=("$r"); done
  local n=${#repo_list[@]} ri=0
  for r in "${repo_list[@]}"; do ri=$((ri+1)); local d; d=$(_canon "$r")
    [ "$n" -gt 0 ] && _prog "scanning repos" $(( ri * 100 / n )) || _prog "scanning $r" 50
    git -C "$d" fetch --prune --quiet 2>/dev/null || { warn "skip $r (fetch failed)"; continue; }
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
# --force discards uncommitted work; --yes is not a discard flag (frontend confirm skip only).
cmd_archive(){
  local wt="" force=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --force|-f) force=--force; shift;;
      --yes|-y) shift;; # confirm-skip parity with frontend; does not discard dirty
      -*) die "unknown flag: $1 (usage: archive <path> [--force])";;
      *) [ -z "$wt" ] || die "usage: archive <path> [--force]"; wt=$1; shift;;
    esac
  done
  [ -n "$wt" ] || die "usage: archive <path> [--force]"
  case "$wt" in "$WORK"/*) ;; *) die "refusing: not under workspaces/";; esac
  local rel=${wt#"$WORK"/}; _is_agent "${rel%%/*}" || die "not a wt-managed worktree"; [ -e "$wt/.git" ] || die "not a worktree: $wt"
  _prog "checking status" 25
  [ -n "$(git -C "$wt" status --porcelain 2>/dev/null)" ] && [ "$force" != "--force" ] && {
    printf 'DIRTY: uncommitted changes — commit first, or archive --force to discard them\n'
    return 3
  }
  local repo; repo=$(printf '%s' "$rel" | cut -d/ -f2); local br; br=$(git -C "$wt" branch --show-current 2>/dev/null)
  _prog "archiving worktree" 70
  git -C "$(_canon "$repo")" worktree remove --force "$wt" || die "worktree remove failed"; _prog "finishing" 100
  printf 'archived: %s\n' "$br"; }
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
cmd_rmbranch(){
  local repo="" branch=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --yes|-y) shift;; # CLI parity with frontend confirm skip
      -*) die "unknown flag: $1 (usage: rmbranch <repo> <branch>)";;
      *) if [ -z "$repo" ]; then repo=$1; elif [ -z "$branch" ]; then branch=$1; else die "usage: rmbranch <repo> <branch>"; fi; shift;;
    esac
  done
  [ -n "$repo" ] && [ -n "$branch" ] || die "usage: rmbranch <repo> <branch>"
  local d; d=$(_canon "$repo"); [ -d "${d}/.git" ] || die "no canonical repo: $repo"; _is_agent "${branch%%/*}" || die "not an agent branch: $branch"
  _prog "checking branch" 30
  git -C "$d" worktree list --porcelain 2>/dev/null | awk '/^branch /{sub("refs/heads/","",$2); print $2}' | grep -qxF "$branch" && die "branch is active (worktree exists) — archive it first"
  _prog "deleting branch" 80
  git -C "$d" branch -D "$branch" >/dev/null 2>&1 && { _prog "finishing" 100; printf 'removed branch: %s\n' "$branch"; } || die "branch delete failed"; }
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
cmd_doctor(){
  local r missing=0
  ok "store root  ${DIM}$ROOT${N}"
  if _agents_configured; then ok "agents  ${DIM}$VALID_AGENTS${N}"; else warn "no agents configured — wt agents add <name>"; fi
  command -v git >/dev/null 2>&1 && ok "git available" || err "git missing"
  if command -v gh >/dev/null 2>&1; then ok "gh available"; else warn "gh not installed (optional)"; fi
  # Shared/box path: probe remotes when we have canonicals (no fleet-specific remediations).
  if [ "${WT_PROFILE_TYPE:-local}" != local ] && [ -z "${WT_HOME:-}" ]; then
    local first; first=$(_repos_all | head -1)
    if [ -n "$first" ]; then
      if git -C "$(_canon "$first")" ls-remote origin >/dev/null 2>&1; then
        ok "origin reachable for ${DIM}$first${N}"
      else
        err "cannot reach origin for $first — check git credentials / network"
      fi
    fi
  fi
  for r in $(_repos_all); do [ "$(git -C "$(_canon "$r")" config --get worktree.useRelativePaths 2>/dev/null)" = true ] || { err "relpaths off: $r"; missing=1; }; done
  [ -z "$(_repos_all)" ] && ok "no canonicals yet — wt clone <repo>"
  [ "$missing" = 0 ] && [ -n "$(_repos_all)" ] && ok "relative worktrees set on all canonicals"
  return 0
}

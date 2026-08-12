#!/usr/bin/env bash
# BACKEND — git verbs (cmd_*) that run where the store lives: on the box over
# ssh (shared), or in-process (local profile / WORKFRAME_BACKEND=1).
# These operate purely on $ROOT / $REPOS / $WORK with `git -C`.

# Repo folder names stay inside $REPOS — no slashes, no "." / "..".
_repo_name_ok(){
  case "$1" in
    ""|"."|".."|*/*|*\\*) return 1;;
    *[!A-Za-z0-9._-]*) return 1;;
  esac
  return 0
}
# A task becomes the branch name. Slashes
# are allowed so `sub/feat` keeps working, but every segment must be a usable
# ref component: git rejects "..", a ".lock" suffix, and empty segments, and a
# leading dash makes the branch look like a flag. Without this, `new <repo> "   "`
# normalized to the branch `---`, and anything git refused surfaced as a
# raw `fatal:` instead of an explanation.
_feature_name_ok(){
  local feature=$1 seg
  case "$feature" in
    ''|/*|*/) return 1;;
    *[!a-z0-9._/-]*) return 1;;
    *//*) return 1;;
  esac
  local rest=$feature
  while [ -n "$rest" ]; do
    seg=${rest%%/*}
    case "$rest" in */*) rest=${rest#*/};; *) rest="";; esac
    case "$seg" in
      ''|'.'|'..'|*.lock) return 1;;
      [!a-z0-9]*) return 1;;
    esac
  done
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
_prog(){ printf 'workframe-progress:%s:%s\n' "$1" "$2" >&2; }
_default_branch(){ local b; b=$(git -C "$(_canon "$1")" symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null); b=${b#origin/}; printf '%s' "${b:-main}"; }
_repos_all(){ for d in "$REPOS"/*/; do [ -d "${d}.git" ] && basename "$d"; done; }
_ensure_relpaths(){ git -C "$(_canon "$1")" config worktree.useRelativePaths true 2>/dev/null; }

# Workframe-owned branches are explicitly marked in a private Git ref namespace.
# Layout alone is not ownership: Conductor and users may create compatible worktrees.
_managed_ref(){ printf 'refs/workframe/managed/%s' "$2"; }
_managed_branch(){ git -C "$(_canon "$1")" show-ref --verify --quiet "$(_managed_ref "$1" "$2")"; }
_register_branch(){ git -C "$(_canon "$1")" update-ref "$(_managed_ref "$1" "$2")" "refs/heads/$2"; }
_unregister_branch(){ git -C "$(_canon "$1")" update-ref -d "$(_managed_ref "$1" "$2")"; }
# Print a worktree's branch from Git's porcelain record, including stale entries.
_worktree_branch(){
  local d=$1 wanted=$2 line path="" branch=""
  while IFS= read -r line; do
    case "$line" in
      "worktree "*)
        if [ "$path" = "$wanted" ]; then printf '%s' "$branch"; return; fi
        path=${line#worktree }; branch=""
        ;;
      "branch refs/heads/"*) branch=${line#branch refs/heads/};;
    esac
  done < <(git -C "$d" worktree list --porcelain 2>/dev/null)
  [ "$path" = "$wanted" ] && printf '%s' "$branch"
}
_managed_worktree(){
  local repo=$1 worktree=$2 branch
  branch=$(_worktree_branch "$(_canon "$repo")" "$worktree")
  [ -n "$branch" ] && _managed_branch "$repo" "$branch"
}
cmd_guide(){
  _ensure_store_guide "$ROOT" || die "could not create Workframe guide at $ROOT/WORKFRAME.md"
  printf 'guide: %s\n' "$ROOT/WORKFRAME.md"
}

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

# Unique folder label under $WORK/<repo>/. Samples lib/cities.txt
# (world place names); on collision exhaustion, syllable names, then a suffix.
_pick_city(){
  local dir="$WORK/$1"
  local file="${WORKFRAME_LIB:-}/cities.txt"
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
# Git's porcelain format puts the complete path after "worktree ".  Do not use
# awk's $2 here: roots with spaces are valid and must remain one pathname.
_worktree_paths(){
  local d=$1 line
  while IFS= read -r line; do
    case "$line" in "worktree "*) printf '%s\n' "${line#worktree }";; esac
  done < <(git -C "$d" worktree list --porcelain 2>/dev/null)
}
cmd_worktrees(){ local r d
  for r in $(_repos_all); do d=$(_canon "$r")
    while IFS= read -r worktree; do
      case "$worktree" in "$WORK"/*) ;; *) continue;; esac; [ -e "$worktree/.git" ] || continue
      local rel=${worktree#"$WORK"/} city
      case "$rel" in
        "$r"/*) city=${rel#"$r"/}; case "$city" in */*) continue;; esac;;
        *) continue;;
      esac
      local branch; branch=$(git -C "$worktree" branch --show-current 2>/dev/null)
      _managed_branch "$r" "$branch" || continue
      printf '%s\t%s\t%s\t%s\n' "$r" "$city" "$worktree" "$branch"
    done < <(_worktree_paths "$d"); done; }
cmd_new(){ local repo="${1:-}" feature="${2:-}"
  [ $# -eq 2 ] || die "usage: new <repo> <task>"
  feature=$(printf '%s' "$feature" | tr ' ' '-' | tr '[:upper:]' '[:lower:]')
  _feature_name_ok "$feature" || die "invalid feature name '$feature' (use letters, numbers, . _ - and /, starting with a letter or number)"
  local d; d=$(_canon "$repo")
  [ -d "${d}/.git" ] || die "no repo '$repo' — clone first: workframe clone owner/repo"
  _ensure_relpaths "$repo"
  local city branch="$feature" worktree_dir existing
  # Archive keeps the branch; reuse needs restore, not a second -b create.
  if git -C "$d" show-ref --verify --quiet "refs/heads/$branch" 2>/dev/null; then
    existing=$(git -C "$d" worktree list --porcelain 2>/dev/null | awk -v want="refs/heads/$branch" '
      /^worktree /{sub(/^worktree /, ""); worktree=$0; next}
      /^branch /{ if ($2==want) { print worktree; exit } }
    ')
    if [ -n "$existing" ]; then
      die "branch '$branch' is already active at $existing"
    fi
    die "branch '$branch' is archived — restore with: workframe restore $repo $branch"
  fi
  city=$(_pick_city "$repo"); worktree_dir="$WORK/$repo/$city"
  # New feature branches should not track the default branch. Tracking is set
  # when the user first pushes their feature branch with `git push -u`.
  mkdir -p "$(dirname "$worktree_dir")"
  git -C "$d" worktree add -b "$branch" --no-track "$worktree_dir" "origin/$(_default_branch "$repo")" >/dev/null 2>&1 || die "could not create workspace"
  if ! _register_branch "$repo" "$branch"; then
    git -C "$d" worktree remove --force "$worktree_dir" >/dev/null 2>&1 || true
    git -C "$d" branch -D "$branch" >/dev/null 2>&1 || true
    die "could not record workspace ownership"
  fi
  local ex; ex=$(git -C "$worktree_dir" rev-parse --git-path info/exclude 2>/dev/null)
  [ -n "$ex" ] && for cdir in $CACHE_DIRS; do grep -qxF "/$cdir" "$ex" 2>/dev/null || printf '/%s\n' "$cdir" >> "$ex"; done
  printf '%s\n' "$worktree_dir"; }
cmd_rename(){ local worktree="${1:-}" feature="${2:-}"; [ -n "$worktree" ] && [ -n "$feature" ] || die "usage: rename <path> <task>"
  case "$worktree" in "$WORK"/*) ;; *) die "not a workframe worktree: $worktree";; esac; [ -e "$worktree/.git" ] || die "not a worktree: $worktree"
  local rel=${worktree#"$WORK"/} repo
  repo=${rel%%/*}
  case "$rel" in "$repo"/*/*) die "not a Workframe workspace";; esac
  [ -d "$REPOS/$repo/.git" ] || die "not a Workframe workspace"
  local oldbr; oldbr=$(git -C "$worktree" branch --show-current 2>/dev/null)
  _managed_branch "$repo" "$oldbr" || die "not a Workframe-managed workspace"
  feature=$(printf '%s' "$feature" | tr ' ' '-' | tr '[:upper:]' '[:lower:]')
  _feature_name_ok "$feature" || die "invalid feature name '$feature' (use letters, numbers, . _ - and /, starting with a letter or number)"
  local newbr="$feature"
  [ "$oldbr" = "$newbr" ] && { printf 'branch already %s\n' "$newbr"; return 0; }
  git -C "$(_canon "$repo")" branch -m "$oldbr" "$newbr" || die "branch rename failed"
  if ! _register_branch "$repo" "$newbr"; then
    git -C "$(_canon "$repo")" branch -m "$newbr" "$oldbr" >/dev/null 2>&1 || true
    die "could not record workspace ownership"
  fi
  _unregister_branch "$repo" "$oldbr" || warn "renamed, but could not clear old workspace ownership"
  printf 'renamed: %s -> %s\n' "$oldbr" "$newbr"; }
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
            [ -n "$DEFAULT_ORG" ] || die "no default org — pass owner/repo, or set default_org in the selected store config"
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
  local d; d=$(_canon "$repo"); [ -d "${d}/.git" ] || die "no canonical repo: $repo"; local risky=0 worktree
  # Partition the canonical's worktrees. This function rm -rf's what it is given,
  # so only paths under $WORK are ever deleted: a worktree the user added by hand
  # somewhere else is theirs, not Workframe's, and was previously wiped without
  # warning. `clean` and `worktrees` already apply the same containment rule.
  local -a worktrees=() external=()
  while IFS= read -r worktree; do
    [ "$worktree" = "$d" ] && continue
    # A compatible path is not proof of ownership. Only branches created or
    # migrated by Workframe carry a managed ref; leave every other worktree alone.
    case "$worktree" in
      "$WORK/$repo"/*) _managed_worktree "$repo" "$worktree" && worktrees+=("$worktree") || external+=("$worktree");;
      *) external+=("$worktree");;
    esac
  done < <(_worktree_paths "$d")
  _prog "checking worktrees" 10
  for worktree in "${worktrees[@]}" ${external[@]+"${external[@]}"}; do
    [ -e "$worktree/.git" ] || continue
    local dirty unpushed; dirty=$(git -C "$worktree" status --porcelain 2>/dev/null | wc -l | tr -d ' '); unpushed=$(git -C "$worktree" log --branches --not --remotes --oneline 2>/dev/null | wc -l | tr -d ' ')
    if [ "$dirty" != 0 ] || [ "$unpushed" != 0 ]; then risky=$((risky+1)); printf '  at-risk: %s (dirty=%s unpushed=%s)\n' "${worktree#"$WORK"/}" "$dirty" "$unpushed"; fi; done
  _prog "checking worktrees" 30
  if [ "$risky" -gt 0 ] && [ "$force" != "--force" ]; then printf 'REFUSED: %s worktree(s) hold uncommitted/unpushed work\n' "$risky"; return 3; fi
  if [ ${#external[@]} -gt 0 ]; then
    for worktree in "${external[@]}"; do printf '  outside the store: %s\n' "$worktree"; done
    if [ "$force" != "--force" ]; then
      printf 'REFUSED: %s worktree(s) are not Workframe-managed — remove them yourself before deleting the repository\n' "${#external[@]}"
      return 3
    fi
    printf 'REFUSED: %s worktree(s) are not Workframe-managed — deleting the canonical would break them\n' "${#external[@]}"
    return 3
  fi
  local n=${#worktrees[@]} i=0
  for worktree in "${worktrees[@]}"; do
    i=$((i+1)); [ "$n" -gt 0 ] && _prog "removing worktrees" $(( 30 + i * 50 / n )) || _prog "removing worktrees" 50
    git -C "$d" worktree remove --force "$worktree" 2>/dev/null
    # Belt and braces: the partition above already guarantees containment, but
    # this is the line that recursively deletes, so it re-checks before doing so.
    case "$worktree" in "$WORK"/*) rm -rf "${worktree:?}" 2>/dev/null;; esac; done
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
    while IFS= read -r worktree; do
      case "$worktree" in "$WORK/$r"/*) ;; *) continue;; esac
      _managed_worktree "$r" "$worktree" || continue
      if [ ! -e "$worktree/.git" ]; then
        printf '  %sorphan%s   %s\n' "$YEL" "$N" "$worktree"
        if [ "$force" = "--yes" ]; then
          rm -rf "$worktree"
          git -C "$d" worktree prune --expire=now || die "could not prune stale worktree metadata"
        fi
        continue
      fi
      [ -n "$(git -C "$worktree" status --porcelain 2>/dev/null)" ] && continue
      local br up_remote up_merge rc unpushed; br=$(git -C "$worktree" branch --show-current 2>/dev/null)
      up_remote=$(git -C "$worktree" config --get "branch.$br.remote" 2>/dev/null || true)
      up_merge=$(git -C "$worktree" config --get "branch.$br.merge" 2>/dev/null || true)
      # A new worktree starts from origin/main but must never be treated as a
      # deleted feature branch. Only branches that explicitly track themselves
      # on origin are cleanup candidates.
      [ "$up_remote" = origin ] && [ "$up_merge" = "refs/heads/$br" ] || continue
      git -C "$d" ls-remote --exit-code --heads origin "$br" >/dev/null 2>&1; rc=$?
      if [ "$rc" = 2 ]; then
        # A disappeared remote does not prove there is no local-only work
        # (for example after a squash merge followed by more local commits).
        unpushed=$(git -C "$worktree" log "$br" --not --remotes --oneline 2>/dev/null | wc -l | tr -d ' ')
        if [ "$unpushed" != 0 ]; then
          printf '  %sskip%s     %s %s(%s local-only commit(s))%s\n' "$YEL" "$N" "$worktree" "$DIM" "$unpushed" "$N"
          continue
        fi
        printf '  %sremote gone%s  %s %s(%s)%s\n' "$GRN" "$N" "$worktree" "$DIM" "$br" "$N"
        [ "$force" = "--yes" ] && git -C "$d" worktree remove --force "$worktree" && git -C "$d" branch -D "$br" >/dev/null 2>&1 && printf '%s  removed %s (%s)\n' "$(date '+%F %T')" "$worktree" "$br" >> "$LOGDIR/workframe-clean.log" 2>/dev/null
      fi
    done < <(_worktree_paths "$d"); done; [ "$force" = "--yes" ] || printf '  %s(dry run — workframe clean --yes to remove)%s\n' "$DIM" "$N"; }
# archive: remove the worktree FOLDER but KEEP the branch (Conductor-style — restorable).
# --force discards uncommitted work; --yes is not a discard flag (frontend confirm skip only).
cmd_archive(){
  local worktree="" force=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --force|-f) force=--force; shift;;
      --yes|-y) shift;; # confirm-skip parity with frontend; does not discard dirty
      -*) die "unknown flag: $1 (usage: archive <path> [--force])";;
      *) [ -z "$worktree" ] || die "usage: archive <path> [--force]"; worktree=$1; shift;;
    esac
  done
  [ -n "$worktree" ] || die "usage: archive <path> [--force]"
  # $WORK is physical (see config.sh), so the argument must be too — otherwise a
  # store reached through a symlink (an attached volume, /tmp on macOS) fails the
  # containment check even though it names a managed worktree.
  [ -d "$worktree" ] && worktree=$(cd -P "$worktree" 2>/dev/null && pwd -P || printf '%s' "$worktree")
  case "$worktree" in "$WORK"/*) ;; *) die "refusing: not under workspaces/";; esac
  local rel=${worktree#"$WORK"/} repo; repo=${rel%%/*}; case "$rel" in "$repo"/*/*) die "not a Workframe workspace";; esac; [ -d "$REPOS/$repo/.git" ] || die "not a Workframe workspace"; [ -e "$worktree/.git" ] || die "not a worktree: $worktree"
  _prog "checking status" 25
  [ -n "$(git -C "$worktree" status --porcelain 2>/dev/null)" ] && [ "$force" != "--force" ] && {
    printf 'DIRTY: uncommitted changes — commit first, or archive --force to discard them\n'
    return 3
  }
  local br; br=$(git -C "$worktree" branch --show-current 2>/dev/null)
  _managed_branch "$repo" "$br" || die "not a Workframe-managed workspace"
  _prog "archiving worktree" 70
  git -C "$(_canon "$repo")" worktree remove --force "$worktree" || die "worktree remove failed"; _prog "finishing" 100
  printf 'archived: %s\n' "$br"; }
# archived: non-default branches with no managed worktree.
cmd_archived(){ local r d
  for r in $(_repos_all); do d=$(_canon "$r")
    local checked base; checked=$(git -C "$d" worktree list --porcelain 2>/dev/null | awk '/^branch /{sub("refs/heads/","",$2); print $2}'); base=$(_default_branch "$r")
    git -C "$d" for-each-ref --format='%(refname:short)' refs/heads 2>/dev/null | while read -r br; do
      [ "$br" = "$base" ] && continue
      _managed_branch "$r" "$br" || continue
      printf '%s\n' "$checked" | grep -qxF "$br" && continue
      printf '%s\t%s\t%s\n' "$r" "$br" "$(git -C "$d" log -1 --format='%cr' "$br" 2>/dev/null)"
    done; done; }
# restore: recreate a worktree on an EXISTING (archived) branch, in a fresh city folder.
cmd_restore(){ local repo="${1:-}" branch="${2:-}"; [ -n "$repo" ] && [ -n "$branch" ] || die "usage: restore <repo> <branch>"
  local d; d=$(_canon "$repo"); [ -d "${d}/.git" ] || die "no canonical repo: $repo"
  git -C "$d" show-ref --verify --quiet "refs/heads/$branch" || die "no such branch: $branch"
  local city worktree_dir
  _ensure_relpaths "$repo"
  city=$(_pick_city "$repo"); worktree_dir="$WORK/$repo/$city"
  _managed_branch "$repo" "$branch" || die "branch is not managed by Workframe"
  mkdir -p "$(dirname "$worktree_dir")"; git -C "$d" worktree add "$worktree_dir" "$branch" >&2 || die "worktree add failed"
  local ex; ex=$(git -C "$worktree_dir" rev-parse --git-path info/exclude 2>/dev/null)
  [ -n "$ex" ] && for cdir in $CACHE_DIRS; do grep -qxF "/$cdir" "$ex" 2>/dev/null || printf '/%s\n' "$cdir" >> "$ex"; done
  printf 'workspace: %s\nbranch: %s\ncity: %s\n' "$worktree_dir" "$branch" "$city"; }
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
  local d; d=$(_canon "$repo"); [ -d "${d}/.git" ] || die "no canonical repo: $repo"
  _managed_branch "$repo" "$branch" || die "branch is not managed by Workframe"
  _prog "checking branch" 30
  git -C "$d" worktree list --porcelain 2>/dev/null | awk '/^branch /{sub("refs/heads/","",$2); print $2}' | grep -qxF "$branch" && die "branch is active (worktree exists) — archive it first"
  _prog "deleting branch" 80
  git -C "$d" branch -D "$branch" >/dev/null 2>&1 || die "branch delete failed"
  _unregister_branch "$repo" "$branch" || warn "branch deleted, but could not clear workspace ownership"
  _prog "finishing" 100
  printf 'removed branch: %s\n' "$branch"; }
cmd_list(){ local rows; rows=$(cmd_worktrees)
  printf '  %s%-12s %-22s %-6s %-9s %s%s\n' "$W" REPO TASK DIRTY AHD/BEH CITY "$N"
  [ -z "$rows" ] && { printf '  %sno worktrees yet — try: workframe new%s\n' "$DIM" "$N"; return; }
  printf '%s\n' "$rows" | while IFS=$'\t' read -r repo city worktree br; do local base; base=$(_default_branch "$repo")
    local task dv dc dcell ab; task=$br; [ ${#task} -gt 22 ] && task="${task:0:20}.."
    if [ -n "$(git -C "$worktree" status --porcelain 2>/dev/null)" ]; then dv=yes; dc=$YEL; else dv="-"; dc=$DIM; fi; printf -v dcell '%-6s' "$dv"
    ab=$(git -C "$worktree" rev-list --left-right --count "origin/$base...HEAD" 2>/dev/null | awk '{printf "+%s/-%s",$2,$1}')
    printf '  %-12s %s%-22s%s %s%s%s %-9s %s%s%s\n' "$repo" "$W" "$task" "$N" "$dc" "$dcell" "$N" "${ab:-?}" "$DIM" "$city" "$N"; done; }

_legacy_agent_configured(){
  local want=$1 a
  for a in $LEGACY_AGENTS; do [ "$a" = "$want" ] && return 0; done
  return 1
}

_migration_rollback(){
  local operations=$1 kind a b c
  while IFS=$'\t' read -r kind a b c; do
    case "$kind" in
      unregister) git -C "$a" update-ref -d "refs/workframe/managed/$b" >/dev/null 2>&1 || true;;
      rename) git -C "$a" branch -m "$c" "$b" >/dev/null 2>&1 || true;;
      move) git -C "$a" worktree move "$c" "$b" >/dev/null 2>&1 || true;;
    esac
  done <<< "$operations"
}

# Restore configuration files captured before a migration's Git operations.
_migration_restore_config(){
  local current=$1 current_backup=$2 current_exists=$3 legacy=$4 legacy_backup=$5 legacy_exists=$6
  if [ "$current_exists" = 1 ]; then cp -p "$current_backup" "$current" || return 1; else rm -f -- "$current" || return 1; fi
  [ "$legacy" = "$current" ] && return 0
  if [ "$legacy_exists" = 1 ]; then cp -p "$legacy_backup" "$legacy" || return 1; else rm -f -- "$legacy" || return 1; fi
}

# Keep the test-only config failure seam next to the transactional migration path.
_migration_save_config(){
  [ "${WORKFRAME_MIGRATE_FAIL_CONFIG_SAVE:-0}" != 1 ] || return 1
  _save_user_config
}

# Convert the pre-1.6 agent/repo/city layout without touching remotes or
# Conductor. A config's old agents= value is the ownership proof for both active
# worktrees and archived branches; unknown nested paths are refused, not guessed.
cmd_migrate(){
  local yes=0
  case "${1:-}" in
    "") ;;
    --yes|-y) yes=1;;
    -h|--help) printf 'usage: workframe migrate [--yes]\n'; return 0;;
    *) die 'usage: workframe migrate [--yes]';;
  esac
  [ -n "$LEGACY_AGENTS" ] || die 'no legacy agents= configuration found; nothing to migrate'

  local plans='' problems='' r d worktree rel agent repo city branch task dest existing plan_file
  plan_file=$(mktemp "${TMPDIR:-/tmp}/workframe-migrate.XXXXXX") || die 'could not create migration plan'
  for r in $(_repos_all); do
    d=$(_canon "$r")
    while IFS= read -r worktree; do
      case "$worktree" in "$WORK"/*/*/*) ;; *) continue;; esac
      rel=${worktree#"$WORK"/}; agent=${rel%%/*}; repo=${rel#*/}; repo=${repo%%/*}; city=${rel##*/}
      case "$rel" in "$agent/$repo/$city") ;; *) problems="${problems}"$'\n'"invalid legacy workspace path: $worktree"; continue;; esac
      [ "$repo" = "$r" ] || { problems="${problems}"$'\n'"workspace belongs under wrong repository: $worktree"; continue; }
      _legacy_agent_configured "$agent" || { problems="${problems}"$'\n'"unknown legacy agent '$agent' at $worktree"; continue; }
      [ -e "$worktree/.git" ] || { problems="${problems}"$'\n'"invalid legacy worktree: $worktree"; continue; }
      branch=$(git -C "$worktree" branch --show-current 2>/dev/null)
      case "$branch" in "$agent"/*) task=${branch#"$agent/"};; *) problems="${problems}"$'\n'"legacy workspace branch mismatch: $worktree ($branch)"; continue;; esac
      [ -n "$task" ] || { problems="${problems}"$'\n'"empty legacy task branch: $branch"; continue; }
      dest="$WORK/$repo/$city"
      [ -e "$dest" ] && problems="${problems}"$'\n'"destination exists: $dest"
      git -C "$d" show-ref --verify --quiet "refs/heads/$task" && problems="${problems}"$'\n'"target branch exists: $repo/$task"
      plans="${plans}"$'\n'"active"$'\t'"$r"$'\t'"$worktree"$'\t'"$dest"$'\t'"$branch"$'\t'"$task"
    done < <(_worktree_paths "$d")

    for agent in $LEGACY_AGENTS; do
      git -C "$d" for-each-ref --format='%(refname:short)' "refs/heads/$agent" 2>/dev/null | while IFS= read -r branch; do
        [ -n "$branch" ] || continue
        task=${branch#"$agent/"}
        # Active branches are already represented above; they move with the worktree.
        git -C "$d" worktree list --porcelain | grep -qx "branch refs/heads/$branch" && continue
        git -C "$d" show-ref --verify --quiet "refs/heads/$task" && printf 'problem\t%s\t%s\n' "$r" "target branch exists: $r/$task" || printf 'archived\t%s\t%s\t%s\n' "$r" "$branch" "$task"
      done
    done
  done > "$plan_file"
  if [ -s "$plan_file" ]; then
    while IFS=$'\t' read -r kind a b c; do
      if [ "$kind" = problem ]; then problems="${problems}"$'\n'"$c"; else plans="${plans}"$'\n'"$kind"$'\t'"$a"$'\t'"$b"$'\t'"$c"; fi
    done < "$plan_file"
  fi
  rm -f "$plan_file"
  plans=$(printf '%s\n' "$plans" | sed '/^$/d')
  problems=$(printf '%s\n' "$problems" | sed '/^$/d')
  # Two old agents may have used the same task or city. Detect collisions across
  # the complete plan, not only against state that existed before migration.
  local targets='' destinations='' kind a b c d e key
  while IFS=$'\t' read -r kind a b c d e; do
    case "$kind" in
      active)
        key="$a"$'\t'"$e"
        printf '%s\n' "$targets" | grep -qxF "$key" && problems="${problems}"$'\n'"multiple legacy branches map to: $a/$e"
        targets="${targets}"$'\n'"$key"
        key="$a"$'\t'"$c"
        printf '%s\n' "$destinations" | grep -qxF "$key" && problems="${problems}"$'\n'"multiple legacy worktrees map to: $c"
        destinations="${destinations}"$'\n'"$key"
        ;;
      archived)
        key="$a"$'\t'"$c"
        printf '%s\n' "$targets" | grep -qxF "$key" && problems="${problems}"$'\n'"multiple legacy branches map to: $a/$c"
        targets="${targets}"$'\n'"$key"
        ;;
    esac
  done <<< "$plans"
  [ -z "$plans" ] && [ -z "$problems" ] && { ok 'no legacy workspaces or branches to migrate'; return 0; }
  printf '%s\n' "$plans" | while IFS=$'\t' read -r kind a b c d e; do
    case "$kind" in
      active) printf '  active   %s  %s -> %s  %s -> %s\n' "$a" "$b" "$c" "$d" "$e";;
      archived) printf '  archived %s  %s -> %s\n' "$a" "$b" "$c";;
    esac
  done
  if [ -n "$problems" ]; then
    printf '%s\n' "$problems" >&2
    die 'migration refused; resolve every reported conflict before retrying'
  fi
  [ "$yes" = 1 ] || { printf 'dry run — rerun with: workframe migrate --yes\n'; return 0; }

  local journal_dir="$ROOT/system/migrations" journal operations='' completed=0 fail_after=${WORKFRAME_MIGRATE_FAIL_AFTER:-0} repo_dir
  local config_backup legacy_backup current_exists=0 legacy_exists=0
  mkdir -p "$journal_dir" || die 'could not create migration journal directory'
  journal=$(mktemp "$journal_dir/agent-layout.XXXXXX") || die 'could not create migration journal'
  printf '# workframe legacy agent-layout migration\n' > "$journal" || die 'could not create migration journal'
  config_backup=$(mktemp "$journal_dir/agent-layout-config.XXXXXX") || die 'could not snapshot migration config'
  legacy_backup=$(mktemp "$journal_dir/agent-layout-legacy.XXXXXX") || die 'could not snapshot migration config'
  if [ -f "$WORKFRAME_USER_CONFIG" ]; then cp -p "$WORKFRAME_USER_CONFIG" "$config_backup" || die 'could not snapshot migration config'; current_exists=1; fi
  if [ "$WORKFRAME_LEGACY_CONFIG" != "$WORKFRAME_USER_CONFIG" ] && [ -f "$WORKFRAME_LEGACY_CONFIG" ]; then cp -p "$WORKFRAME_LEGACY_CONFIG" "$legacy_backup" || die 'could not snapshot migration config'; legacy_exists=1; fi
  while IFS=$'\t' read -r kind a b c d e; do
    case "$kind" in
      active)
        repo_dir=$(_canon "$a")
        mkdir -p "$(dirname "$c")" || { _migration_rollback "$operations"; die "migration failed; rolled back (journal: $journal)"; }
        if ! git -C "$repo_dir" worktree move "$b" "$c"; then _migration_rollback "$operations"; die "migration failed; rolled back (journal: $journal)"; fi
        printf 'move\t%s\t%s\t%s\n' "$repo_dir" "$b" "$c" >> "$journal"; operations="move"$'\t'"$repo_dir"$'\t'"$b"$'\t'"$c"$'\n'"$operations"
        if ! git -C "$repo_dir" branch -m "$d" "$e"; then _migration_rollback "$operations"; die "migration failed; rolled back (journal: $journal)"; fi
        printf 'rename\t%s\t%s\t%s\n' "$repo_dir" "$d" "$e" >> "$journal"; operations="rename"$'\t'"$repo_dir"$'\t'"$d"$'\t'"$e"$'\n'"$operations"
        if ! _register_branch "$a" "$e"; then _migration_rollback "$operations"; die "migration failed; rolled back (journal: $journal)"; fi
        printf 'unregister\t%s\t%s\n' "$repo_dir" "$e" >> "$journal"; operations="unregister"$'\t'"$repo_dir"$'\t'"$e"$'\n'"$operations"
        ;;
      archived)
        repo_dir=$(_canon "$a")
        if ! git -C "$repo_dir" branch -m "$b" "$c"; then _migration_rollback "$operations"; die "migration failed; rolled back (journal: $journal)"; fi
        printf 'rename\t%s\t%s\t%s\n' "$repo_dir" "$b" "$c" >> "$journal"; operations="rename"$'\t'"$repo_dir"$'\t'"$b"$'\t'"$c"$'\n'"$operations"
        if ! _register_branch "$a" "$c"; then _migration_rollback "$operations"; die "migration failed; rolled back (journal: $journal)"; fi
        printf 'unregister\t%s\t%s\n' "$repo_dir" "$c" >> "$journal"; operations="unregister"$'\t'"$repo_dir"$'\t'"$c"$'\n'"$operations"
        ;;
    esac
    completed=$((completed + 1))
    if [ "$fail_after" -gt 0 ] 2>/dev/null && [ "$completed" -ge "$fail_after" ]; then _migration_rollback "$operations"; die "migration failed; rolled back (journal: $journal)"; fi
  done <<< "$plans"
  LEGACY_AGENTS=''
  if ! _migration_save_config; then
    _migration_restore_config "$WORKFRAME_USER_CONFIG" "$config_backup" "$current_exists" "$WORKFRAME_LEGACY_CONFIG" "$legacy_backup" "$legacy_exists" || warn "could not restore configuration after failed migration"
    _migration_rollback "$operations"
    die "migration failed; rolled back (journal: $journal)"
  fi
  ok "migrated legacy workspaces and branches  ${DIM}$journal${N}"
}

cmd_status(){ local n disk; n=$(cmd_worktrees | wc -l | tr -d ' '); printf 'worktrees: %s\ncanonicals:\n' "$n"
  local r; for r in $(_repos_all); do printf '  %-14s %s\n' "$r" "$(git -C "$(_canon "$r")" log -1 --format='%h %cr' 2>/dev/null)"; done
  if [ ! -d "$ROOT" ]; then
    printf 'disk: not initialized — run workframe setup\n'
    return
  fi
  disk=$(df -h "$ROOT" 2>/dev/null | awk 'NR==2{print $3" used / "$2}')
  printf 'disk: %s\n' "${disk:-unavailable}"; }
cmd_doctor(){
  local r missing=0 initialized=1
  if [ -d "$ROOT" ] && _user_config_exists; then
    ok "store root  ${DIM}$ROOT${N}"
  else
    warn "store not initialized at $ROOT — run workframe setup"
    initialized=0
  fi
  command -v git >/dev/null 2>&1 && ok "git available" || err "git missing"
  if command -v gh >/dev/null 2>&1; then ok "gh available"; else warn "gh not installed (optional)"; fi
  [ "$initialized" = 1 ] || return 0
  # Shared/box path: probe remotes when we have canonicals (no fleet-specific remediations).
  if [ "${WORKFRAME_PROFILE_TYPE:-local}" != local ] && [ -z "${WORKFRAME_HOME:-}" ]; then
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
  [ -z "$(_repos_all)" ] && ok "no canonicals yet — workframe clone <repo>"
  [ "$missing" = 0 ] && [ -n "$(_repos_all)" ] && ok "relative worktrees set on all canonicals"
  return 0
}

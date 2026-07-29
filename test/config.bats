#!/usr/bin/env bats
# Config parsing safety. CACHE_DIRS feeds `rm -rf "$worktree/$d"` in mac_localdeps,
# so every entry must be a single path segment under the worktree. A value that
# escapes via `../` deletes whatever it lands on — including a sibling worktree
# holding unpushed work.

load helper

setup() {
  export WORKFRAME_HOME="$BATS_TEST_TMPDIR/store"
  mkdir -p "$WORKFRAME_HOME"
  # shellcheck source=/dev/null
  . "${BATS_TEST_DIRNAME}/../lib/config.sh"
}

# Write a config file and load it, so assertions run against the real parser.
_load_cfg() {
  printf '%s\n' "$@" > "$WORKFRAME_HOME/config"
  _load_user_config "$WORKFRAME_HOME/config"
}

@test "_cache_dir_ok accepts plain single segments" {
  for d in node_modules .next .turbo dist build a-b_c.d; do
    _cache_dir_ok "$d" || { echo "rejected valid: $d"; return 1; }
  done
}

@test "_cache_dir_ok rejects traversal, separators and empties" {
  for d in "" "." ".." "../escape" "a/b" "/abs" 'a\b' "sp ace" 'semi;colon'; do
    ! _cache_dir_ok "$d" || { echo "accepted unsafe: [$d]"; return 1; }
  done
}

@test "_sanitize_cache_dirs drops unsafe entries and keeps the rest" {
  run _sanitize_cache_dirs "node_modules ../escape dist .. build"
  [ "$status" -eq 0 ]
  [ "$output" = "node_modules dist build" ]
}

@test "cache_dirs config with ../ traversal is filtered out" {
  _load_cfg "type = local" "cache_dirs = node_modules, ../sibling-worktree, dist"
  [ "$CACHE_DIRS" = "node_modules dist" ]
}

@test "every parsed cache dir is a single segment" {
  _load_cfg "type = local" "cache_dirs = ../a, b/c, /d, .., ., ok_one"
  [ "$CACHE_DIRS" = "ok_one" ]
  local d
  for d in $CACHE_DIRS; do
    case "$d" in */*|..|.|"") echo "unsafe survived: [$d]"; return 1;; esac
  done
}

@test "a fully unsafe cache_dirs list degrades to empty, not to a bad path" {
  _load_cfg "type = local" "cache_dirs = ../a, ../../b"
  [ -z "$CACHE_DIRS" ]
}

@test "valid cache_dirs are still honoured" {
  _load_cfg "type = local" "cache_dirs = node_modules, .next, dist"
  [ "$CACHE_DIRS" = "node_modules .next dist" ]
}

@test "saved user config is private even when replacing a permissive file" {
  printf 'old\n' > "$WORKFRAME_USER_CONFIG"
  chmod 644 "$WORKFRAME_USER_CONFIG"
  WORKFRAME_PROFILE_TYPE=shared
  BOX_HOST=store.example
  BOX_ADDR=192.0.2.10
  BOX_USER=workframe
  BOX_ROOT=/srv/workframe
  MAC_ROOT=/Volumes/workframe
  SHARE_NAME=workframe

  _save_user_config

  local mode
  if [ "$(uname -s)" = Darwin ]; then
    mode=$(stat -f '%Lp' "$WORKFRAME_USER_CONFIG")
  else
    mode=$(stat -c '%a' "$WORKFRAME_USER_CONFIG")
  fi
  [ "$mode" = 600 ]
  grep -q '^box_host = store.example$' "$WORKFRAME_USER_CONFIG"
}

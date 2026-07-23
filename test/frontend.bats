#!/usr/bin/env bats
# Frontend path resolution — hermetic, no TTY, no network.

load helper

@test "progress_run preserves backend failures and output" {
  run bash -c '
    export WT_COLOR=0
    . "'"$BATS_TEST_DIRNAME/../lib/palette.sh"'"
    . "'"$BATS_TEST_DIRNAME/../lib/ui.sh"'"
    fail_backend() { printf "backend failed\n"; return 17; }
    _progress_run "testing" fail_backend
    rc=$?
    printf "rc=%s\nout=%s\n" "$rc" "$PROGRESS_OUT"
  '
  [ "$status" -eq 0 ]
  [ "$output" = $'rc=17\nout=backend failed' ]
}

@test "resolve_worktree rejects absolute paths outside the store" {
  _use_backend_store
  run bash -c '
    export WT_BACKEND=1 WT_COLOR=0 WT_HOME="'"$WT_HOME"'"
    . "'"$BATS_TEST_DIRNAME/../lib/config.sh"'"
    . "'"$BATS_TEST_DIRNAME/../lib/palette.sh"'"
    . "'"$BATS_TEST_DIRNAME/../lib/ui.sh"'"
    . "'"$BATS_TEST_DIRNAME/../lib/agents.sh"'"
    . "'"$BATS_TEST_DIRNAME/../lib/backend.sh"'"
    . "'"$BATS_TEST_DIRNAME/../lib/frontend.sh"'"
    _resolve_worktree /tmp
  '
  [ "$status" -ne 0 ]
  [[ "$output" == *"no worktree matching"* ]]
}

@test "resolve_worktree rejects store internals that are not worktrees" {
  _use_backend_store
  mkdir -p "$WT_HOME/repos/demo"
  run bash -c '
    export WT_BACKEND=1 WT_COLOR=0 WT_HOME="'"$WT_HOME"'"
    . "'"$BATS_TEST_DIRNAME/../lib/config.sh"'"
    . "'"$BATS_TEST_DIRNAME/../lib/palette.sh"'"
    . "'"$BATS_TEST_DIRNAME/../lib/ui.sh"'"
    . "'"$BATS_TEST_DIRNAME/../lib/agents.sh"'"
    . "'"$BATS_TEST_DIRNAME/../lib/backend.sh"'"
    . "'"$BATS_TEST_DIRNAME/../lib/frontend.sh"'"
    _resolve_worktree "'"$WT_HOME/repos/demo"'"
  '
  [ "$status" -ne 0 ]
  [[ "$output" == *"no worktree matching"* ]]
}

@test "resolve_worktree rejects workspace-shaped paths not in the worktree list" {
  _use_backend_store
  local p="$WT_HOME/workspaces/codex/demo/hanoi"
  mkdir -p "$p"
  touch "$p/.git"
  p=$(cd "$p" && pwd -P)
  run bash -c '
    export WT_BACKEND=1 WT_COLOR=0 WT_HOME="'"$WT_HOME"'"
    . "'"$BATS_TEST_DIRNAME/../lib/config.sh"'"
    . "'"$BATS_TEST_DIRNAME/../lib/palette.sh"'"
    . "'"$BATS_TEST_DIRNAME/../lib/ui.sh"'"
    . "'"$BATS_TEST_DIRNAME/../lib/agents.sh"'"
    . "'"$BATS_TEST_DIRNAME/../lib/backend.sh"'"
    . "'"$BATS_TEST_DIRNAME/../lib/frontend.sh"'"
    _resolve_worktree "'"$p"'"
  '
  [ "$status" -ne 0 ]
  [[ "$output" == *"no worktree matching"* ]]
}

@test "mac_archive accepts a selector with --yes (non-interactive)" {
  _use_backend_store
  _seed_repo
  local ws; ws=$("$WT" new codex demo cli-arch 2>/dev/null | _workspace_path)
  run bash -c '
    export WT_BACKEND=1 WT_COLOR=0 WT_HOME="'"$WT_HOME"'"
    . "'"$BATS_TEST_DIRNAME/../lib/config.sh"'"
    . "'"$BATS_TEST_DIRNAME/../lib/palette.sh"'"
    . "'"$BATS_TEST_DIRNAME/../lib/ui.sh"'"
    . "'"$BATS_TEST_DIRNAME/../lib/agents.sh"'"
    . "'"$BATS_TEST_DIRNAME/../lib/backend.sh"'"
    . "'"$BATS_TEST_DIRNAME/../lib/frontend.sh"'"
    mac_archive demo/cli-arch --yes
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *"archived"* ]]
  [ ! -e "$ws/.git" ]
}

@test "mac_archive without args is a usage error when non-TTY" {
  _use_backend_store
  run bash -c '
    export WT_BACKEND=1 WT_COLOR=0 WT_HOME="'"$WT_HOME"'"
    . "'"$BATS_TEST_DIRNAME/../lib/config.sh"'"
    . "'"$BATS_TEST_DIRNAME/../lib/palette.sh"'"
    . "'"$BATS_TEST_DIRNAME/../lib/ui.sh"'"
    . "'"$BATS_TEST_DIRNAME/../lib/agents.sh"'"
    . "'"$BATS_TEST_DIRNAME/../lib/backend.sh"'"
    . "'"$BATS_TEST_DIRNAME/../lib/frontend.sh"'"
    mac_archive
  '
  [ "$status" -ne 0 ]
  [[ "$output" == *"usage: wt archive"* ]]
}

@test "mac_restore accepts repo and branch args" {
  _use_backend_store
  _seed_repo
  local ws; ws=$("$WT" new codex demo cli-rest 2>/dev/null | _workspace_path)
  "$WT" archive "$ws" >/dev/null
  run bash -c '
    export WT_BACKEND=1 WT_COLOR=0 WT_HOME="'"$WT_HOME"'"
    . "'"$BATS_TEST_DIRNAME/../lib/config.sh"'"
    . "'"$BATS_TEST_DIRNAME/../lib/palette.sh"'"
    . "'"$BATS_TEST_DIRNAME/../lib/ui.sh"'"
    . "'"$BATS_TEST_DIRNAME/../lib/agents.sh"'"
    . "'"$BATS_TEST_DIRNAME/../lib/backend.sh"'"
    . "'"$BATS_TEST_DIRNAME/../lib/frontend.sh"'"
    mac_restore demo codex/cli-rest
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *"restored"*codex/cli-rest* ]]
}

@test "mac_remove without subcommand is a usage error" {
  _use_backend_store
  run bash -c '
    export WT_BACKEND=1 WT_COLOR=0 WT_HOME="'"$WT_HOME"'"
    . "'"$BATS_TEST_DIRNAME/../lib/config.sh"'"
    . "'"$BATS_TEST_DIRNAME/../lib/palette.sh"'"
    . "'"$BATS_TEST_DIRNAME/../lib/ui.sh"'"
    . "'"$BATS_TEST_DIRNAME/../lib/agents.sh"'"
    . "'"$BATS_TEST_DIRNAME/../lib/backend.sh"'"
    . "'"$BATS_TEST_DIRNAME/../lib/frontend.sh"'"
    mac_remove
  '
  [ "$status" -ne 0 ]
  [[ "$output" == *"usage: wt remove branch"* ]]
}

@test "mac_rmbranch deletes with --yes without prompting" {
  _use_backend_store
  _seed_repo
  local ws; ws=$("$WT" new codex demo cli-rm 2>/dev/null | _workspace_path)
  "$WT" archive "$ws" >/dev/null
  run bash -c '
    export WT_BACKEND=1 WT_COLOR=0 WT_HOME="'"$WT_HOME"'"
    . "'"$BATS_TEST_DIRNAME/../lib/config.sh"'"
    . "'"$BATS_TEST_DIRNAME/../lib/palette.sh"'"
    . "'"$BATS_TEST_DIRNAME/../lib/ui.sh"'"
    . "'"$BATS_TEST_DIRNAME/../lib/agents.sh"'"
    . "'"$BATS_TEST_DIRNAME/../lib/backend.sh"'"
    . "'"$BATS_TEST_DIRNAME/../lib/frontend.sh"'"
    mac_rmbranch demo codex/cli-rm --yes
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *"deleted"*codex/cli-rm* ]]
  run git -C "$WT_HOME/repos/demo" branch --list codex/cli-rm
  [ -z "$output" ]
}

@test "mac_delrepo requires --yes when non-interactive" {
  _use_backend_store
  _seed_repo
  run bash -c '
    export WT_BACKEND=1 WT_COLOR=0 WT_HOME="'"$WT_HOME"'"
    . "'"$BATS_TEST_DIRNAME/../lib/config.sh"'"
    . "'"$BATS_TEST_DIRNAME/../lib/palette.sh"'"
    . "'"$BATS_TEST_DIRNAME/../lib/ui.sh"'"
    . "'"$BATS_TEST_DIRNAME/../lib/agents.sh"'"
    . "'"$BATS_TEST_DIRNAME/../lib/backend.sh"'"
    . "'"$BATS_TEST_DIRNAME/../lib/frontend.sh"'"
    mac_delrepo demo
  '
  [ "$status" -ne 0 ]
  [[ "$output" == *"refusing without --yes"* ]]
}

@test "mac_archive --yes on dirty worktree refuses without --force" {
  _use_backend_store
  _seed_repo
  local ws; ws=$("$WT" new codex demo cli-dirty 2>/dev/null | _workspace_path)
  echo change >> "$ws/README.md"
  run bash -c '
    export WT_BACKEND=1 WT_COLOR=0 WT_HOME="'"$WT_HOME"'"
    . "'"$BATS_TEST_DIRNAME/../lib/config.sh"'"
    . "'"$BATS_TEST_DIRNAME/../lib/palette.sh"'"
    . "'"$BATS_TEST_DIRNAME/../lib/ui.sh"'"
    . "'"$BATS_TEST_DIRNAME/../lib/agents.sh"'"
    . "'"$BATS_TEST_DIRNAME/../lib/backend.sh"'"
    . "'"$BATS_TEST_DIRNAME/../lib/frontend.sh"'"
    mac_archive demo/cli-dirty --yes
  '
  [ "$status" -eq 3 ]
  [[ "$output" == *DIRTY* ]]
  [ -e "$ws/.git" ]
}

@test "mac_archive --yes --force discards dirty work without DIRTY scare" {
  _use_backend_store
  _seed_repo
  local ws; ws=$("$WT" new codex demo cli-force 2>/dev/null | _workspace_path)
  echo change >> "$ws/README.md"
  run bash -c '
    export WT_BACKEND=1 WT_COLOR=0 WT_HOME="'"$WT_HOME"'"
    . "'"$BATS_TEST_DIRNAME/../lib/config.sh"'"
    . "'"$BATS_TEST_DIRNAME/../lib/palette.sh"'"
    . "'"$BATS_TEST_DIRNAME/../lib/ui.sh"'"
    . "'"$BATS_TEST_DIRNAME/../lib/agents.sh"'"
    . "'"$BATS_TEST_DIRNAME/../lib/backend.sh"'"
    . "'"$BATS_TEST_DIRNAME/../lib/frontend.sh"'"
    mac_archive demo/cli-force --yes --force
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *"archived"* ]]
  [[ "$output" != *DIRTY* ]]
  [ ! -e "$ws/.git" ]
}

@test "mac_new -h exits 0 with usage" {
  _use_backend_store
  run bash -c '
    export WT_BACKEND=1 WT_COLOR=0 WT_HOME="'"$WT_HOME"'"
    . "'"$BATS_TEST_DIRNAME/../lib/config.sh"'"
    . "'"$BATS_TEST_DIRNAME/../lib/palette.sh"'"
    . "'"$BATS_TEST_DIRNAME/../lib/ui.sh"'"
    . "'"$BATS_TEST_DIRNAME/../lib/agents.sh"'"
    . "'"$BATS_TEST_DIRNAME/../lib/backend.sh"'"
    . "'"$BATS_TEST_DIRNAME/../lib/frontend.sh"'"
    mac_new -h
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *"usage: wt new"* ]]
}

@test "mac_new after archive surfaces restore hint" {
  _use_backend_store
  _seed_repo
  local ws; ws=$("$WT" new codex demo comeback 2>/dev/null | _workspace_path)
  "$WT" archive "$ws" >/dev/null
  run bash -c '
    export WT_BACKEND=1 WT_COLOR=0 WT_HOME="'"$WT_HOME"'"
    . "'"$BATS_TEST_DIRNAME/../lib/config.sh"'"
    . "'"$BATS_TEST_DIRNAME/../lib/palette.sh"'"
    . "'"$BATS_TEST_DIRNAME/../lib/ui.sh"'"
    . "'"$BATS_TEST_DIRNAME/../lib/agents.sh"'"
    . "'"$BATS_TEST_DIRNAME/../lib/backend.sh"'"
    . "'"$BATS_TEST_DIRNAME/../lib/frontend.sh"'"
    mac_new demo comeback --agent codex
  '
  [ "$status" -ne 0 ]
  [[ "$output" == *"archived"* ]]
  [[ "$output" == *"wt restore demo codex/comeback"* ]]
}

@test "box_reachable uses -w timeout on Linux" {
  local fake_nc="$BATS_TEST_TMPDIR/fake-nc"
  cat > "$fake_nc" <<'EOF'
#!/bin/sh
printf '%s\n' "$*" > "${NC_ARGS_FILE:?}"
exit 0
EOF
  chmod +x "$fake_nc"
  run env NC_BIN="$fake_nc" NC_ARGS_FILE="$BATS_TEST_TMPDIR/nc-args" bash -c '
    export WT_COLOR=0 WT_HOME="'"$BATS_TEST_TMPDIR/store"'"
    mkdir -p "$WT_HOME"
    . "'"$BATS_TEST_DIRNAME/../lib/config.sh"'"
    BOX_HOST=box.example
    _box_reachable
    cat "$NC_ARGS_FILE"
  '
  [ "$status" -eq 0 ]
  if [ "$(uname)" = "Darwin" ]; then
    [[ "$output" == *"-G 2 box.example 22"* ]]
  else
    [[ "$output" == *"-w 2 box.example 22"* ]]
  fi
}

@test "shared Linux frontend preserves user HOME" {
  local user_home="$BATS_TEST_TMPDIR/user-home"
  local box_root="$BATS_TEST_TMPDIR/box-root"
  local mount_path="$BATS_TEST_TMPDIR/mount"
  mkdir -p "$user_home/.wt" "$box_root/.home" "$mount_path"
  cat > "$user_home/.wt/config" <<EOF
type = shared
box_host = box.example
box_user = wt
box_root = $box_root
mount_path = $mount_path
share_name = wt
agents = codex
EOF
  run env -u WT_BACKEND -u WT_HOME HOME="$user_home" bash -c '
    . "'"$BATS_TEST_DIRNAME/../lib/config.sh"'"
    printf "HOME=%s\n" "$HOME"
    printf "ROOT=%s\n" "$ROOT"
    printf "GIT_TERMINAL_PROMPT=%s\n" "${GIT_TERMINAL_PROMPT-}"
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *"HOME=$user_home"* ]]
  [[ "$output" == *"ROOT=$mount_path"* ]]
  [[ "$output" != *"HOME=$box_root"* ]]
  [[ "$output" != *"GIT_TERMINAL_PROMPT=0"* ]]
}

@test "shared backend remaps HOME to BOX_HOME" {
  local user_home="$BATS_TEST_TMPDIR/user-home"
  local box_root="$BATS_TEST_TMPDIR/box-root"
  local mount_path="$BATS_TEST_TMPDIR/mount"
  mkdir -p "$user_home/.wt" "$box_root/.home" "$mount_path"
  cat > "$user_home/.wt/config" <<EOF
type = shared
box_host = box.example
box_user = wt
box_root = $box_root
mount_path = $mount_path
share_name = wt
agents = codex
EOF
  run env -u WT_HOME WT_BACKEND=1 HOME="$user_home" bash -c '
    . "'"$BATS_TEST_DIRNAME/../lib/config.sh"'"
    printf "HOME=%s\n" "$HOME"
    printf "ROOT=%s\n" "$ROOT"
    printf "GIT_TERMINAL_PROMPT=%s\n" "${GIT_TERMINAL_PROMPT-}"
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *"HOME=$box_root/.home"* ]]
  [[ "$output" == *"ROOT=$box_root"* ]]
  [[ "$output" == *"GIT_TERMINAL_PROMPT=0"* ]]
}

@test "mac_localdeps is a no-op when localdeps is off" {
  _use_backend_store
  local wt="$WT_HOME/workspaces/codex/demo/fakecity"
  mkdir -p "$wt/node_modules"
  echo keep > "$wt/node_modules/x"
  run bash -c '
    export WT_BACKEND=1 WT_COLOR=0 WT_HOME="'"$WT_HOME"'"
    . "'"$BATS_TEST_DIRNAME/../lib/config.sh"'"
    . "'"$BATS_TEST_DIRNAME/../lib/palette.sh"'"
    . "'"$BATS_TEST_DIRNAME/../lib/ui.sh"'"
    . "'"$BATS_TEST_DIRNAME/../lib/agents.sh"'"
    . "'"$BATS_TEST_DIRNAME/../lib/backend.sh"'"
    . "'"$BATS_TEST_DIRNAME/../lib/frontend.sh"'"
    WT_PROFILE_TYPE=shared
    LOCALDEPS=0
    mac_localdeps "'"$wt"'"
    [ -d "'"$wt"'/node_modules" ] && [ ! -L "'"$wt"'/node_modules" ]
    grep -q keep "'"$wt"'/node_modules/x"
  '
  [ "$status" -eq 0 ]
}

@test "mac_status is a cheap glance (not doctor)" {
  _use_backend_store
  _seed_repo
  run bash -c '
    export WT_BACKEND=1 WT_COLOR=0 WT_HOME="'"$WT_HOME"'"
    . "'"$BATS_TEST_DIRNAME/../lib/config.sh"'"
    . "'"$BATS_TEST_DIRNAME/../lib/palette.sh"'"
    . "'"$BATS_TEST_DIRNAME/../lib/ui.sh"'"
    . "'"$BATS_TEST_DIRNAME/../lib/agents.sh"'"
    . "'"$BATS_TEST_DIRNAME/../lib/backend.sh"'"
    . "'"$BATS_TEST_DIRNAME/../lib/frontend.sh"'"
    mac_status
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *"worktrees:"* ]]
  [[ "$output" == *"canonicals:"* ]]
  [[ "$output" != *"gum"* ]]
}

@test "mac_config refuses non-interactive prefs rewrite" {
  _use_backend_store
  run bash -c '
    export WT_BACKEND=1 WT_COLOR=0 WT_HOME="'"$WT_HOME"'"
    . "'"$BATS_TEST_DIRNAME/../lib/config.sh"'"
    . "'"$BATS_TEST_DIRNAME/../lib/palette.sh"'"
    . "'"$BATS_TEST_DIRNAME/../lib/ui.sh"'"
    . "'"$BATS_TEST_DIRNAME/../lib/agents.sh"'"
    . "'"$BATS_TEST_DIRNAME/../lib/backend.sh"'"
    . "'"$BATS_TEST_DIRNAME/../lib/frontend.sh"'"
    mac_config
  '
  [ "$status" -ne 0 ]
  [[ "$output" == *"usage: wt config"* ]]
}

@test "_bx_remote_cmd quotes box paths containing spaces" {
  run bash -c '
    export WT_COLOR=0 WT_HOME="'"$BATS_TEST_TMPDIR/store"'"
    mkdir -p "$WT_HOME"
    . "'"$BATS_TEST_DIRNAME/../lib/config.sh"'"
    . "'"$BATS_TEST_DIRNAME/../lib/frontend.sh"'"
    BOX_USER=agents; BOX_ROOT="/mnt/my wt"; BOX_HOME="/mnt/my wt/.home"
    VALID_AGENTS="claude codex"
    cmd=$(_bx_remote_cmd 0 list)
    # Re-parse the way the remote shell will, then print one arg per line.
    eval "set -- $cmd"
    for a in "$@"; do printf "%s\n" "$a"; done
  '
  [ "$status" -eq 0 ]
  # Paths and the agent list must each survive as ONE argument, not split on space.
  [[ "$output" == *"HOME=/mnt/my wt/.home"* ]]
  [[ "$output" == *"WT_HOME=/mnt/my wt"* ]]
  [[ "$output" == *"WT_VALID_AGENTS=claude codex"* ]]
  [[ "$output" == *"/mnt/my wt/system/bin/wt"* ]]
}

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

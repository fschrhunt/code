#!/usr/bin/env bats
# Frontend path resolution — hermetic, no TTY, no network.

load helper

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

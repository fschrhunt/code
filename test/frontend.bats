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

@test "resolve_worktree accepts a path under ROOT" {
  _use_backend_store
  local p="$WT_HOME/workspaces/codex/demo/hanoi"
  mkdir -p "$p"
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
  [ "$status" -eq 0 ]
  [ "$output" = "$p" ]
}

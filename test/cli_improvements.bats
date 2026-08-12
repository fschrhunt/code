#!/usr/bin/env bats
# Command-first UX additions: these exercise the frontend over the same
# hermetic local store used by the lifecycle suite.

load helper

setup() {
  _use_backend_store
  _seed_repo demo
  export WORKFRAME_BACKEND=0
}

_new_workspace() {
  "$WORKFRAME" new demo feature >/dev/null
  "$WORKFRAME" worktrees | cut -f3
}

@test "new workspaces use the Conductor-style repo/city layout and task branch" {
  run "$WORKFRAME" new demo conductor-model
  [ "$status" -eq 0 ]
  local ws; ws=$("$WORKFRAME" worktrees | cut -f3)
  [[ "$ws" == */workspaces/demo/* ]]
  [[ "$ws" != *"/codex/"* ]]
  run git -C "$ws" branch --show-current
  [ "$output" = conductor-model ]
}

@test "init is non-interactive and writes task-only configuration" {
  local store="$BATS_TEST_TMPDIR/init-store"
  run env -u WORKFRAME_BACKEND WORKFRAME_COLOR=0 WORKFRAME_HOME="$store" "$WORKFRAME" init
  [ "$status" -eq 0 ]
  [ -f "$store/system/config/workframe.conf" ]
  ! grep -q '^agents =' "$store/system/config/workframe.conf"
}

@test "list filters and JSON describe worktrees" {
  local ws; ws=$(_new_workspace)
  printf 'change\n' >> "$ws/README.md"

  run "$WORKFRAME" list --repo demo --dirty --json
  [ "$status" -eq 0 ]
  [[ "$output" == *'"repo":"demo"'* ]]
  [[ "$output" == *'"dirty":true'* ]]

  run "$WORKFRAME" worktrees --json
  [ "$status" -eq 0 ]
  [[ "$output" == *'"path":"'* ]]
}

@test "current and run resolve a workspace from a nested directory" {
  local ws; ws=$(_new_workspace)
  mkdir -p "$ws/nested"
  run bash -c "cd '$ws/nested' && WORKFRAME_BACKEND=0 WORKFRAME_COLOR=0 WORKFRAME_HOME='$WORKFRAME_HOME' '$WORKFRAME' current --json"
  [ "$status" -eq 0 ]
  [[ "$output" == *'"branch":"feature"'* ]]

  run "$WORKFRAME" run demo/feature -- git rev-parse --show-prefix
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "lifecycle JSON and resume restore archived work" {
  local ws; ws=$(_new_workspace)
  run "$WORKFRAME" archive demo/feature --yes --json
  [ "$status" -eq 0 ]
  [[ "$output" == *'"action":"archived"'* ]]

  run "$WORKFRAME" resume demo/feature
  [ "$status" -eq 0 ]
  [[ "$output" == *restored* ]]

  run "$WORKFRAME" restore --json demo codex/feature
  [ "$status" -ne 0 ]
}

@test "status dashboard doctor repair and completion are available" {
  _new_workspace >/dev/null
  run "$WORKFRAME" status --json
  [ "$status" -eq 0 ]
  [[ "$output" == *'"worktrees":1'* ]]

  run "$WORKFRAME" dashboard
  [ "$status" -eq 0 ]
  [[ "$output" == *'active    1'* ]]

  rm -f "$WORKFRAME_HOME/WORKFRAME.md"
  run "$WORKFRAME" doctor --fix
  [ "$status" -eq 0 ]
  [ -f "$WORKFRAME_HOME/WORKFRAME.md" ]

  run "$WORKFRAME" completion bash
  [ "$status" -eq 0 ]
  [[ "$output" == *'complete -F _workframe_complete'* ]]
}

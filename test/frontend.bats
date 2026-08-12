#!/usr/bin/env bats
# User-facing task lifecycle uses the same task-only record shape as backend.

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

@test "frontend creates, lists, archives, and restores a task workspace" {
  local ws; ws=$(_new_workspace)
  [ -e "$ws/.git" ]
  run "$WORKFRAME" list --repo demo --json
  [ "$status" -eq 0 ]
  [[ "$output" == *'"repo":"demo"'* ]]
  [[ "$output" != *'"agent"'* ]]
  run "$WORKFRAME" archive demo/feature --yes --json
  [ "$status" -eq 0 ]
  [[ "$output" == *'"action":"archived"'* ]]
  run "$WORKFRAME" restore --json demo feature
  [ "$status" -eq 0 ]
  [[ "$output" == *'"action":"restored"'* ]]
}

@test "frontend current, path, run, and status expose no agent field" {
  local ws; ws=$(_new_workspace)
  mkdir -p "$ws/nested"
  run bash -c "cd '$ws/nested' && WORKFRAME_BACKEND=0 WORKFRAME_COLOR=0 WORKFRAME_HOME='$WORKFRAME_HOME' '$WORKFRAME' current --json"
  [ "$status" -eq 0 ]
  [[ "$output" == *'"branch":"feature"'* ]]
  [[ "$output" != *'"agent"'* ]]
  run "$WORKFRAME" run demo/feature -- git rev-parse --show-prefix
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  run "$WORKFRAME" status --json
  [ "$status" -eq 0 ]
  [[ "$output" == *'"worktrees":1'* ]]
}

@test "frontend rejects removed agent flags and commands" {
  run "$WORKFRAME" new demo feature --agent codex
  [ "$status" -ne 0 ]
  run "$WORKFRAME" agents list
  [ "$status" -ne 0 ]
  run "$WORKFRAME" list --agent codex
  [ "$status" -ne 0 ]
}

@test "completion advertises migration and no agent option" {
  run "$WORKFRAME" completion bash
  [ "$status" -eq 0 ]
  [[ "$output" == *migrate* ]]
  [[ "$output" != *'--agent'* ]]
}

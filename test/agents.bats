#!/usr/bin/env bats
# Agent registry + no silent default agent.

load helper

setup() {
  _use_backend_store
  _seed_repo demo
}

@test "agents list shows configured agents" {
  run "$WORKFRAME" agents list
  [ "$status" -eq 0 ]
  [[ "$output" == *codex* ]]
  [[ "$output" == *alpha* ]]
}

@test "agents add appends a new agent" {
  run "$WORKFRAME" agents add nova
  [ "$status" -eq 0 ]
  [[ "$output" == *nova* ]]
  run "$WORKFRAME" agents list
  [[ "$output" == *nova* ]]
}

@test "agents add rejects invalid names" {
  run "$WORKFRAME" agents add 'Bad Name'
  [ "$status" -ne 0 ]
}

@test "agents treats dotted names as fixed strings not regex" {
  run "$WORKFRAME" agents add co.ex
  [ "$status" -eq 0 ]
  run "$WORKFRAME" agents list
  [[ "$output" == *codex* ]]
  [[ "$output" == *co.ex* ]]
  run "$WORKFRAME" agents remove co.ex
  [ "$status" -eq 0 ]
  run "$WORKFRAME" agents list
  [[ "$output" == *codex* ]]
  [[ "$output" != *co.ex* ]]
}

@test "new rejects an unknown agent" {
  run "$WORKFRAME" new mystery demo feat
  [ "$status" -ne 0 ]
  [[ "$output" == *"unknown agent"* ]]
}

@test "new without agent fails in non-TTY (no silent default)" {
  # Backend path requires agent as first positional — omitting it is usage error.
  run "$WORKFRAME" new
  [ "$status" -ne 0 ]
  [[ "$output" == *usage* ]]
}

@test "agents remove refuses while worktrees exist" {
  "$WORKFRAME" new codex demo live >/dev/null 2>&1
  run "$WORKFRAME" agents remove codex
  [ "$status" -ne 0 ]
  [[ "$output" == *"active worktrees"* ]]
}

@test "agents remove rejects --force" {
  "$WORKFRAME" new codex demo live2 >/dev/null 2>&1
  run "$WORKFRAME" agents remove codex --force
  [ "$status" -ne 0 ]
  [[ "$output" == *"unknown flag"* ]]
  run "$WORKFRAME" agents list
  [[ "$output" == *codex* ]]
}

@test "WORKFRAME_VALID_AGENTS overrides agent list for the process" {
  run env WORKFRAME_VALID_AGENTS="nova alpha" "$WORKFRAME" agents list
  [ "$status" -eq 0 ]
  [[ "$output" == *nova* ]]
  [[ "$output" == *alpha* ]]
  [[ "$output" != *codex* ]]
}

@test "backend setup creates local config" {
  # Fresh store without config overwrite
  export WORKFRAME_HOME="$BATS_TEST_TMPDIR/fresh"
  mkdir -p "$WORKFRAME_HOME"
  run "$WORKFRAME" setup nova
  [ "$status" -eq 0 ]
  [ -f "$WORKFRAME_HOME/system/config/workframe.conf" ]
  grep -q 'type = local' "$WORKFRAME_HOME/system/config/workframe.conf"
  grep -q 'nova' "$WORKFRAME_HOME/system/config/workframe.conf"
}

@test "list archived shows archived branches" {
  local ws; ws=$("$WORKFRAME" new codex demo archived-list 2>/dev/null | _workspace_path)
  "$WORKFRAME" archive "$ws" >/dev/null
  run "$WORKFRAME" archived
  [ "$status" -eq 0 ]
  [[ "$output" == *archived-list* ]]
}

#!/usr/bin/env bats
# Agent registry + no silent default agent.

load helper

setup() {
  _use_backend_store
  _seed_repo demo
}

@test "agents list shows configured agents" {
  run "$WT" agents list
  [ "$status" -eq 0 ]
  [[ "$output" == *codex* ]]
  [[ "$output" == *cursor* ]]
}

@test "agents add appends a new agent" {
  run "$WT" agents add nova
  [ "$status" -eq 0 ]
  [[ "$output" == *nova* ]]
  run "$WT" agents list
  [[ "$output" == *nova* ]]
}

@test "agents add rejects invalid names" {
  run "$WT" agents add 'Bad Name'
  [ "$status" -ne 0 ]
}

@test "agents treats dotted names as fixed strings not regex" {
  run "$WT" agents add co.ex
  [ "$status" -eq 0 ]
  run "$WT" agents list
  [[ "$output" == *codex* ]]
  [[ "$output" == *co.ex* ]]
  run "$WT" agents remove co.ex
  [ "$status" -eq 0 ]
  run "$WT" agents list
  [[ "$output" == *codex* ]]
  [[ "$output" != *co.ex* ]]
}

@test "new rejects an unknown agent" {
  run "$WT" new mystery demo feat
  [ "$status" -ne 0 ]
  [[ "$output" == *"unknown agent"* ]]
}

@test "new without agent fails in non-TTY (no silent default)" {
  # Backend path requires agent as first positional — omitting it is usage error.
  run "$WT" new
  [ "$status" -ne 0 ]
  [[ "$output" == *usage* ]]
}

@test "agents remove refuses while worktrees exist" {
  "$WT" new codex demo live >/dev/null 2>&1
  run "$WT" agents remove codex
  [ "$status" -ne 0 ]
  [[ "$output" == *"active worktrees"* ]]
}

@test "agents remove --force works even with worktrees" {
  "$WT" new codex demo live2 >/dev/null 2>&1
  run "$WT" agents remove codex --force
  [ "$status" -eq 0 ]
  run "$WT" agents list
  [[ "$output" != *codex* ]]
}

@test "init creates local config" {
  # Fresh store without config overwrite
  export WT_HOME="$BATS_TEST_TMPDIR/fresh"
  mkdir -p "$WT_HOME"
  run "$WT" init cursor
  [ "$status" -eq 0 ]
  [ -f "$WT_HOME/config" ]
  grep -q 'type = local' "$WT_HOME/config"
  grep -q 'cursor' "$WT_HOME/config"
}

@test "list archived shows archived branches" {
  local ws; ws=$("$WT" new codex demo archived-list 2>/dev/null | _workspace_path)
  "$WT" archive "$ws" >/dev/null
  run "$WT" archived
  [ "$status" -eq 0 ]
  [[ "$output" == *archived-list* ]]
}

#!/usr/bin/env bats
# Backend worktree lifecycle + destructive-action safety, exercised in-process
# (WT_BACKEND=1) against a hermetic local store. This is the code path that the
# 2026-07-13 incident touched, so it gets the most coverage.

load helper

setup() {
  _use_backend_store
  _seed_repo demo
}

@test "new creates a worktree on an agent branch" {
  run "$WT" new codex demo fix-login
  [ "$status" -eq 0 ]
  local ws; ws=$(printf '%s\n' "$output" | _workspace_path)
  [ -n "$ws" ]
  [ -e "$ws/.git" ]
  run git -C "$WT_HOME/repos/demo" branch --list codex/fix-login
  [ -n "$output" ]
}

@test "new without args is a usage error" {
  run "$WT" new
  [ "$status" -ne 0 ]
  [[ "$output" == *usage* ]]
}

@test "list shows an active worktree" {
  "$WT" new codex demo fix-login
  run "$WT" list
  [ "$status" -eq 0 ]
  [[ "$output" == *demo* ]]
  [[ "$output" == *fix-login* ]]
}

@test "archive removes the folder but keeps the branch; archived lists it" {
  local ws; ws=$("$WT" new codex demo feat-x 2>/dev/null | _workspace_path)
  run "$WT" archive "$ws"
  [ "$status" -eq 0 ]
  [[ "$output" == *"archived: codex/feat-x"* ]]
  [ ! -e "$ws/.git" ]
  run git -C "$WT_HOME/repos/demo" branch --list codex/feat-x
  [ -n "$output" ]
  run "$WT" archived
  [[ "$output" == *feat-x* ]]
}

@test "archive refuses a dirty worktree without --yes (exit 3)" {
  local ws; ws=$("$WT" new codex demo dirty 2>/dev/null | _workspace_path)
  echo change >> "$ws/README.md"
  run "$WT" archive "$ws"
  [ "$status" -eq 3 ]
  [[ "$output" == *DIRTY* ]]
}

@test "archive refuses a path outside the workspace root" {
  run "$WT" archive "$WT_HOME/repos/demo"
  [ "$status" -ne 0 ]
  [[ "$output" == *refusing* ]]
}

@test "restore recreates a worktree from an archived branch" {
  local ws; ws=$("$WT" new codex demo comeback 2>/dev/null | _workspace_path)
  "$WT" archive "$ws" >/dev/null
  run "$WT" restore demo codex/comeback
  [ "$status" -eq 0 ]
  local ws2; ws2=$(printf '%s\n' "$output" | _workspace_path)
  [ -e "$ws2/.git" ]
}

@test "rmbranch refuses while the branch is active" {
  "$WT" new codex demo active >/dev/null 2>&1
  run "$WT" rmbranch demo codex/active
  [ "$status" -ne 0 ]
  [[ "$output" == *active* ]]
}

@test "rmbranch deletes an archived branch permanently" {
  local ws; ws=$("$WT" new codex demo gone 2>/dev/null | _workspace_path)
  "$WT" archive "$ws" >/dev/null
  run "$WT" rmbranch demo codex/gone
  [ "$status" -eq 0 ]
  [[ "$output" == *"removed branch: codex/gone"* ]]
  run git -C "$WT_HOME/repos/demo" branch --list codex/gone
  [ -z "$output" ]
}

@test "remove branch is a CLI alias for rmbranch" {
  local ws; ws=$("$WT" new codex demo alias-rm 2>/dev/null | _workspace_path)
  "$WT" archive "$ws" >/dev/null
  run "$WT" remove branch demo codex/alias-rm
  [ "$status" -eq 0 ]
  [[ "$output" == *"removed branch: codex/alias-rm"* ]]
}

@test "remove without subcommand is a usage error" {
  run "$WT" remove
  [ "$status" -ne 0 ]
  [[ "$output" == *"usage: wt remove branch"* ]]
}

@test "remove repo deletes a canonical clone" {
  "$WT" new codex demo doomed >/dev/null 2>&1
  run "$WT" remove repo demo --force
  [ "$status" -eq 0 ]
  [[ "$output" == *"deleted repo: demo"* ]]
  [ ! -d "$WT_HOME/repos/demo" ]
}

@test "clean is a dry run by default" {
  "$WT" new codex demo keep >/dev/null 2>&1
  run "$WT" clean
  [ "$status" -eq 0 ]
  [[ "$output" == *"dry run"* ]]
}

@test "unknown backend command errors" {
  run "$WT" frobnicate
  [ "$status" -ne 0 ]
  [[ "$output" == *"unknown box command"* ]]
}

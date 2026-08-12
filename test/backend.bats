#!/usr/bin/env bats
# Task-owned worktree lifecycle + destructive-action safety.

load helper

setup() {
  _use_backend_store
  _seed_repo demo
}

@test "new creates a Conductor-compatible task worktree" {
  run "$WORKFRAME" new demo fix-login
  [ "$status" -eq 0 ]
  local ws; ws=$(printf '%s\n' "$output" | _workspace_path)
  [[ "$ws" == */workspaces/demo/* ]]
  [ -e "$ws/.git" ]
  run git -C "$WORKFRAME_HOME/repos/demo" branch --list fix-login
  [ -n "$output" ]
}

@test "new accepts only repo and task" {
  run "$WORKFRAME" new codex demo fix-login
  [ "$status" -ne 0 ]
  [[ "$output" == *'usage: new <repo> <task>'* ]]
}

@test "worktrees uses four stable TSV fields" {
  "$WORKFRAME" new demo visible >/dev/null
  run "$WORKFRAME" worktrees
  [ "$status" -eq 0 ]
  local fields; fields=$(printf '%s\n' "$output" | awk -F '\t' 'NF { print NF; exit }')
  [ "$fields" = 4 ]
  [[ "$output" == demo$'\t'*$'\t'*$'\t'visible ]]
}

@test "archive and restore preserve an unprefixed branch" {
  local ws; ws=$("$WORKFRAME" new demo feat-x 2>/dev/null | _workspace_path)
  run "$WORKFRAME" archive "$ws"
  [ "$status" -eq 0 ]
  [[ "$output" == *'archived: feat-x'* ]]
  [ ! -e "$ws/.git" ]
  run "$WORKFRAME" restore demo feat-x
  [ "$status" -eq 0 ]
  [ -e "$(printf '%s\n' "$output" | _workspace_path)/.git" ]
}

@test "archive protects dirty work unless force is explicit" {
  local ws; ws=$("$WORKFRAME" new demo dirty 2>/dev/null | _workspace_path)
  printf 'change\n' >> "$ws/README.md"
  run "$WORKFRAME" archive "$ws" --yes
  [ "$status" -eq 3 ]
  [ -e "$ws/.git" ]
  run "$WORKFRAME" archive "$ws" --force
  [ "$status" -eq 0 ]
  [ ! -e "$ws" ]
}

@test "selectors and removal reject workspace paths outside the managed layout" {
  run "$WORKFRAME" archive "$WORKFRAME_HOME/repos/demo"
  [ "$status" -ne 0 ]
  run "$WORKFRAME" remove repo '../escape' --force --yes
  [ "$status" -ne 0 ]
  [[ "$output" == *'invalid repo name'* ]]
}

@test "feature validation keeps safe task branches and rejects unsafe refs" {
  local bad
  for bad in '   ' '-x' '..' 'x.lock' 'a//b' '/lead' 'trail/'; do
    run "$WORKFRAME" new demo "$bad"
    [ "$status" -ne 0 ]
  done
  run "$WORKFRAME" new demo 'sub/feat'
  [ "$status" -eq 0 ]
  run git -C "$WORKFRAME_HOME/repos/demo" branch --list sub/feat
  [ -n "$output" ]
}

@test "clean and repository removal preserve the documented safety boundary" {
  local ws; ws=$("$WORKFRAME" new demo orphaned 2>/dev/null | _workspace_path)
  rm "$ws/.git"
  run "$WORKFRAME" clean --yes
  [ "$status" -eq 0 ]
  [ ! -e "$ws" ]

  git -C "$WORKFRAME_HOME/repos/demo" worktree add -q -b external "$BATS_TEST_TMPDIR/external"
  "$WORKFRAME" new demo inside >/dev/null
  run "$WORKFRAME" remove repo demo --yes
  [ "$status" -eq 3 ]
  [ -d "$BATS_TEST_TMPDIR/external" ]
}

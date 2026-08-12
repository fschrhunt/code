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
  git -C "$WORKFRAME_HOME/repos/demo" show-ref --verify --quiet refs/workframe/managed/fix-login
}

@test "new starts from the freshly fetched default branch" {
  local origin="$BATS_TEST_TMPDIR/demo-origin.git" seed="$BATS_TEST_TMPDIR/demo-seed"
  printf 'fresh\n' >> "$seed/README.md"
  git -C "$seed" add README.md
  git -C "$seed" commit -qm fresh
  git -C "$seed" push -q origin main

  run "$WORKFRAME" new demo fresh-tip
  [ "$status" -eq 0 ]
  local ws; ws=$(_workspace_path <<<"$output")
  [ "$(git -C "$ws" rev-parse HEAD)" = "$(git -C "$origin" rev-parse main)" ]
}

@test "new refuses stale work when it cannot fetch" {
  git -C "$WORKFRAME_HOME/repos/demo" remote set-url origin "$BATS_TEST_TMPDIR/missing-origin.git"

  run "$WORKFRAME" new demo requires-fetch
  [ "$status" -ne 0 ]
  [[ "$output" == *"could not refresh 'demo'"* ]]
  [ -z "$(git -C "$WORKFRAME_HOME/repos/demo" branch --list requires-fetch)" ]
}

@test "new offline uses the local remote ref" {
  git -C "$WORKFRAME_HOME/repos/demo" remote set-url origin "$BATS_TEST_TMPDIR/missing-origin.git"

  run "$WORKFRAME" new --offline demo disconnected
  [ "$status" -eq 0 ]
  [ -e "$(_workspace_path <<<"$output")/.git" ]
}

@test "new prints only its workspace path" {
  run "$WORKFRAME" new demo clean-output
  [ "$status" -eq 0 ]
  [[ "$output" == */workspaces/demo/* ]]
  [[ "$output" != *$'\n'* ]]
}

@test "new accepts only repo and task" {
  run "$WORKFRAME" new codex demo fix-login
  [ "$status" -ne 0 ]
  [[ "$output" == *'usage: new [--offline] <repo> <task>'* ]]
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

@test "lifecycle ignores compatible worktrees that Workframe did not create" {
  local foreign="$WORKFRAME_HOME/workspaces/demo/conductor-city"
  mkdir -p "$(dirname "$foreign")"
  git -C "$WORKFRAME_HOME/repos/demo" worktree add -q -b conductor-task "$foreign" origin/main

  run "$WORKFRAME" worktrees
  [ "$status" -eq 0 ]
  [[ "$output" != *conductor-city* ]]

  run "$WORKFRAME" archive "$foreign"
  [ "$status" -ne 0 ]
  [ -e "$foreign/.git" ]

  run "$WORKFRAME" remove branch demo conductor-task --yes
  [ "$status" -ne 0 ]
  git -C "$WORKFRAME_HOME/repos/demo" show-ref --verify --quiet refs/heads/conductor-task

  run "$WORKFRAME" remove repo demo --force --yes
  [ "$status" -ne 0 ]
  [ -e "$foreign/.git" ]
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

@test "archive rejects paths outside the managed layout" {
  run "$WORKFRAME" archive "$WORKFRAME_HOME/repos/demo"
  [ "$status" -ne 0 ]
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

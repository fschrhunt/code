#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

load helper

setup() { _use_test_root; }

@test "new creates a worktree on a named branch" {
  _seed_repo demo
  cd "$CODE_ROOT/repos/demo"

  run --separate-stderr "$CODE" new feat/thing

  [ "$status" -eq 0 ]
  [ "$output" = "$CODE_ROOT/worktrees/feat-thing" ]
  [ "$(git -C "$CODE_ROOT/worktrees/feat-thing" symbolic-ref --short HEAD)" = "feat/thing" ]
}

@test "new checks out an existing local branch" {
  _seed_repo demo
  git -C "$CODE_ROOT/repos/demo" branch feat/existing
  cd "$CODE_ROOT/repos/demo"

  run "$CODE" new feat/existing

  [ "$status" -eq 0 ]
  [ "$(git -C "$CODE_ROOT/worktrees/feat-existing" symbolic-ref --short HEAD)" = "feat/existing" ]
}

@test "new refuses an occupied worktree name" {
  _seed_repo demo
  cd "$CODE_ROOT/repos/demo"
  "$CODE" new task > /dev/null

  run "$CODE" new task

  [ "$status" -ne 0 ]
}

@test "remove refuses dirty work without --force" {
  _seed_repo demo
  cd "$CODE_ROOT/repos/demo"
  "$CODE" new task > /dev/null
  printf 'change\n' > "$CODE_ROOT/worktrees/task/file.txt"

  run "$CODE" remove task

  [ "$status" -ne 0 ]
  [ -d "$CODE_ROOT/worktrees/task" ]
}

@test "remove --force discards work and keeps the branch" {
  _seed_repo demo
  cd "$CODE_ROOT/repos/demo"
  "$CODE" new task > /dev/null
  printf 'change\n' > "$CODE_ROOT/worktrees/task/file.txt"

  run "$CODE" remove task --force

  [ "$status" -eq 0 ]
  [ ! -e "$CODE_ROOT/worktrees/task" ]
  git -C "$CODE_ROOT/repos/demo" show-ref --verify --quiet refs/heads/task
}

@test "list shows repositories and their worktrees" {
  _seed_repo demo
  cd "$CODE_ROOT/repos/demo"
  "$CODE" new task > /dev/null

  run "$CODE" list

  [ "$status" -eq 0 ]
  [[ "$output" == *"Repositories"* ]]
  [[ "$output" == *"demo"* ]]
  [[ "$output" == *"demo/task"* ]]
}

@test "new resolves a symlinked root" {
  _seed_repo demo
  ln -s "$CODE_ROOT" "$BATS_TEST_TMPDIR/link"
  export CODE_ROOT="$BATS_TEST_TMPDIR/link"
  cd "$BATS_TEST_TMPDIR/link/repos/demo"

  run --separate-stderr "$CODE" new task

  [ "$status" -eq 0 ]
  [ "$(git -C "$CODE_ROOT/worktrees/task" symbolic-ref --short HEAD)" = "task" ]
}

@test "new rejects a flag-like branch name" {
  _seed_repo demo
  cd "$CODE_ROOT/repos/demo"

  run "$CODE" new --worktree

  [ "$status" -ne 0 ]
  [[ "$output" == *"must not start with"* ]]
}

@test "help byte-matches the golden fixture" {
  local output_file="$BATS_TEST_TMPDIR/help.out"
  "$CODE" help > "$output_file"
  diff -u "$BATS_TEST_DIRNAME/golden/help.txt" "$output_file"
}

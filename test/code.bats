#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

load helper

setup() { _use_test_root; }

@test "new creates a detached worktree named <agent>-<repo>" {
  _seed_repo demo
  cd "$CODE_ROOT/repos/demo"

  run --separate-stderr "$CODE" new pi

  [ "$status" -eq 0 ]
  [ "$output" = "$CODE_ROOT/worktrees/pi-demo" ]
  [ -z "$(git -C "$CODE_ROOT/worktrees/pi-demo" branch --show-current)" ]
}

@test "new suffixes an occupied name" {
  _seed_repo demo
  cd "$CODE_ROOT/repos/demo"
  "$CODE" new pi > /dev/null

  run --separate-stderr "$CODE" new pi

  [ "$status" -eq 0 ]
  [ "$output" = "$CODE_ROOT/worktrees/pi-demo-1" ]
}

@test "new reattaches an existing branch" {
  _seed_repo demo
  git -C "$CODE_ROOT/repos/demo" branch pi-demo
  cd "$CODE_ROOT/repos/demo"

  run --separate-stderr "$CODE" new pi

  [ "$status" -eq 0 ]
  [ "$(git -C "$CODE_ROOT/worktrees/pi-demo" symbolic-ref --short HEAD)" = "pi-demo" ]
}

@test "remove refuses dirty work without --force" {
  _seed_repo demo
  cd "$CODE_ROOT/repos/demo"
  "$CODE" new pi > /dev/null
  printf 'change\n' > "$CODE_ROOT/worktrees/pi-demo/file.txt"

  run "$CODE" remove pi-demo

  [ "$status" -ne 0 ]
  [ -d "$CODE_ROOT/worktrees/pi-demo" ]
}

@test "remove --force discards work" {
  _seed_repo demo
  cd "$CODE_ROOT/repos/demo"
  "$CODE" new pi > /dev/null
  printf 'change\n' > "$CODE_ROOT/worktrees/pi-demo/file.txt"

  run "$CODE" remove pi-demo --force

  [ "$status" -eq 0 ]
  [ ! -e "$CODE_ROOT/worktrees/pi-demo" ]
}

@test "list shows repositories and their worktrees" {
  _seed_repo demo
  cd "$CODE_ROOT/repos/demo"
  "$CODE" new pi > /dev/null

  run "$CODE" list

  [ "$status" -eq 0 ]
  [[ "$output" == *"Repositories"* ]]
  [[ "$output" == *"demo"* ]]
  [[ "$output" == *"demo/pi-demo"* ]]
}

@test "new resolves a symlinked root" {
  _seed_repo demo
  ln -s "$CODE_ROOT" "$BATS_TEST_TMPDIR/link"
  export CODE_ROOT="$BATS_TEST_TMPDIR/link"
  cd "$BATS_TEST_TMPDIR/link/repos/demo"

  run --separate-stderr "$CODE" new pi

  [ "$status" -eq 0 ]
  [ -e "$CODE_ROOT/worktrees/pi-demo/.git" ]
}

@test "new rejects a flag-like name" {
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

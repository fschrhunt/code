#!/usr/bin/env bats

load helper

@test "help output byte-matches the golden fixture" {
  local output_file="$BATS_TEST_TMPDIR/help.out"
  "$WORKSPACES" help > "$output_file"
  diff -u "$BATS_TEST_DIRNAME/golden/help.txt" "$output_file"
}

@test "help describes repositories and nested task worktrees" {
  run "$WORKSPACES" help
  [ "$status" -eq 0 ]
  [[ "$output" == *'workspaces new [<repo> [task]]'* ]]
  [[ "$output" == *'can discover the repository'* ]]
  [[ "$output" == *'creates or upgrades the root'* ]]
  [[ "$output" == *'repos/<repo>'* ]]
  [[ "$output" == *'worktrees/<repo>/<task>'* ]]
  [[ "$output" == *'unused world capital'* ]]
  [[ "$output" == *'Workspaces only removes worktrees it created.'* ]]
  [[ "$output" != *'ws'* ]]
  [[ "$output" != *'archive'* ]]
  [[ "$output" != *'agent'* ]]
}

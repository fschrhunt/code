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
  [[ "$output" == *'workspaces new <repo> [task]'* ]]
  [[ "$output" == *'~/workspaces/repos'* ]]
  [[ "$output" == *'worktrees/<repo>/<task>'* ]]
  [[ "$output" == *'unused world capital'* ]]
  [[ "$output" == *'`ws` is the short alias'* ]]
  [[ "$output" != *'archive'* ]]
  [[ "$output" != *'agent'* ]]
}

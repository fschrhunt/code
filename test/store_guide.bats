#!/usr/bin/env bats
# Store-level agent guidance is provisioned safely for local and shared roots.

load helper

@test "backend setup creates the shipped store guide" {
  local store="$BATS_TEST_TMPDIR/local-store"

  run env WORKFRAME_BACKEND=1 WORKFRAME_COLOR=0 WORKFRAME_HOME="$store" \
    "$WORKFRAME" setup nova

  [ "$status" -eq 0 ]
  [ -f "$store/WORKFRAME.md" ]
  cmp "$BATS_TEST_DIRNAME/../lib/WORKFRAME.md" "$store/WORKFRAME.md"
  grep -q 'Work only in the current worktree' "$store/WORKFRAME.md"
  grep -q 'Do not implement' "$store/WORKFRAME.md"
}

@test "setup never overwrites an existing store guide" {
  local store="$BATS_TEST_TMPDIR/custom-store"
  mkdir -p "$store"
  printf 'custom agent contract\n' > "$store/WORKFRAME.md"

  run env WORKFRAME_BACKEND=1 WORKFRAME_COLOR=0 WORKFRAME_HOME="$store" \
    "$WORKFRAME" setup nova

  [ "$status" -eq 0 ]
  [ "$(cat "$store/WORKFRAME.md")" = "custom agent contract" ]
}

@test "repeated local setup repairs a missing guide and migrates legacy config" {
  local store="$BATS_TEST_TMPDIR/existing-store"
  mkdir -p "$store"
  printf 'type = local\neditor = cursor\nagents = codex\n' > "$store/config"

  run env -u WORKFRAME_BACKEND WORKFRAME_COLOR=0 WORKFRAME_HOME="$store" \
    "$WORKFRAME" setup

  [ "$status" -eq 0 ]
  [ -f "$store/WORKFRAME.md" ]
  [ ! -e "$store/config" ]
  [ -f "$store/system/config/workframe.conf" ]
  grep -q '^type = local$' "$store/system/config/workframe.conf"
  grep -q '^editor = cursor$' "$store/system/config/workframe.conf"
  grep -q '^agents = codex$' "$store/system/config/workframe.conf"
  [[ "$output" == *"config moved"* ]]
  [[ "$output" == *"local profile already"* ]]
}

@test "backend guide provisions the actual shared store root" {
  local box_root="$BATS_TEST_TMPDIR/shared-root"

  run env WORKFRAME_BACKEND=1 WORKFRAME_COLOR=0 WORKFRAME_HOME="$box_root" \
    "$WORKFRAME" guide

  [ "$status" -eq 0 ]
  [ -f "$box_root/WORKFRAME.md" ]
  [[ "$output" == *"guide: $box_root/WORKFRAME.md"* ]]
  cmp "$BATS_TEST_DIRNAME/../lib/WORKFRAME.md" "$box_root/WORKFRAME.md"
}

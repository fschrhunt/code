#!/usr/bin/env bats
# Root selection defaults to ~/workspaces and ignores the retired namespace.

load helper

setup() { _use_test_root; }

@test "default root is HOME/workspaces" {
  local home="$BATS_TEST_TMPDIR/home"
  mkdir -p "$home"

  run env -u XDG_CONFIG_HOME -u WORKSPACES_ROOT HOME="$home" "$WORKSPACES" root

  [ "$status" -eq 0 ]
  [ "$output" = "$home/workspaces" ]
}

@test "WORKSPACES_ROOT overrides the saved and default roots" {
  local override="$BATS_TEST_TMPDIR/override"
  mkdir -p "$override"
  override=$(cd -P "$override" && pwd)

  run env WORKSPACES_ROOT="$override" "$WORKSPACES" root

  [ "$status" -eq 0 ]
  [ "$output" = "$override" ]
}

@test "relative WORKSPACES_ROOT is rejected" {
  run env WORKSPACES_ROOT=relative/path "$WORKSPACES" root

  [ "$status" -ne 0 ]
  [[ "$output" == *'invalid WORKSPACES_ROOT'* ]]
}

@test "saved root selects a custom collection" {
  local selected="$BATS_TEST_TMPDIR/selected"
  mkdir -p "$XDG_CONFIG_HOME/workspaces" "$selected"
  selected=$(cd -P "$selected" && pwd)
  printf '%s\n' "$selected" > "$XDG_CONFIG_HOME/workspaces/root"
  unset WORKSPACES_ROOT

  run "$WORKSPACES" root

  [ "$status" -eq 0 ]
  [ "$output" = "$selected" ]
}

@test "invalid saved root falls back to HOME/workspaces" {
  local home="$BATS_TEST_TMPDIR/home"
  mkdir -p "$XDG_CONFIG_HOME/workspaces" "$home"
  printf 'relative/path\n' > "$XDG_CONFIG_HOME/workspaces/root"
  unset WORKSPACES_ROOT

  run env HOME="$home" XDG_CONFIG_HOME="$XDG_CONFIG_HOME" "$WORKSPACES" root

  [ "$status" -eq 0 ]
  [ "$output" = "$home/workspaces" ]
}

@test "old Workframe roots and environment variables remain untouched" {
  local home="$BATS_TEST_TMPDIR/home" old="$BATS_TEST_TMPDIR/old"
  mkdir -p "$home/workframe" "$old"
  printf 'keep\n' > "$home/workframe/marker"
  unset WORKSPACES_ROOT

  run env HOME="$home" XDG_CONFIG_HOME="$XDG_CONFIG_HOME" WORKFRAME_HOME="$old" "$WORKSPACES" root

  [ "$status" -eq 0 ]
  [ "$output" = "$home/workspaces" ]
  [ "$(cat "$home/workframe/marker")" = keep ]
}

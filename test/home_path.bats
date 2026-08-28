#!/usr/bin/env bats
# Root selection defaults to ~/Code and ignores the retired namespace.

load helper

setup() { _use_test_root; }

@test "default root is HOME/Code" {
  local home="$BATS_TEST_TMPDIR/home"
  mkdir -p "$home"

  run env -u XDG_CONFIG_HOME -u CODE_ROOT HOME="$home" "$CODE" root

  [ "$status" -eq 0 ]
  [ "$output" = "$home/Code" ]
}

@test "CODE_ROOT overrides the saved and default roots" {
  local override="$BATS_TEST_TMPDIR/override"
  mkdir -p "$override"
  override=$(cd -P "$override" && pwd)

  run env CODE_ROOT="$override" "$CODE" root

  [ "$status" -eq 0 ]
  [ "$output" = "$override" ]
}

@test "relative CODE_ROOT is rejected" {
  run env CODE_ROOT=relative/path "$CODE" root

  [ "$status" -ne 0 ]
  [[ "$output" == *'invalid CODE_ROOT'* ]]
}

@test "saved root selects a custom collection" {
  local selected="$BATS_TEST_TMPDIR/selected"
  mkdir -p "$XDG_CONFIG_HOME/code" "$selected"
  selected=$(cd -P "$selected" && pwd)
  printf '%s\n' "$selected" > "$XDG_CONFIG_HOME/code/root"
  unset CODE_ROOT

  run "$CODE" root

  [ "$status" -eq 0 ]
  [ "$output" = "$selected" ]
}

@test "invalid saved root falls back to HOME/Code" {
  local home="$BATS_TEST_TMPDIR/home"
  mkdir -p "$XDG_CONFIG_HOME/code" "$home"
  printf 'relative/path\n' > "$XDG_CONFIG_HOME/code/root"
  unset CODE_ROOT

  run env HOME="$home" XDG_CONFIG_HOME="$XDG_CONFIG_HOME" "$CODE" root

  [ "$status" -eq 0 ]
  [ "$output" = "$home/Code" ]
}

@test "old Workframe roots and environment variables remain untouched" {
  local home="$BATS_TEST_TMPDIR/home" old="$BATS_TEST_TMPDIR/old"
  mkdir -p "$home/workframe" "$old"
  printf 'keep\n' > "$home/workframe/marker"
  unset CODE_ROOT

  run env HOME="$home" XDG_CONFIG_HOME="$XDG_CONFIG_HOME" WORKFRAME_HOME="$old" "$CODE" root

  [ "$status" -eq 0 ]
  [ "$output" = "$home/Code" ]
  [ "$(cat "$home/workframe/marker")" = keep ]
}

#!/usr/bin/env bats

@test "installer links only the Workframe command" {
  local bindir="$BATS_TEST_TMPDIR/bin"
  local old_name expected
  old_name=$(printf '%s%s' w t)
  expected="$(cd "$BATS_TEST_DIRNAME/.." && pwd)/bin/workframe"

  run "$BATS_TEST_DIRNAME/../install.sh" "$bindir"

  [ "$status" -eq 0 ]
  [ -L "$bindir/workframe" ]
  [ "$(readlink "$bindir/workframe")" = "$expected" ]
  [ ! -e "$bindir/$old_name" ]
  [[ "$output" == *"linked $bindir/workframe"* ]]
}

@test "installed command can provision the shipped store guide" {
  local bindir="$BATS_TEST_TMPDIR/bin"
  local store="$BATS_TEST_TMPDIR/store"

  "$BATS_TEST_DIRNAME/../install.sh" "$bindir" >/dev/null
  run env WORKFRAME_BACKEND=1 WORKFRAME_COLOR=0 WORKFRAME_HOME="$store" \
    "$bindir/workframe" init codex

  [ "$status" -eq 0 ]
  cmp "$BATS_TEST_DIRNAME/../lib/WORKFRAME.md" "$store/WORKFRAME.md"
}

@test "mount helper names every required Workframe setting" {
  local user_home="$BATS_TEST_TMPDIR/home"
  mkdir -p "$user_home"

  run env HOME="$user_home" bash "$BATS_TEST_DIRNAME/../contrib/mount-workframe.sh"

  [ "$status" -eq 1 ]
  [[ "$output" == *"WORKFRAME_SHARE_NAME"* ]]
  [[ "$output" == *"WORKFRAME_BOX_USER"* ]]
  [[ "$output" == *"WORKFRAME_MOUNT_PATH"* ]]
  [[ "$output" == *"WORKFRAME_BOX_ADDR"* ]]
  [[ "$output" == *"~/workframe/config"* ]]
}

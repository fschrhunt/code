#!/usr/bin/env bats

@test "installer links only the Workframe command and its short name" {
  local bindir="$BATS_TEST_TMPDIR/bin"
  local old_name expected
  old_name=$(printf '%s%s' w t)
  expected="$(cd "$BATS_TEST_DIRNAME/.." && pwd)/bin/workframe"

  run "$BATS_TEST_DIRNAME/../install.sh" "$bindir"

  [ "$status" -eq 0 ]
  [ -L "$bindir/workframe" ]
  [ "$(readlink "$bindir/workframe")" = "$expected" ]
  [ -L "$bindir/wf" ]
  [ "$(readlink "$bindir/wf")" = "$expected" ]
  [ ! -e "$bindir/$old_name" ]
  [[ "$output" == *"linked $bindir/workframe"* ]]
  [[ "$output" == *"linked $bindir/wf"* ]]
  [[ "$output" == *"next:   workframe setup"* ]]
}

@test "the short name runs the same command" {
  local bindir="$BATS_TEST_TMPDIR/bin"
  local store="$BATS_TEST_TMPDIR/store"

  "$BATS_TEST_DIRNAME/../install.sh" "$bindir" >/dev/null
  run env WORKFRAME_COLOR=0 WORKFRAME_HOME="$store" "$bindir/wf" version

  [ "$status" -eq 0 ]
  [ "$output" = "workframe $(cat "$BATS_TEST_DIRNAME/../VERSION")" ]

  run env WORKFRAME_COLOR=0 WORKFRAME_HOME="$store" "$bindir/wf" help
  [ "$status" -eq 0 ]
  [[ "$output" == *"interactive workspace wizard"* ]]
}

@test "installed command can provision the shipped store guide" {
  local bindir="$BATS_TEST_TMPDIR/bin"
  local store="$BATS_TEST_TMPDIR/store"

  "$BATS_TEST_DIRNAME/../install.sh" "$bindir" >/dev/null
  run env WORKFRAME_BACKEND=1 WORKFRAME_COLOR=0 WORKFRAME_HOME="$store" \
    "$bindir/workframe" setup codex

  [ "$status" -eq 0 ]
  cmp "$BATS_TEST_DIRNAME/../lib/WORKFRAME.md" "$store/WORKFRAME.md"
}

@test "installer replaces a command symlink that points to a directory" {
  local bindir="$BATS_TEST_TMPDIR/bin"
  local old_target="$BATS_TEST_TMPDIR/old-target"
  local expected
  expected="$(cd "$BATS_TEST_DIRNAME/.." && pwd)/bin/workframe"
  mkdir -p "$bindir" "$old_target"
  ln -s "$old_target" "$bindir/workframe"
  ln -s "$old_target" "$bindir/wf"

  run "$BATS_TEST_DIRNAME/../install.sh" "$bindir"

  [ "$status" -eq 0 ]
  [ -L "$bindir/workframe" ]
  [ "$(readlink "$bindir/workframe")" = "$expected" ]
  [ -L "$bindir/wf" ]
  [ "$(readlink "$bindir/wf")" = "$expected" ]
  [ ! -e "$old_target/workframe" ]
  [ ! -e "$old_target/wf" ]
}

@test "installer refuses to write inside a directory at the command path" {
  local bindir="$BATS_TEST_TMPDIR/bin"
  mkdir -p "$bindir/workframe"

  run "$BATS_TEST_DIRNAME/../install.sh" "$bindir"

  [ "$status" -ne 0 ]
  [[ "$output" == *"refusing to replace directory"* ]]
  [ -d "$bindir/workframe" ]
  [ ! -e "$bindir/workframe/workframe" ]
  [ ! -e "$bindir/wf" ]
}

@test "installer refuses a directory at the short-name path before linking anything" {
  local bindir="$BATS_TEST_TMPDIR/bin"
  mkdir -p "$bindir/wf"

  run "$BATS_TEST_DIRNAME/../install.sh" "$bindir"

  [ "$status" -ne 0 ]
  [[ "$output" == *"refusing to replace directory"* ]]
  [ -d "$bindir/wf" ]
  [ ! -e "$bindir/wf/workframe" ]
  [ ! -e "$bindir/workframe" ]
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
  [[ "$output" == *"workframe setup --shared"* ]]
}

@test "mount helper refuses a permissive credential seed" {
  local user_home="$BATS_TEST_TMPDIR/home"
  mkdir -p "$user_home" "$BATS_TEST_TMPDIR/mount"
  printf 'not-a-real-password\n' > "$user_home/.workframe-cred.seed"
  chmod 644 "$user_home/.workframe-cred.seed"

  run env \
    HOME="$user_home" \
    WORKFRAME_SHARE_NAME=workframe \
    WORKFRAME_BOX_USER=workframe \
    WORKFRAME_MOUNT_PATH="$BATS_TEST_TMPDIR/mount" \
    WORKFRAME_BOX_ADDR=192.0.2.10 \
    bash "$BATS_TEST_DIRNAME/../contrib/mount-workframe.sh"

  [ "$status" -eq 1 ]
  [[ "$output" == *"refusing credential seed"* ]]
  [ -f "$user_home/.workframe-cred.seed" ]
}

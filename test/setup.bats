#!/usr/bin/env bats
# First-run setup and persistent local-root selection.

load helper

@test "fresh install diagnostics point to setup instead of reporting a healthy store" {
  local user_home="$BATS_TEST_TMPDIR/home"
  mkdir -p "$user_home"

  run env -u XDG_CONFIG_HOME -u WORKFRAME_HOME -u WORKFRAME_BACKEND \
    HOME="$user_home" WORKFRAME_COLOR=0 "$WORKFRAME" doctor

  [ "$status" -eq 0 ]
  [[ "$output" == *"store not initialized at $user_home/workframe"* ]]
  [[ "$output" == *"run workframe setup"* ]]
  [[ "$output" != *"store root"* ]]

  run env -u XDG_CONFIG_HOME -u WORKFRAME_HOME -u WORKFRAME_BACKEND \
    HOME="$user_home" WORKFRAME_COLOR=0 "$WORKFRAME" status

  [ "$status" -eq 0 ]
  [[ "$output" == *"disk: not initialized — run workframe setup"* ]]
}

@test "setup remembers a custom root and task-only preferences" {
  local user_home="$BATS_TEST_TMPDIR/home"
  local volume="$BATS_TEST_TMPDIR/Attached Volume"
  local store="$volume/development/workframe"
  local pointer="$user_home/.config/workframe/root"
  local expected_root
  mkdir -p "$user_home" "$volume/development"

  run env -u XDG_CONFIG_HOME -u WORKFRAME_HOME -u WORKFRAME_BACKEND \
    HOME="$user_home" WORKFRAME_COLOR=0 \
    "$WORKFRAME" setup --local --root "$store" --editor code --org example

  [ "$status" -eq 0 ]
  [ -f "$pointer" ]
  [ "$(cat "$pointer")" = "$store" ]
  [ -f "$store/system/config/workframe.conf" ]
  [ ! -e "$store/config" ]
  [ -f "$store/WORKFRAME.md" ]
  [ -d "$store/repos" ]
  [ -d "$store/workspaces" ]
  grep -q '^type = local$' "$store/system/config/workframe.conf"
  grep -q '^editor = code$' "$store/system/config/workframe.conf"
  grep -q '^default_org = example$' "$store/system/config/workframe.conf"
  ! grep -q '^agents =' "$store/system/config/workframe.conf"
  expected_root=$(cd "$store" && pwd -P)

  run env -u XDG_CONFIG_HOME -u WORKFRAME_HOME -u WORKFRAME_BACKEND \
    HOME="$user_home" WORKFRAME_COLOR=0 bash -c '
      . "'"$BATS_TEST_DIRNAME/../lib/config.sh"'"
      printf "ROOT=%s\nCONFIG=%s\n" "$ROOT" "$WORKFRAME_USER_CONFIG"
    '

  [ "$status" -eq 0 ]
  [[ "$output" == *"ROOT=$expected_root"* ]]
  [[ "$output" == *"CONFIG=$store/system/config/workframe.conf"* ]]
}

@test "later setup updates the store selected by the root locator" {
  local user_home="$BATS_TEST_TMPDIR/home"
  local store="$BATS_TEST_TMPDIR/store"
  mkdir -p "$user_home" "$store"

  env -u XDG_CONFIG_HOME -u WORKFRAME_HOME -u WORKFRAME_BACKEND HOME="$user_home" WORKFRAME_COLOR=0 \
    "$WORKFRAME" setup --local --root "$store" >/dev/null

  run env -u XDG_CONFIG_HOME -u WORKFRAME_HOME -u WORKFRAME_BACKEND HOME="$user_home" WORKFRAME_COLOR=0 \
    "$WORKFRAME" setup --local

  [ "$status" -eq 0 ]
  ! grep -q '^agents =' "$store/system/config/workframe.conf"
  [ ! -e "$user_home/workframe/config" ]
}

@test "setup recognizes an existing symlink and its target as the same store" {
  local user_home="$BATS_TEST_TMPDIR/home"
  local store="$BATS_TEST_TMPDIR/volume/workframe"
  mkdir -p "$user_home" "$store/repos" "$store/workspaces"
  mkdir -p "$store/system/config"
  printf 'type = local\neditor = cursor\n' > "$store/system/config/workframe.conf"
  ln -s "$store" "$user_home/workframe"

  run env -u XDG_CONFIG_HOME -u WORKFRAME_HOME -u WORKFRAME_BACKEND \
    HOME="$user_home" WORKFRAME_COLOR=0 \
    "$WORKFRAME" setup --local --root "$store"

  [ "$status" -eq 0 ]
  [[ "$output" != *"existing data was not moved"* ]]
  [ "$(cat "$user_home/.config/workframe/root")" = "$store" ]
  ! grep -q '^agents =' "$store/system/config/workframe.conf"
}

@test "setup rejects a relative root without creating a locator" {
  local user_home="$BATS_TEST_TMPDIR/home"
  mkdir -p "$user_home"

  run env -u XDG_CONFIG_HOME -u WORKFRAME_HOME -u WORKFRAME_BACKEND \
    HOME="$user_home" WORKFRAME_COLOR=0 \
    "$WORKFRAME" setup --local --root relative/workframe

  [ "$status" -ne 0 ]
  [[ "$output" == *"use an absolute path"* ]]
  [ ! -e "$user_home/.config/workframe/root" ]
}

@test "commands refuse an unavailable selected root" {
  local user_home="$BATS_TEST_TMPDIR/home"
  local missing="$BATS_TEST_TMPDIR/unmounted/workframe"
  mkdir -p "$user_home/.config/workframe"
  printf '%s\n' "$missing" > "$user_home/.config/workframe/root"

  run env -u XDG_CONFIG_HOME -u WORKFRAME_HOME -u WORKFRAME_BACKEND \
    HOME="$user_home" WORKFRAME_COLOR=0 "$WORKFRAME" status

  [ "$status" -ne 0 ]
  [[ "$output" == *"selected Workframe root is unavailable"* ]]
  [[ "$output" == *"attach the volume"* ]]
  [ ! -e "$missing" ]
}

@test "WORKFRAME_HOME remains process-scoped and does not write a locator" {
  local user_home="$BATS_TEST_TMPDIR/home"
  local store="$BATS_TEST_TMPDIR/override"
  mkdir -p "$user_home"

  run env -u XDG_CONFIG_HOME HOME="$user_home" WORKFRAME_HOME="$store" WORKFRAME_COLOR=0 \
    "$WORKFRAME" setup --local

  [ "$status" -eq 0 ]
  [ -f "$store/system/config/workframe.conf" ]
  [ ! -e "$user_home/.config/workframe/root" ]
}

@test "init exposes the non-interactive bootstrap command" {
  local user_home="$BATS_TEST_TMPDIR/home"
  mkdir -p "$user_home"

  run env -u XDG_CONFIG_HOME -u WORKFRAME_HOME -u WORKFRAME_BACKEND \
    HOME="$user_home" WORKFRAME_COLOR=0 "$WORKFRAME" init --help

  [ "$status" -eq 0 ]
  [[ "$output" == *"usage: workframe init"* ]]
  [[ "$output" == *"--root <path>"* ]]
}

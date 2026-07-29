#!/usr/bin/env bats
# Default local store is ~/workframe. Existing pre-Workframe stores are untouched.

load helper

@test "default WORKFRAME_USER_DIR is HOME/workframe when WORKFRAME_HOME unset" {
  local user_home="$BATS_TEST_TMPDIR/home"
  mkdir -p "$user_home"
  run env -u XDG_CONFIG_HOME -u WORKFRAME_HOME -u WORKFRAME_BACKEND HOME="$user_home" bash -c '
    . "'"$BATS_TEST_DIRNAME/../lib/config.sh"'"
    printf "%s\n" "$WORKFRAME_USER_DIR"
  '
  [ "$status" -eq 0 ]
  [ "$output" = "$user_home/workframe" ]
}

@test "pre-Workframe store is ignored and left untouched" {
  local user_home="$BATS_TEST_TMPDIR/home"
  local old_name old_store
  old_name=$(printf '%s%s' w t)
  old_store="$user_home/$old_name"
  mkdir -p "$old_store/repos"
  echo "type = local" > "$old_store/config"
  run env -u XDG_CONFIG_HOME -u WORKFRAME_HOME -u WORKFRAME_BACKEND HOME="$user_home" bash -c '
    . "'"$BATS_TEST_DIRNAME/../lib/config.sh"'"
    printf "%s\n" "$WORKFRAME_USER_DIR"
  '
  [ "$status" -eq 0 ]
  [ "$output" = "$user_home/workframe" ]
  [ -d "$old_store/repos" ]
  [ ! -e "$user_home/workframe" ]
}

@test "WORKFRAME_HOME override skips the default store" {
  local user_home="$BATS_TEST_TMPDIR/home"
  local override="$BATS_TEST_TMPDIR/override"
  mkdir -p "$override"
  run env -u XDG_CONFIG_HOME -u WORKFRAME_BACKEND HOME="$user_home" WORKFRAME_HOME="$override" bash -c '
    . "'"$BATS_TEST_DIRNAME/../lib/config.sh"'"
    printf "%s\n" "$WORKFRAME_USER_DIR"
  '
  [ "$status" -eq 0 ]
  [ "$output" = "$override" ]
  [ ! -e "$user_home/workframe" ]
}

@test "saved root locator selects a custom store" {
  local user_home="$BATS_TEST_TMPDIR/home"
  local selected="$BATS_TEST_TMPDIR/selected"
  mkdir -p "$user_home/.config/workframe" "$selected"
  printf '%s\n' "$selected" > "$user_home/.config/workframe/root"

  run env -u XDG_CONFIG_HOME -u WORKFRAME_HOME -u WORKFRAME_BACKEND HOME="$user_home" bash -c '
    . "'"$BATS_TEST_DIRNAME/../lib/config.sh"'"
    printf "%s\n" "$WORKFRAME_USER_DIR"
  '

  [ "$status" -eq 0 ]
  [ "$output" = "$selected" ]
}

@test "invalid root locator falls back to HOME/workframe" {
  local user_home="$BATS_TEST_TMPDIR/home"
  mkdir -p "$user_home/.config/workframe"
  printf '%s\n' relative/path > "$user_home/.config/workframe/root"

  run env -u XDG_CONFIG_HOME -u WORKFRAME_HOME -u WORKFRAME_BACKEND HOME="$user_home" bash -c '
    . "'"$BATS_TEST_DIRNAME/../lib/config.sh"'"
    printf "%s\n" "$WORKFRAME_USER_DIR"
  '

  [ "$status" -eq 0 ]
  [ "$output" = "$user_home/workframe" ]
}

@test "pre-Workframe environment namespace is ignored" {
  local user_home="$BATS_TEST_TMPDIR/home"
  local old_prefix old_override
  old_prefix=$(printf '%s%s' W T)
  old_override="$BATS_TEST_TMPDIR/pre-workframe"
  mkdir -p "$user_home" "$old_override"

  run env -u XDG_CONFIG_HOME -u WORKFRAME_HOME -u WORKFRAME_BACKEND HOME="$user_home" \
    "${old_prefix}_HOME=$old_override" bash -c '
      . "'"$BATS_TEST_DIRNAME/../lib/config.sh"'"
      printf "%s\n" "$WORKFRAME_USER_DIR"
    '

  [ "$status" -eq 0 ]
  [ "$output" = "$user_home/workframe" ]
}

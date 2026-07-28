#!/usr/bin/env bats
# Default local store is ~/wt; legacy ~/.wt migrates when safe.

load helper

@test "default WT_USER_DIR is HOME/wt when WT_HOME unset" {
  local user_home="$BATS_TEST_TMPDIR/home"
  mkdir -p "$user_home"
  run env -u WT_HOME -u WT_BACKEND HOME="$user_home" bash -c '
    . "'"$BATS_TEST_DIRNAME/../lib/config.sh"'"
    printf "%s\n" "$WT_USER_DIR"
  '
  [ "$status" -eq 0 ]
  [ "$output" = "$user_home/wt" ]
}

@test "legacy ~/.wt migrates to ~/wt when modern path is absent" {
  local user_home="$BATS_TEST_TMPDIR/home"
  mkdir -p "$user_home/.wt/repos"
  echo "type = local" > "$user_home/.wt/config"
  run env -u WT_HOME -u WT_BACKEND HOME="$user_home" bash -c '
    . "'"$BATS_TEST_DIRNAME/../lib/config.sh"'" 2>/dev/null
    printf "dir=%s\n" "$WT_USER_DIR"
    test -d "'"$user_home"'/wt/repos" && echo migrated=yes
    test -e "'"$user_home"'/.wt" && echo legacy=still || echo legacy=gone
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *"dir=$user_home/wt"* ]]
  [[ "$output" == *"migrated=yes"* ]]
  [[ "$output" == *"legacy=gone"* ]]
}

@test "WT_HOME override skips default and migration" {
  local user_home="$BATS_TEST_TMPDIR/home"
  local override="$BATS_TEST_TMPDIR/override"
  mkdir -p "$user_home/.wt" "$override"
  run env -u WT_BACKEND HOME="$user_home" WT_HOME="$override" bash -c '
    . "'"$BATS_TEST_DIRNAME/../lib/config.sh"'"
    printf "%s\n" "$WT_USER_DIR"
  '
  [ "$status" -eq 0 ]
  [ "$output" = "$override" ]
  [ -d "$user_home/.wt" ]
  [ ! -e "$user_home/wt" ]
}

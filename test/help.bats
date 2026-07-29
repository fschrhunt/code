#!/usr/bin/env bats
# Help golden lock: `workframe help` output must byte-match test/golden/help.txt.
# Intentional UX changes update the golden in the same commit. Also covers `workframe version`.

load helper

@test "help output byte-matches the golden" {
  export WORKFRAME_HOME="$BATS_TEST_TMPDIR/help-store"
  mkdir -p "$WORKFRAME_HOME"
  cat > "$WORKFRAME_HOME/config" <<'EOF'
type = local
editor = cursor
default_org = example
agents = cursor
EOF
  WORKFRAME_COLOR=0 "$WORKFRAME" help > "$BATS_TEST_TMPDIR/help.out"
  run diff -u "$BATS_TEST_DIRNAME/golden/help.txt" "$BATS_TEST_TMPDIR/help.out"
  [ "$status" -eq 0 ] || { echo "$output"; false; }
}

@test "bare workframe prints help" {
  export WORKFRAME_HOME="$BATS_TEST_TMPDIR/help-store"
  mkdir -p "$WORKFRAME_HOME"
  printf 'type = local\neditor = cursor\nagents = cursor\n' > "$WORKFRAME_HOME/config"
  run bash -c "WORKFRAME_COLOR=0 WORKFRAME_HOME='$WORKFRAME_HOME' '$WORKFRAME'"
  [ "$status" -eq 0 ]
  [[ "$output" == *"START HERE"* ]]
  [[ "$output" == *"WORKSPACES"* ]]
  [[ "$output" == *"REPOSITORIES"* ]]
  [[ "$output" == *"SYSTEM"* ]]
  [[ "$output" == *"ide"* ]]
  [[ "$output" == *"workframe new"* ]]
}

@test "help header uses the brace logo without adjacent metadata" {
  export WORKFRAME_HOME="$BATS_TEST_TMPDIR/help-store"
  mkdir -p "$WORKFRAME_HOME"
  printf 'type = shared\neditor = cursor\nagents = cursor\n' > "$WORKFRAME_HOME/config"
  run bash -c "WORKFRAME_COLOR=0 WORKFRAME_HOME='$WORKFRAME_HOME' '$WORKFRAME' help"
  [ "$status" -eq 0 ]
  [[ "$output" == *"██  ████  ██"* ]]
  [[ "$output" != *"Workframe v"* ]]
  [[ "$output" != *"Isolated git worktrees"* ]]
  [[ "$output" != *"Shared profile"* ]]
}

@test "help uses the acid brand accent when color is enabled" {
  run bash -c "WORKFRAME_COLOR=1 '$WORKFRAME' help"
  [ "$status" -eq 0 ]
  [[ "$output" == *$'\e[38;2;240;251;41m'* ]]
  [[ "$output" == *$'\e[48;2;240;251;41m'* ]]
  [[ "$output" != *$'\e[38;2;58;222;161m'* ]]
}

@test "paired help commands share a fixed right-hand column" {
  run bash -c "WORKFRAME_COLOR=0 '$WORKFRAME' help"
  [ "$status" -eq 0 ]
  local command line prefix
  for command in archive restore rename sync remove config status update; do
    line=$(printf '%s\n' "$output" | grep -E "[[:space:]]${command}[[:space:]]")
    prefix=${line%%"$command"*}
    [ "${#prefix}" -eq 40 ]
  done
}

@test "help works via -h and --help too" {
  run bash -c "WORKFRAME_COLOR=0 '$WORKFRAME' -h"
  [ "$status" -eq 0 ]
  run bash -c "WORKFRAME_COLOR=0 '$WORKFRAME' --help"
  [ "$status" -eq 0 ]
}

@test "version prints the VERSION file" {
  run "$WORKFRAME" version
  [ "$status" -eq 0 ]
  [ "$output" = "workframe $(cat "$BATS_TEST_DIRNAME/../VERSION")" ]
}

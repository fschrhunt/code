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
  [[ "$output" == *"EXAMPLES"* ]]
  [[ "$output" == *"COMMANDS"* ]]
  [[ "$output" == *"ide"* ]]
  [[ "$output" == *"workframe new"* ]]
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

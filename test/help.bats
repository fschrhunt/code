#!/usr/bin/env bats
# Help golden lock: `wt help` output must byte-match test/golden/help.txt.
# Intentional UX changes update the golden in the same commit. Also covers `wt version`.

load helper

@test "help output byte-matches the golden" {
  export WT_HOME="$BATS_TEST_TMPDIR/help-store"
  mkdir -p "$WT_HOME"
  cat > "$WT_HOME/config" <<'EOF'
type = local
editor = cursor
default_org = example
agents = cursor
EOF
  WT_COLOR=0 "$WT" help > "$BATS_TEST_TMPDIR/help.out"
  run diff -u "$BATS_TEST_DIRNAME/golden/help.txt" "$BATS_TEST_TMPDIR/help.out"
  [ "$status" -eq 0 ] || { echo "$output"; false; }
}

@test "bare wt falls back to help when not a TTY" {
  export WT_HOME="$BATS_TEST_TMPDIR/help-store"
  mkdir -p "$WT_HOME"
  printf 'type = local\neditor = cursor\nagents = cursor\n' > "$WT_HOME/config"
  run bash -c "WT_COLOR=0 WT_HOME='$WT_HOME' '$WT'"
  [ "$status" -eq 0 ]
  [[ "$output" == *"WORK"* ]]
  [[ "$output" == *"SETTINGS"* ]]
  [[ "$output" == *"MORE"* ]]
  [[ "$output" == *"ide"* ]]
}

@test "help works via -h and --help too" {
  run bash -c "WT_COLOR=0 '$WT' -h"
  [ "$status" -eq 0 ]
  run bash -c "WT_COLOR=0 '$WT' --help"
  [ "$status" -eq 0 ]
}

@test "version prints the VERSION file" {
  run "$WT" version
  [ "$status" -eq 0 ]
  [ "$output" = "wt $(cat "$BATS_TEST_DIRNAME/../VERSION")" ]
}

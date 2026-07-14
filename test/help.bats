#!/usr/bin/env bats
# Behavior-preserving proof: `wt help` output must byte-match the golden captured
# from the v1 monolith before the module split. Also covers `wt version`.

load helper

@test "help output byte-matches the v1 golden" {
  WT_COLOR=0 "$WT" help > "$BATS_TEST_TMPDIR/help.out"
  run diff -u "$BATS_TEST_DIRNAME/golden/help.txt" "$BATS_TEST_TMPDIR/help.out"
  [ "$status" -eq 0 ] || { echo "$output"; false; }
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

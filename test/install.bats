#!/usr/bin/env bats

@test "installer links only the command and short alias" {
  local bindir="$BATS_TEST_TMPDIR/bin"
  local expected="$(cd "$BATS_TEST_DIRNAME/.." && pwd)/bin/workframe"

  run "$BATS_TEST_DIRNAME/../install.sh" "$bindir"

  [ "$status" -eq 0 ]
  [ "$(readlink "$bindir/workframe")" = "$expected" ]
  [ "$(readlink "$bindir/wf")" = "$expected" ]
}

@test "installed short alias runs the Workframe command" {
  local bindir="$BATS_TEST_TMPDIR/bin"
  "$BATS_TEST_DIRNAME/../install.sh" "$bindir" >/dev/null

  run "$bindir/wf" version

  [ "$status" -eq 0 ]
  [ "$output" = "workframe $(cat "$BATS_TEST_DIRNAME/../VERSION")" ]
}

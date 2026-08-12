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

@test "release installer verifies and links a versioned archive" {
  local version=2.0.0 fixture="$BATS_TEST_TMPDIR/fixture" mockbin="$BATS_TEST_TMPDIR/mockbin"
  local install_root="$BATS_TEST_TMPDIR/install" bindir="$BATS_TEST_TMPDIR/bin"
  mkdir -p "$fixture/workframe-$version/bin" "$mockbin"
  cat > "$fixture/workframe-$version/bin/workframe" <<'EOF'
#!/bin/sh
printf 'workframe fixture\n'
EOF
  chmod +x "$fixture/workframe-$version/bin/workframe"
  tar -czf "$fixture/workframe-$version.tar.gz" -C "$fixture" "workframe-$version"
  (cd "$fixture" && shasum -a 256 "workframe-$version.tar.gz" > SHA256SUMS)
  cat > "$mockbin/curl" <<'EOF'
#!/bin/sh
while [ $# -gt 0 ]; do
  case "$1" in -o) output=$2; shift 2;; *) url=$1; shift;; esac
done
case "$url" in
  *.tar.gz) cp "$WORKFRAME_FIXTURE/workframe-$WORKFRAME_VERSION.tar.gz" "$output";;
  */SHA256SUMS) cp "$WORKFRAME_FIXTURE/SHA256SUMS" "$output";;
  *) exit 1;;
esac
EOF
  chmod +x "$mockbin/curl"

  run env PATH="$mockbin:$PATH" WORKFRAME_FIXTURE="$fixture" WORKFRAME_VERSION="$version" \
    WORKFRAME_INSTALL_ROOT="$install_root" WORKFRAME_BIN_DIR="$bindir" \
    "$BATS_TEST_DIRNAME/../scripts/install.sh"

  [ "$status" -eq 0 ]
  [ "$(readlink "$bindir/workframe")" = "$install_root/$version/bin/workframe" ]
  run "$bindir/wf"
  [ "$output" = 'workframe fixture' ]
}

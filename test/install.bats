#!/usr/bin/env bats

@test "development installer links only workspaces" {
  local bindir="$BATS_TEST_TMPDIR/bin"
  local expected
  expected="$(cd "$BATS_TEST_DIRNAME/.." && pwd)/bin/workspaces"

  run "$BATS_TEST_DIRNAME/../install.sh" "$bindir"

  [ "$status" -eq 0 ]
  [ "$(readlink "$bindir/workspaces")" = "$expected" ]
  [ ! -e "$bindir/workframe" ]
  [ ! -e "$bindir/wf" ]
}

@test "development installer refuses an existing regular file" {
  local bindir="$BATS_TEST_TMPDIR/bin"
  mkdir -p "$bindir"
  printf 'keep\n' > "$bindir/workspaces"

  run "$BATS_TEST_DIRNAME/../install.sh" "$bindir"

  [ "$status" -ne 0 ]
  [ "$(cat "$bindir/workspaces")" = keep ]
}

@test "installed command reports the Workspaces version" {
  local bindir="$BATS_TEST_TMPDIR/bin"
  "$BATS_TEST_DIRNAME/../install.sh" "$bindir" >/dev/null

  run "$bindir/workspaces" version

  [ "$status" -eq 0 ]
  [ "$output" = "workspaces $(cat "$BATS_TEST_DIRNAME/../VERSION")" ]
}

@test "release installer verifies and links a versioned archive" {
  local version=3.0.0 fixture="$BATS_TEST_TMPDIR/fixture" mockbin="$BATS_TEST_TMPDIR/mockbin"
  local install_root="$BATS_TEST_TMPDIR/install" bindir="$BATS_TEST_TMPDIR/bin"
  mkdir -p "$fixture/workspaces-$version/bin" "$mockbin"
  cat > "$fixture/workspaces-$version/bin/workspaces" <<'SCRIPT'
#!/bin/sh
printf 'workspaces fixture\n'
SCRIPT
  chmod +x "$fixture/workspaces-$version/bin/workspaces"
  tar -czf "$fixture/workspaces-$version.tar.gz" -C "$fixture" "workspaces-$version"
  (cd "$fixture" && shasum -a 256 "workspaces-$version.tar.gz" > SHA256SUMS)
  cat > "$mockbin/curl" <<'SCRIPT'
#!/bin/sh
while [ $# -gt 0 ]; do
  case "$1" in -o) output=$2; shift 2;; *) url=$1; shift;; esac
done
case "$url" in
  *.tar.gz) cp "$WORKSPACES_FIXTURE/workspaces-$WORKSPACES_VERSION.tar.gz" "$output";;
  */SHA256SUMS) cp "$WORKSPACES_FIXTURE/SHA256SUMS" "$output";;
  *) exit 1;;
esac
SCRIPT
  chmod +x "$mockbin/curl"

  run env PATH="$mockbin:$PATH" WORKSPACES_FIXTURE="$fixture" WORKSPACES_VERSION="$version" \
    WORKSPACES_INSTALL_ROOT="$install_root" WORKSPACES_BIN_DIR="$bindir" \
    "$BATS_TEST_DIRNAME/../scripts/install.sh"

  [ "$status" -eq 0 ]
  [ "$(readlink "$bindir/workspaces")" = "$install_root/$version/bin/workspaces" ]
  run "$bindir/workspaces"
  [ "$output" = 'workspaces fixture' ]
}

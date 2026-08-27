#!/usr/bin/env bats

@test "development installer links only code" {
  local bindir="$BATS_TEST_TMPDIR/bin"
  local expected
  expected="$(cd "$BATS_TEST_DIRNAME/.." && pwd)/bin/code"

  run "$BATS_TEST_DIRNAME/../install.sh" "$bindir"

  [ "$status" -eq 0 ]
  [ "$(readlink "$bindir/code")" = "$expected" ]
  [ ! -e "$bindir/ws" ]
  [ ! -e "$bindir/workspaces" ]
  [ ! -e "$bindir/workframe" ]
  [ ! -e "$bindir/wf" ]
}

@test "development installer removes a prior workspaces/ws symlink pointing at an install" {
  local bindir="$BATS_TEST_TMPDIR/bin"
  local old_release="$BATS_TEST_TMPDIR/releases/4.1.0/bin/workspaces"
  local expected
  expected="$(cd "$BATS_TEST_DIRNAME/.." && pwd)/bin/code"
  mkdir -p "$bindir" "$(dirname "$old_release")"
  ln -s "$old_release" "$bindir/workspaces"
  ln -s "$old_release" "$bindir/ws"

  run "$BATS_TEST_DIRNAME/../install.sh" "$bindir"

  [ "$status" -eq 0 ]
  [ "$(readlink "$bindir/code")" = "$expected" ]
  [ ! -e "$bindir/workspaces" ]
  [ ! -e "$bindir/ws" ]
}

@test "development installer refuses an existing regular file" {
  local bindir="$BATS_TEST_TMPDIR/bin"
  mkdir -p "$bindir"
  printf 'keep\n' > "$bindir/code"

  run "$BATS_TEST_DIRNAME/../install.sh" "$bindir"

  [ "$status" -ne 0 ]
  [ "$(cat "$bindir/code")" = keep ]
}

@test "development installer preserves an unrelated ws symlink" {
  local bindir="$BATS_TEST_TMPDIR/bin" other="$BATS_TEST_TMPDIR/other-command"
  mkdir -p "$bindir"
  printf '#!/bin/sh\n' > "$other"
  ln -s "$other" "$bindir/ws"

  run "$BATS_TEST_DIRNAME/../install.sh" "$bindir"

  [ "$status" -eq 0 ]
  [ "$(readlink "$bindir/ws")" = "$other" ]
  [ -L "$bindir/code" ]
}

@test "installed commands report the Code version" {
  local bindir="$BATS_TEST_TMPDIR/bin"
  "$BATS_TEST_DIRNAME/../install.sh" "$bindir" >/dev/null

  run "$bindir/code" version
  [ "$status" -eq 0 ]
  [ "$output" = "code $(cat "$BATS_TEST_DIRNAME/../VERSION")" ]
}

@test "release installer verifies, cleans up safely, and links a versioned archive" {
  local version=3.0.0 fixture="$BATS_TEST_TMPDIR/fixture" mockbin="$BATS_TEST_TMPDIR/mockbin"
  local install_root="$BATS_TEST_TMPDIR/install" bindir="$BATS_TEST_TMPDIR/bin"
  mkdir -p "$fixture/code-$version/bin" "$mockbin"
  printf '%s\n' "$version" > "$fixture/code-$version/VERSION"
  mkdir -p "$install_root/2.9.0/bin" "$bindir"
  printf '2.9.0\n' > "$install_root/2.9.0/VERSION"
  ln -s "$install_root/2.9.0/bin/workspaces" "$bindir/ws"
  ln -s "$install_root/2.9.0/bin/workspaces" "$bindir/workspaces"
  cat > "$fixture/code-$version/bin/code" <<'SCRIPT'
#!/bin/sh
printf 'code fixture\n'
SCRIPT
  chmod +x "$fixture/code-$version/bin/code"
  tar -czf "$fixture/code-$version.tar.gz" -C "$fixture" "code-$version"
  (cd "$fixture" && shasum -a 256 "code-$version.tar.gz" > SHA256SUMS)
  cat > "$mockbin/curl" <<'SCRIPT'
#!/bin/sh
while [ $# -gt 0 ]; do
  case "$1" in -o) output=$2; shift 2;; *) url=$1; shift;; esac
done
case "$url" in
  *.tar.gz) cp "$CODE_FIXTURE/code-$CODE_VERSION.tar.gz" "$output";;
  */SHA256SUMS) cp "$CODE_FIXTURE/SHA256SUMS" "$output";;
  *) exit 1;;
esac
SCRIPT
  chmod +x "$mockbin/curl"

  run env PATH="$mockbin:$PATH" CODE_FIXTURE="$fixture" CODE_VERSION="$version" \
    CODE_INSTALL_ROOT="$install_root" CODE_BIN_DIR="$bindir" \
    "$BATS_TEST_DIRNAME/../scripts/install.sh"

  [ "$status" -eq 0 ]
  [ "$(readlink "$bindir/code")" = "$install_root/$version/bin/code" ]
  [ ! -e "$bindir/ws" ]
  [ ! -e "$bindir/workspaces" ]
  run "$bindir/code"
  [ "$output" = 'code fixture' ]

  local other="$BATS_TEST_TMPDIR/other-command"
  printf '#!/bin/sh\n' > "$other"
  ln -s "$other" "$bindir/ws"
  run env PATH="$mockbin:$PATH" CODE_FIXTURE="$fixture" CODE_VERSION="$version" \
    CODE_INSTALL_ROOT="$install_root" CODE_BIN_DIR="$bindir" \
    "$BATS_TEST_DIRNAME/../scripts/install.sh"

  [ "$status" -eq 0 ]
  [ "$(readlink "$bindir/ws")" = "$other" ]
  [ "$(readlink "$bindir/code")" = "$install_root/$version/bin/code" ]
}

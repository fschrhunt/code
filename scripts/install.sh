#!/bin/sh
# Install a checksum-verified Code release without a package manager.
set -eu

REPOSITORY="fschrhunt/code"
VERSION="${CODE_VERSION:-}"
INSTALL_ROOT="${CODE_INSTALL_ROOT:-$HOME/.local/share/code}"
BIN_DIR="${CODE_BIN_DIR:-$HOME/.local/bin}"
API="https://api.github.com/repos/$REPOSITORY/releases/latest"

fail() { printf '%s\n' "error: $*" >&2; exit 1; }
need() { command -v "$1" >/dev/null 2>&1 || fail "$1 is required"; }

need curl
need tar
need awk
need shasum

if [ -z "$VERSION" ]; then
  VERSION=$(curl -fsSL "$API" | sed -n 's/.*"tag_name": *"v\([^"]*\)".*/\1/p' | head -n 1)
fi
case "$VERSION" in
  [0-9]*.[0-9]*.[0-9]*) ;;
  *) fail "could not determine the latest Code release";;
esac

BASE="https://github.com/$REPOSITORY/releases/download/v$VERSION"
ARCHIVE="code-$VERSION.tar.gz"
TMP=$(mktemp -d "${TMPDIR:-/tmp}/code-install.XXXXXX") || fail "could not create temporary directory"
trap 'rm -rf "$TMP"' EXIT HUP INT TERM

printf 'Downloading Code %s...\n' "$VERSION"
curl -fsSL "$BASE/$ARCHIVE" -o "$TMP/$ARCHIVE"
curl -fsSL "$BASE/SHA256SUMS" -o "$TMP/SHA256SUMS"
EXPECTED=$(awk -v file="$ARCHIVE" '$2 == file { print $1; exit }' "$TMP/SHA256SUMS")
[ -n "$EXPECTED" ] || fail "release checksums do not list $ARCHIVE"
ACTUAL=$(shasum -a 256 "$TMP/$ARCHIVE" | awk '{print $1}')
[ "$ACTUAL" = "$EXPECTED" ] || fail "download checksum did not match"

tar -xzf "$TMP/$ARCHIVE" -C "$TMP"
SOURCE="$TMP/code-$VERSION"
[ -x "$SOURCE/bin/code" ] || fail "release archive has an unexpected layout"
DESTINATION="$INSTALL_ROOT/$VERSION"
TARGET="$BIN_DIR/code"
mkdir -p "$INSTALL_ROOT" "$BIN_DIR"
[ ! -e "$TARGET" ] || [ -L "$TARGET" ] || fail "refusing to replace existing path: $TARGET"
if [ -L "$TARGET" ]; then
  existing=$(readlink "$TARGET")
  case "$existing" in
    "$INSTALL_ROOT"/*/bin/code) ;;
    *) fail "refusing to replace existing symlink: $TARGET";;
  esac
fi

rm -rf "$DESTINATION"
mv "$SOURCE" "$DESTINATION"
rm -f "$TARGET"
ln -s "$DESTINATION/bin/code" "$TARGET"

printf 'Installed Code %s\n' "$VERSION"
case ":$PATH:" in
  *":$BIN_DIR:"*) ;;
  *) printf 'Add %s to your PATH.\n' "$BIN_DIR";;
esac
printf 'Run: code setup\n'

#!/bin/sh
# Install a verified Workframe release without a package manager.
set -eu

REPOSITORY="fschrhunt/workframe"
VERSION="${WORKFRAME_VERSION:-}"
INSTALL_ROOT="${WORKFRAME_INSTALL_ROOT:-$HOME/.local/share/workframe}"
BIN_DIR="${WORKFRAME_BIN_DIR:-$HOME/.local/bin}"
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
  *) fail "could not determine the latest Workframe release";;
esac

BASE="https://github.com/$REPOSITORY/releases/download/v$VERSION"
ARCHIVE="workframe-$VERSION.tar.gz"
SUMS="SHA256SUMS"
TMP=$(mktemp -d "${TMPDIR:-/tmp}/workframe-install.XXXXXX") || fail "could not create temporary directory"
trap 'rm -rf "$TMP"' EXIT HUP INT TERM

printf 'Downloading Workframe %s...\n' "$VERSION"
curl -fsSL "$BASE/$ARCHIVE" -o "$TMP/$ARCHIVE"
curl -fsSL "$BASE/$SUMS" -o "$TMP/$SUMS"

EXPECTED=$(awk -v file="$ARCHIVE" '$2 == file { print $1; exit }' "$TMP/$SUMS")
[ -n "$EXPECTED" ] || fail "release checksums do not list $ARCHIVE"
ACTUAL=$(shasum -a 256 "$TMP/$ARCHIVE" | awk '{print $1}')
[ "$ACTUAL" = "$EXPECTED" ] || fail "download checksum did not match"

tar -xzf "$TMP/$ARCHIVE" -C "$TMP"
SOURCE="$TMP/workframe-$VERSION"
[ -x "$SOURCE/bin/workframe" ] || fail "release archive has an unexpected layout"

DESTINATION="$INSTALL_ROOT/$VERSION"
mkdir -p "$INSTALL_ROOT" "$BIN_DIR"
rm -rf "$DESTINATION"
mv "$SOURCE" "$DESTINATION"

for command in workframe wf; do
  target="$BIN_DIR/$command"
  [ -d "$target" ] && [ ! -L "$target" ] && fail "refusing to replace directory: $target"
  ln -sfn "$DESTINATION/bin/workframe" "$target"
done

printf 'Installed Workframe %s\n' "$VERSION"
case ":$PATH:" in
  *":$BIN_DIR:"*) ;;
  *) printf 'Add %s to your PATH, then run: workframe setup\n' "$BIN_DIR";;
esac
printf 'Run: workframe setup\n'

#!/usr/bin/env bash
# Link a development checkout's Workspaces command onto PATH.
set -euo pipefail

PREFIX=$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)
BINDIR=${1:-$HOME/.local/bin}
DESTINATION="$BINDIR/workspaces"
LEGACY_ALIAS="$BINDIR/ws"
SOURCE="$PREFIX/bin/workspaces"

mkdir -p "$BINDIR"
previous_target=
if [ -e "$DESTINATION" ] && [ ! -L "$DESTINATION" ]; then
  printf 'error: refusing to replace existing path: %s\n' "$DESTINATION" >&2
  exit 1
fi
if [ -L "$DESTINATION" ]; then
  previous_target=$(readlink "$DESTINATION")
  case "$previous_target" in
    "$SOURCE"|*/bin/workspaces) ;;
    *) printf 'error: refusing to replace existing symlink: %s\n' "$DESTINATION" >&2; exit 1;;
  esac
fi
rm -f "$DESTINATION"
ln -s "$SOURCE" "$DESTINATION"
printf 'linked %s -> %s\n' "$DESTINATION" "$SOURCE"

# Remove an alias that shared the managed command target. An unrelated ws path
# belongs to its owner and must remain untouched.
if [ -L "$LEGACY_ALIAS" ]; then
  alias_target=$(readlink "$LEGACY_ALIAS")
  if [ "$alias_target" = "$SOURCE" ] || { [ -n "$previous_target" ] && [ "$alias_target" = "$previous_target" ]; }; then
    rm -f "$LEGACY_ALIAS"
    printf 'removed legacy alias %s\n' "$LEGACY_ALIAS"
  fi
fi
printf 'next: workspaces setup\n'
case ":$PATH:" in
  *":$BINDIR:"*) ;;
  *) printf 'note: %s is not on your PATH\n' "$BINDIR";;
esac

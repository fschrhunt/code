#!/usr/bin/env bash
# Link a development checkout's Workspaces command onto PATH.
set -euo pipefail

PREFIX=$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)
BINDIR=${1:-$HOME/.local/bin}
DESTINATION="$BINDIR/workspaces"
SOURCE="$PREFIX/bin/workspaces"

mkdir -p "$BINDIR"
if [ -e "$DESTINATION" ] && [ ! -L "$DESTINATION" ]; then
  printf 'error: refusing to replace existing path: %s\n' "$DESTINATION" >&2
  exit 1
fi
rm -f "$DESTINATION"
ln -s "$SOURCE" "$DESTINATION"
printf 'linked %s -> %s\n' "$DESTINATION" "$SOURCE"
printf 'next: workspaces help\n'
case ":$PATH:" in
  *":$BINDIR:"*) ;;
  *) printf 'note: %s is not on your PATH\n' "$BINDIR";;
esac

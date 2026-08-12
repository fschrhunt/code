#!/usr/bin/env bash
# Link a development checkout's Workspaces command onto PATH.
set -euo pipefail

PREFIX=$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)
BINDIR=${1:-$HOME/.local/bin}
DESTINATION="$BINDIR/workspaces"
ALIAS="$BINDIR/ws"
SOURCE="$PREFIX/bin/workspaces"

mkdir -p "$BINDIR"
for target in "$DESTINATION" "$ALIAS"; do
  if [ -e "$target" ] && [ ! -L "$target" ]; then
    printf 'error: refusing to replace existing path: %s\n' "$target" >&2
    exit 1
  fi
  if [ -L "$target" ]; then
    existing=$(readlink "$target")
    case "$existing" in
      "$SOURCE"|*/bin/workspaces) ;;
      *) printf 'error: refusing to replace existing symlink: %s\n' "$target" >&2; exit 1;;
    esac
  fi
done
for target in "$DESTINATION" "$ALIAS"; do
  rm -f "$target"
  ln -s "$SOURCE" "$target"
  printf 'linked %s -> %s\n' "$target" "$SOURCE"
done
printf 'next: ws setup\n'
case ":$PATH:" in
  *":$BINDIR:"*) ;;
  *) printf 'note: %s is not on your PATH\n' "$BINDIR";;
esac

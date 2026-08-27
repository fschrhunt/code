#!/usr/bin/env bash
# Link a development checkout's Code command onto PATH.
set -euo pipefail

PREFIX=$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)
BINDIR=${1:-$HOME/.local/bin}
DESTINATION="$BINDIR/code"
SOURCE="$PREFIX/bin/code"

mkdir -p "$BINDIR"
previous_target=
if [ -e "$DESTINATION" ] && [ ! -L "$DESTINATION" ]; then
  printf 'error: refusing to replace existing path: %s\n' "$DESTINATION" >&2
  exit 1
fi
if [ -L "$DESTINATION" ]; then
  previous_target=$(readlink "$DESTINATION")
  case "$previous_target" in
    "$SOURCE"|*/bin/code) ;;
    *) printf 'error: refusing to replace existing symlink: %s\n' "$DESTINATION" >&2; exit 1;;
  esac
fi

# Remove names from previous releases that this install no longer uses.
for legacy in "$BINDIR/workspaces" "$BINDIR/ws"; do
  if [ -L "$legacy" ]; then
    legacy_target=$(readlink "$legacy")
    case "$legacy_target" in
      "$SOURCE"|"$previous_target"|*/bin/code|*/bin/workspaces) rm -f "$legacy"; printf 'removed legacy command %s\n' "$legacy";;
    esac
  fi
done

rm -f "$DESTINATION"
ln -s "$SOURCE" "$DESTINATION"
printf 'linked %s -> %s\n' "$DESTINATION" "$SOURCE"
printf 'next: code setup\n'
case ":$PATH:" in
  *":$BINDIR:"*) ;;
  *) printf 'note: %s is not on your PATH\n' "$BINDIR";;
esac

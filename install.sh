#!/usr/bin/env bash
# install.sh — link workframe onto your PATH.
#
#   ./install.sh            # links into ~/.local/bin
#   ./install.sh /usr/local/bin
#
# Both names are linked: `workframe` is the canonical command and `wf` is the
# short form for everyday use. They are the same executable.
#
# This only symlinks the entry point; it never changes a Workframe store.
set -euo pipefail

PREFIX="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BINDIR="${1:-$HOME/.local/bin}"
NAMES="workframe wf"

mkdir -p "$BINDIR"

# Check every destination before linking any, so a refusal never leaves the
# install half-linked.
for name in $NAMES; do
  dest="$BINDIR/$name"
  if [ -d "$dest" ] && [ ! -L "$dest" ]; then
    echo "error: refusing to replace directory: $dest" >&2
    exit 1
  fi
done

for name in $NAMES; do
  ln -sfn "$PREFIX/bin/workframe" "$BINDIR/$name"
  echo "linked $BINDIR/$name -> $PREFIX/bin/workframe"
done
echo "docs:   $PREFIX/docs/   (start: docs/README.md)"
echo "next:   workframe help"

case ":$PATH:" in
  *":$BINDIR:"*) ;;
  *) echo "note: $BINDIR is not on your PATH — add it to use 'workframe' or 'wf' directly";;
esac

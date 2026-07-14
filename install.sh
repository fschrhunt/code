#!/usr/bin/env bash
# install.sh — link wt onto your PATH.
#
#   ./install.sh            # links into ~/.local/bin
#   ./install.sh /usr/local/bin
#
# This only symlinks the entry point; it never edits a deployed copy or touches
# a shared store. Deployment to the box is a separate, deliberate step.
set -euo pipefail

PREFIX="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BINDIR="${1:-$HOME/.local/bin}"

mkdir -p "$BINDIR"
ln -sf "$PREFIX/bin/wt" "$BINDIR/wt"
echo "linked $BINDIR/wt -> $PREFIX/bin/wt"
echo "docs:   $PREFIX/docs/   (start: docs/README.md)"

case ":$PATH:" in
  *":$BINDIR:"*) ;;
  *) echo "note: $BINDIR is not on your PATH — add it to use 'wt' directly";;
esac

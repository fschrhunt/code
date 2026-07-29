#!/usr/bin/env bash
# install.sh — link workframe onto your PATH.
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
ln -sf "$PREFIX/bin/workframe" "$BINDIR/workframe"
echo "linked $BINDIR/workframe -> $PREFIX/bin/workframe"
echo "docs:   $PREFIX/docs/   (start: docs/README.md)"
echo "next:   workframe setup"

case ":$PATH:" in
  *":$BINDIR:"*) ;;
  *) echo "note: $BINDIR is not on your PATH — add it to use 'workframe' directly";;
esac

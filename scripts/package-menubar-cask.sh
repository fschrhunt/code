#!/usr/bin/env bash
# Package the already-built Workframe app for a Homebrew cask release.
set -euo pipefail

prefix=$(cd -P "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
version=$(tr -d '[:space:]' < "$prefix/VERSION")
app="$prefix/.build/Workframe.app"
archive="${1:-$prefix/.build/Workframe-$version.zip}"

if [ ! -d "$app" ]; then
  "$prefix/scripts/build-menubar-app.sh"
fi

mkdir -p "$(dirname "$archive")"
rm -f "$archive"
ditto -c -k --keepParent "$app" "$archive"
shasum -a 256 "$archive"

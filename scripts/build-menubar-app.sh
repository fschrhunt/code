#!/usr/bin/env bash
# Build a distributable menubar app. The Workframe CLI remains a separate,
# installed dependency so the app and coding agents use the same backend.
set -euo pipefail

prefix=$(cd -P "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
output="$prefix/.build/Workframe.app"
binary="$prefix/.build/release/Workframe"

cd "$prefix"
swift build -c release

rm -rf "$output"
mkdir -p "$output/Contents/MacOS"
mkdir -p "$output/Contents/Resources"
ditto "$binary" "$output/Contents/MacOS/Workframe"
ditto "$prefix/app/Info.plist" "$output/Contents/Info.plist"
ditto "$prefix/app/Workframe.icon" "$output/Contents/Resources/Workframe.icon"
ditto "$prefix/app/Workframe.icns" "$output/Contents/Resources/Workframe.icns"
echo "built $output"

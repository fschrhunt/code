#!/usr/bin/env bash
# Build a distributable menubar app with the matching Workframe CLI embedded.
# The Homebrew cask exposes that embedded command as `workframe` and `wf`, so
# the app and terminal surface always use the same release.
set -euo pipefail

prefix=$(cd -P "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
output="$prefix/.build/Workframe.app"
binary="$prefix/.build/release/Workframe"
cli_root="$output/Contents/Resources/workframe"
version=$(tr -d '[:space:]' < "$prefix/VERSION")

cd "$prefix"
swift build -c release

rm -rf "$output"
mkdir -p "$output/Contents/MacOS"
mkdir -p "$output/Contents/Resources"
ditto "$binary" "$output/Contents/MacOS/Workframe"
ditto "$prefix/app/Info.plist" "$output/Contents/Info.plist"
ditto "$prefix/app/Workframe.icon" "$output/Contents/Resources/Workframe.icon"
ditto "$prefix/app/Workframe.icns" "$output/Contents/Resources/Workframe.icns"
mkdir -p "$cli_root"
ditto "$prefix/bin" "$cli_root/bin"
ditto "$prefix/lib" "$cli_root/lib"
ditto "$prefix/VERSION" "$cli_root/VERSION"
plutil -replace CFBundleShortVersionString -string "$version" "$output/Contents/Info.plist"
plutil -replace CFBundleVersion -string "$version" "$output/Contents/Info.plist"
echo "built $output"

#!/usr/bin/env bash
# Sign, notarize, staple, and package a Workframe cask release.
# Credentials stay in the release environment, never in this repository.
set -euo pipefail

prefix=$(cd -P "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
version=$(tr -d '[:space:]' < "$prefix/VERSION")
app="$prefix/.build/Workframe.app"
archive="$prefix/.build/Workframe-$version.zip"
: "${WORKFRAME_SIGNING_IDENTITY:?set a Developer ID Application signing identity}"
: "${WORKFRAME_NOTARY_PROFILE:?set a notarytool keychain profile}"

"$prefix/scripts/build-menubar-app.sh"
codesign --force --options runtime --sign "$WORKFRAME_SIGNING_IDENTITY" --timestamp "$app"
codesign --verify --strict --verbose=4 "$app"

"$prefix/scripts/package-menubar-cask.sh" "$archive" >/dev/null
xcrun notarytool submit "$archive" --keychain-profile "$WORKFRAME_NOTARY_PROFILE" --wait
xcrun stapler staple "$app"
xcrun stapler validate "$app"
spctl --assess --type execute --verbose "$app"

# Stapling changes the bundle, so produce the exact archive distributed by the cask.
"$prefix/scripts/package-menubar-cask.sh" "$archive"
echo "next: scripts/write-homebrew-cask.sh \"$(shasum -a 256 "$archive" | awk '{print $1}')\""

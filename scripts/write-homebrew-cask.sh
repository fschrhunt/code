#!/usr/bin/env bash
# Print the cask stanza for the signed and notarized release archive.
set -euo pipefail

prefix=$(cd -P "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
version=$(tr -d '[:space:]' < "$prefix/VERSION")
sha256=${1:-}
unsigned=${WORKFRAME_UNSIGNED:-0}

[ -n "$sha256" ] || {
  echo "usage: scripts/write-homebrew-cask.sh <release-archive-sha256>" >&2
  exit 1
}

cat <<EOF
cask "workframe" do
  version "$version"
  sha256 "$sha256"

  url "https://github.com/fschrhunt/workframe/releases/download/v#{version}/Workframe-#{version}.zip"
  name "Workframe"
  desc "Control plane for isolated coding-agent worktrees"
  homepage "https://github.com/fschrhunt/workframe"

  depends_on macos: :sonoma

  app "Workframe.app"
  command_wrapper "workframe",
                  executable: "#{appdir}/Workframe.app/Contents/Resources/workframe/bin/workframe",
                  env: { "WORKFRAME_DISTRIBUTION" => "homebrew-cask" }
  command_wrapper "wf",
                  executable: "#{appdir}/Workframe.app/Contents/Resources/workframe/bin/workframe",
                  env: { "WORKFRAME_DISTRIBUTION" => "homebrew-cask" }
EOF

if [ "$unsigned" = 1 ]; then
  cat <<'EOF'

  caveats <<~EOS
    This release is unsigned and not notarized. macOS will show a security warning
    before opening Workframe.app. Install only if you trust this project and release.
  EOS
EOF
fi

echo 'end'

#!/bin/sh
# Xcode Cloud clone hook.
#
# Runs immediately after the repo is cloned and BEFORE Xcode resolves the
# project graph. HFMac.xcodeproj is git-ignored (project.yml is the source of
# truth), so we generate it here with XcodeGen. Without this step Xcode Cloud
# would find no project and fail to resolve the "HFMac" scheme.
set -e

echo "▸ ci_post_clone: generating HFMac.xcodeproj from project.yml"

export HOMEBREW_NO_AUTO_UPDATE=1
export HOMEBREW_NO_INSTALL_CLEANUP=1

if ! command -v xcodegen >/dev/null 2>&1; then
  brew install xcodegen
fi

# Xcode Cloud sets CI_PRIMARY_REPOSITORY_PATH to the cloned repo root.
cd "${CI_PRIMARY_REPOSITORY_PATH:-$(cd "$(dirname "$0")/.." && pwd)}"

xcodegen generate --spec project.yml
echo "▸ ci_post_clone: generated"
ls -la HFMac.xcodeproj

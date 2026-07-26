#!/bin/sh
# Xcode Cloud pre-build hook.
#
# App Store Connect rejects an upload whose build number (CFBundleVersion) it has
# already seen. Xcode Cloud hands us a monotonic $CI_BUILD_NUMBER per run — stamp
# it into the Info.plist the build reads, so every TestFlight/App Store upload is
# unique without a manual bump. The marketing version (CFBundleShortVersionString)
# is left alone — that's driven by the git tag / project.yml.
set -e

if [ -n "$CI_BUILD_NUMBER" ]; then
  PLIST="${CI_PRIMARY_REPOSITORY_PATH:-$(cd "$(dirname "$0")/.." && pwd)}/Packaging/Info.plist"
  echo "▸ ci_pre_xcodebuild: CFBundleVersion → $CI_BUILD_NUMBER  ($PLIST)"
  /usr/libexec/PlistBuddy -c "Set :CFBundleVersion $CI_BUILD_NUMBER" "$PLIST"
fi

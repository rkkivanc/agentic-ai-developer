#!/usr/bin/env bash
# Reset Xcode SPM + DerivedData when you see:
#   "unable to initiate PIF transfer session"
#   "failed to find blueprint corresponding to PIF GUID: ... GoogleDataTransport"
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "=== AIKeyboard Xcode reset ==="
echo "Quit Xcode completely (⌘Q) before continuing."
read -r -p "Press Enter when Xcode is closed…"

echo "→ Stopping build services…"
killall -9 Xcode XCBBuildService SWBBuildService SourceKitService 2>/dev/null || true
pkill -9 -f "xcodebuild" 2>/dev/null || true
sleep 2

echo "→ Clearing DerivedData…"
rm -rf "$ROOT/.derivedData"
rm -rf "$HOME/Library/Developer/Xcode/DerivedData"/AIKeyboard-*

echo "→ Clearing SwiftPM state…"
rm -rf "$ROOT/AIKeyboard.xcodeproj/project.xcworkspace/xcshareddata/swiftpm"
rm -rf "$ROOT/AIKeyboard.xcodeproj/xcuserdata"
rm -rf "$ROOT/AIKeyboard.xcodeproj/project.xcworkspace/xcuserdata"
rm -rf "$HOME/Library/Caches/org.swift.swiftpm"
rm -rf "$HOME/Library/org.swift.swiftpm"

echo "→ Regenerating project (xcodegen)…"
xcodegen generate

echo "→ Resolving packages…"
xcodebuild -resolvePackageDependencies \
  -project "$ROOT/AIKeyboard.xcodeproj" \
  -scheme AIKeyboard \
  -derivedDataPath "$ROOT/.derivedData"

echo "→ Clean build…"
xcodebuild \
  -project "$ROOT/AIKeyboard.xcodeproj" \
  -scheme AIKeyboard \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -derivedDataPath "$ROOT/.derivedData" \
  clean build

echo ""
echo "✓ Success. Open AIKeyboard.xcodeproj and build (⌘B)."

#!/usr/bin/env bash
set -euo pipefail

SCHEME="PhoneKeyCore"
VERSION="${1:-1.0.0}"
ROOT=$(pwd)
OUT="$ROOT/build"
SPECS_DIR="/Users/joffreymann/Documents/projects/Specs"   # adjust if your Specs repo is elsewhere
SPEC_PODSPEC_PATH="$SPECS_DIR/PhoneKeyCore/${VERSION}/PhoneKeyCore.podspec"

echo "🚀 Option C Release Script (SSH-only private pod)"

# Clean output
rm -rf "$OUT"
mkdir -p "$OUT"

echo "📦 Building iOS archive..."
xcodebuild archive \
  -scheme "$SCHEME" \
  -configuration Release \
  -sdk iphoneos \
  SKIP_INSTALL=NO BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
  -archivePath "$OUT/${SCHEME}-iOS.xcarchive"

echo "📦 Building iOS Simulator archive..."
xcodebuild archive \
  -scheme "$SCHEME" \
  -configuration Release \
  -sdk iphonesimulator \
  SKIP_INSTALL=NO BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
  -archivePath "$OUT/${SCHEME}-Sim.xcarchive"

echo "🔧 Creating XCFramework..."
xcodebuild -create-xcframework \
  -framework "$OUT/${SCHEME}-iOS.xcarchive/Products/Library/Frameworks/${SCHEME}.framework" \
  -framework "$OUT/${SCHEME}-Sim.xcarchive/Products/Library/Frameworks/${SCHEME}.framework" \
  -output "$OUT/${SCHEME}.xcframework"

echo "📦 Zipping XCFramework..."
(cd "$OUT" && zip -r "${SCHEME}.xcframework.zip" "${SCHEME}.xcframework" >/dev/null)

ZIP_PATH="$OUT/${SCHEME}.xcframework.zip"

echo "📝 Creating Specs directory for version ${VERSION}..."


#!/usr/bin/env bash
set -euo pipefail

SCHEME="PhoneKeyCore"   # framework target name
OUT="build"

rm -rf "$OUT"
mkdir -p "$OUT"

# iOS
xcodebuild archive \
  -scheme "$SCHEME" \
  -configuration Release \
  -sdk iphoneos \
  SKIP_INSTALL=NO BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
  -archivePath "$OUT/${SCHEME}-iOS.xcarchive"

# iOS Simulator
xcodebuild archive \
  -scheme "$SCHEME" \
  -configuration Release \
  -sdk iphonesimulator \
  SKIP_INSTALL=NO BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
  -archivePath "$OUT/${SCHEME}-iOSSim.xcarchive"

# watchOS
xcodebuild archive \
  -scheme "$SCHEME" \
  -configuration Release \
  -sdk watchos \
  SKIP_INSTALL=NO BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
  -archivePath "$OUT/${SCHEME}-watchOS.xcarchive"

# watchOS Simulator
xcodebuild archive \
  -scheme "$SCHEME" \
  -configuration Release \
  -sdk watchsimulator \
  SKIP_INSTALL=NO BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
  -archivePath "$OUT/${SCHEME}-watchSim.xcarchive"

# Create XCFramework
xcodebuild -create-xcframework \
  -framework "$OUT/${SCHEME}-iOS.xcarchive/Products/Library/Frameworks/${SCHEME}.framework" \
  -framework "$OUT/${SCHEME}-iOSSim.xcarchive/Products/Library/Frameworks/${SCHEME}.framework" \
  -framework "$OUT/${SCHEME}-watchOS.xcarchive/Products/Library/Frameworks/${SCHEME}.framework" \
  -framework "$OUT/${SCHEME}-watchSim.xcarchive/Products/Library/Frameworks/${SCHEME}.framework" \
  -output "$OUT/${SCHEME}.xcframework"

# Zip
(cd "$OUT" && zip -r "${SCHEME}.xcframework.zip" "${SCHEME}.xcframework" >/dev/null)

echo "✅ Built XCFramework with watchOS support: $OUT/${SCHEME}.xcframework.zip"


#!/bin/bash
set -euo pipefail

SCHEME="PhoneKeyCore"
OUT="build"

rm -rf "$OUT"
mkdir -p "$OUT"

echo "📦 Building for iOS..."
xcodebuild archive \
  -scheme "$SCHEME" \
  -configuration Release \
  -sdk iphoneos \
  SKIP_INSTALL=NO \
  BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
  -archivePath "$OUT/${SCHEME}-iOS.xcarchive"

echo "📦 Building for iOS Simulator..."
xcodebuild archive \
  -scheme "$SCHEME" \
  -configuration Release \
  -sdk iphonesimulator \
  SKIP_INSTALL=NO \
  BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
  -archivePath "$OUT/${SCHEME}-Sim.xcarchive"

echo "🔧 Creating XCFramework..."
xcodebuild -create-xcframework \
  -framework "$OUT/${SCHEME}-iOS.xcarchive/Products/Library/Frameworks/${SCHEME}.framework" \
  -framework "$OUT/${SCHEME}-Sim.xcarchive/Products/Library/Frameworks/${SCHEME}.framework" \
  -output "$OUT/${SCHEME}.xcframework"

echo "🎉 Created at $OUT/${SCHEME}.xcframework"
``


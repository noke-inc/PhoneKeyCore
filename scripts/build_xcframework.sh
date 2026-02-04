
#!/bin/bash
set -euo pipefail

SCHEME="PhoneKeyCore"
OUT="build"

rm -rf "$OUT"
mkdir -p "$OUT"

###############################################
# 1. Build iOS (device)
###############################################
echo "📦 Building for iPhoneOS..."
xcodebuild archive \
  -scheme "$SCHEME" \
  -configuration Release \
  -sdk iphoneos \
  SKIP_INSTALL=NO \
  BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
  -archivePath "$OUT/${SCHEME}-iOS.xcarchive"

###############################################
# 2. Build iOS Simulator
###############################################
echo "📦 Building for iOS Simulator..."
xcodebuild archive \
  -scheme "$SCHEME" \
  -configuration Release \
  -sdk iphonesimulator \
  SKIP_INSTALL=NO \
  BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
  -archivePath "$OUT/${SCHEME}-iOSSim.xcarchive"

###############################################
# 3. Build watchOS (device)
###############################################
echo "⌚️ Building for watchOS..."
xcodebuild archive \
  -scheme "$SCHEME" \
  -configuration Release \
  -sdk watchos \
  SKIP_INSTALL=NO \
  BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
  -archivePath "$OUT/${SCHEME}-watchOS.xcarchive"

###############################################
# 4. Build watchOS Simulator
###############################################
echo "⌚️ Building for watchOS Simulator..."
xcodebuild archive \
  -scheme "$SCHEME" \
  -configuration Release \
  -sdk watchsimulator \
  SKIP_INSTALL=NO \
  BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
  -archivePath "$OUT/${SCHEME}-watchSim.xcarchive"

###############################################
# 5. Create XCFramework
###############################################
echo "🔧 Creating XCFramework..."

xcodebuild -create-xcframework \
  -framework "$OUT/${SCHEME}-iOS.xcarchive/Products/Library/Frameworks/${SCHEME}.framework" \
  -framework "$OUT/${SCHEME}-iOSSim.xcarchive/Products/Library/Frameworks/${SCHEME}.framework" \
  -framework "$OUT/${SCHEME}-watchOS.xcarchive/Products/Library/Frameworks/${SCHEME}.framework" \
  -framework "$OUT/${SCHEME}-watchSim.xcarchive/Products/Library/Frameworks/${SCHEME}.framework" \
  -output "$OUT/${SCHEME}.xcframework"

echo "🎉 XCFramework created at:"
echo "👉 $OUT/${SCHEME}.xcframework"

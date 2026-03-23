#!/usr/bin/env bash
set -euo pipefail

# ====================================================================
# PhoneKeyCore CocoaPods Release Script
# ====================================================================
# This script automates the release process for PhoneKeyCore:
# 1. Validates the podspec
# 2. Creates a git tag
# 3. Pushes to GitHub
# 4. Publishes to CocoaPods (optional)
# ====================================================================

PODSPEC="PhoneKeyCore.podspec"
SCHEME="PhoneKeyCore"

# Parse version from podspec
VERSION=$(grep -m1 "s.version" "$PODSPEC" | sed -E "s/.*'(.*)'.*/\1/")

echo "🚀 PhoneKeyCore Release Script"
echo "================================"
echo "Version: $VERSION"
echo ""

# ====================================================================
# Step 1: Validate podspec locally
# ====================================================================
echo "📋 Step 1: Validating podspec..."
if pod spec lint "$PODSPEC" --allow-warnings; then
    echo "✅ Podspec validation passed!"
else
    echo "❌ Podspec validation failed. Please fix the errors and try again."
    exit 1
fi

# ====================================================================
# Step 2: Check for uncommitted changes
# ====================================================================
echo ""
echo "📋 Step 2: Checking for uncommitted changes..."
if [[ -n $(git status --porcelain) ]]; then
    echo "⚠️  You have uncommitted changes:"
    git status --short
    read -p "Continue anyway? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "❌ Release cancelled."
        exit 1
    fi
fi

# ====================================================================
# Step 3: Create and push git tag
# ====================================================================
echo ""
echo "📋 Step 3: Creating git tag v$VERSION..."
if git tag -a "v$VERSION" -m "Release version $VERSION"; then
    echo "✅ Tag created successfully!"
else
    echo "⚠️  Tag v$VERSION may already exist."
    read -p "Continue with existing tag? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "❌ Release cancelled."
        exit 1
    fi
fi

echo ""
echo "📋 Step 4: Pushing tag to remote..."
if git push origin "v$VERSION"; then
    echo "✅ Tag pushed to GitHub!"
else
    echo "⚠️  Failed to push tag. It may already exist on remote."
fi

# Also push current branch
echo ""
echo "📋 Step 5: Pushing current branch..."
git push origin HEAD

# ====================================================================
# Step 6: Publish to CocoaPods (optional)
# ====================================================================
echo ""
echo "📋 Step 6: Publishing to CocoaPods..."
read -p "Publish to CocoaPods Trunk? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "Publishing to CocoaPods..."
    if pod trunk push "$PODSPEC" --allow-warnings; then
        echo "✅ Successfully published to CocoaPods!"
    else
        echo "❌ Failed to publish to CocoaPods."
        echo "You can manually publish later with: pod trunk push $PODSPEC --allow-warnings"
        exit 1
    fi
else
    echo "⏭️  Skipping CocoaPods publishing."
    echo "To publish manually later, run:"
    echo "  pod trunk push $PODSPEC --allow-warnings"
fi

echo ""
echo "🎉 Release process complete!"
echo "================================"
echo "Version $VERSION is now available."
echo ""
echo "For private pod deployment, you can also:"
echo "  1. Push to your private Specs repo:"
echo "     pod repo push noke-specs $PODSPEC --allow-warnings"
echo ""
echo "  2. Or reference directly from GitHub in your Podfile:"
echo "     pod 'PhoneKeyCore', :git => 'https://github.com/noke-inc/PhoneKeyCore.git', :tag => 'v$VERSION'"
echo ""

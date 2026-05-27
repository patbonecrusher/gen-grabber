#!/bin/bash
set -e

cd "$(dirname "$0")"

# Regenerate Xcode project
xcodegen generate

# Build
xcodebuild -project GenGrabber.xcodeproj -scheme GenGrabber -configuration Debug build -quiet

# Copy app to project folder
APP=$(find ~/Library/Developer/Xcode/DerivedData/GenGrabber-* -name "GenGrabber.app" -path "*/Debug/*" | head -1)
rm -rf GenGrabber.app
cp -R "$APP" GenGrabber.app

echo "Built: $(pwd)/GenGrabber.app"
echo "Run:   open GenGrabber.app"

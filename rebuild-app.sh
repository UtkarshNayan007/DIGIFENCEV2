#!/bin/bash

# Quick rebuild script for DigiFence app

echo "🧹 Cleaning build folder..."
xcodebuild clean -project DIGIFENCEV1.xcodeproj -scheme DIGIFENCEV1

echo ""
echo "🔨 Building app..."
xcodebuild build -project DIGIFENCEV1.xcodeproj -scheme DIGIFENCEV1

echo ""
echo "✅ Build complete!"
echo ""
echo "Now run the app in Xcode (⌘+R) and try creating an event."

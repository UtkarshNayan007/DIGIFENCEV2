#!/bin/bash
# Verify App Check is disabled in the code

echo "🔍 Verifying App Check is disabled..."
echo ""

if grep -q "// import FirebaseAppCheck" DIGIFENCEV1/DIGIFENCEV1App.swift; then
    echo "✅ App Check import is commented out"
else
    echo "❌ App Check import is NOT commented out"
    echo "   Please check DIGIFENCEV1/DIGIFENCEV1App.swift"
fi

if grep -q "APP CHECK IS COMPLETELY DISABLED" DIGIFENCEV1/DIGIFENCEV1App.swift; then
    echo "✅ Disabled message is present"
else
    echo "❌ Disabled message is NOT present"
fi

echo ""
echo "Next steps:"
echo "1. Clean build: ⌘+Shift+Option+K in Xcode"
echo "2. Delete app from device/simulator"
echo "3. Rebuild: ⌘+R"

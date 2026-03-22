#!/bin/bash
# Deploy Firestore rules to digifence-c5243
# Run this from the project root: bash deploy-rules.sh

NODE=".node_setup/node_v20/bin/node"
FIREBASE=".node_setup/node_v20/lib/node_modules/firebase-tools/lib/bin/firebase.js"
PROJECT="digifence-c5243"

echo "=== Step 1: Firebase Login ==="
$NODE $FIREBASE login --project $PROJECT

echo ""
echo "=== Step 2: Deploying Firestore Rules ==="
$NODE $FIREBASE deploy --only firestore:rules --project $PROJECT

echo ""
echo "=== Done ==="
echo "Firestore rules deployed. Now only the event organizer can verify check-ins."

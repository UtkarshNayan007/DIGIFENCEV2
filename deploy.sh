#!/bin/zsh

# DigiFence Deployment Script
# Uses the portable Node.js 20 downloaded to /tmp/node_setup during automation.

export PATH="/tmp/node_setup/node_v20/bin:$PATH"

echo "Using Node: $(node -v)"
echo "Using npm: $(npm -v)"

echo "\n--- Installing Firebase CLI ---"
npm install -g firebase-tools

echo "\n--- Logging into Firebase ---"
# You may need to run this script interactively if not logged in
npx firebase-tools login --reauth

echo "\n--- Deploying to Firebase ---"
npx firebase-tools deploy --only functions,firestore:rules,firestore:indexes --project digifence-c5243

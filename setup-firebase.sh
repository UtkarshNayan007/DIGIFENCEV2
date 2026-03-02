#!/bin/bash

# DigiFence Firebase Setup Script
# This script will install necessary tools and configure Firebase

set -e  # Exit on error

echo "🚀 DigiFence Firebase Setup"
echo "================================"
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if Homebrew is installed
echo "📦 Checking for Homebrew..."
if ! command -v brew &> /dev/null; then
    echo -e "${YELLOW}Homebrew not found. Installing Homebrew...${NC}"
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    
    # Add Homebrew to PATH for Apple Silicon Macs
    if [[ $(uname -m) == 'arm64' ]]; then
        echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
        eval "$(/opt/homebrew/bin/brew shellenv)"
    fi
else
    echo -e "${GREEN}✓ Homebrew is installed${NC}"
fi

# Check if Node.js is installed
echo ""
echo "📦 Checking for Node.js..."
if ! command -v node &> /dev/null; then
    echo -e "${YELLOW}Node.js not found. Installing Node.js...${NC}"
    brew install node
else
    echo -e "${GREEN}✓ Node.js is installed ($(node --version))${NC}"
fi

# Check if npm is available
echo ""
echo "📦 Checking for npm..."
if ! command -v npm &> /dev/null; then
    echo -e "${RED}✗ npm not found. Please install Node.js manually.${NC}"
    exit 1
else
    echo -e "${GREEN}✓ npm is installed ($(npm --version))${NC}"
fi

# Install Firebase CLI globally
echo ""
echo "📦 Installing Firebase CLI..."
if ! command -v firebase &> /dev/null; then
    echo -e "${YELLOW}Installing Firebase CLI globally...${NC}"
    npm install -g firebase-tools
else
    echo -e "${GREEN}✓ Firebase CLI is installed ($(firebase --version))${NC}"
fi

# Login to Firebase
echo ""
echo "🔐 Firebase Login"
echo "================================"
echo "You need to login to Firebase to deploy rules."
echo "A browser window will open for authentication."
echo ""
read -p "Press Enter to continue..."

firebase login

# Check if login was successful
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Successfully logged in to Firebase${NC}"
else
    echo -e "${RED}✗ Firebase login failed${NC}"
    exit 1
fi

# List Firebase projects
echo ""
echo "📋 Your Firebase Projects:"
firebase projects:list

# Set the Firebase project
echo ""
echo "🎯 Setting Firebase project to digifence-c5243..."
firebase use digifence-c5243

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Project set successfully${NC}"
else
    echo -e "${RED}✗ Failed to set project. Make sure 'digifence-c5243' exists.${NC}"
    exit 1
fi

# Deploy Firestore rules
echo ""
echo "📤 Deploying Firestore rules..."
firebase deploy --only firestore:rules

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Firestore rules deployed successfully${NC}"
else
    echo -e "${RED}✗ Failed to deploy Firestore rules${NC}"
    exit 1
fi

# Install Cloud Functions dependencies
echo ""
echo "📦 Installing Cloud Functions dependencies..."
cd functions
npm install
cd ..

echo ""
echo "================================"
echo -e "${GREEN}✅ Setup Complete!${NC}"
echo "================================"
echo ""
echo "Next steps:"
echo "1. Register App Check debug tokens in Firebase Console:"
echo "   - Go to: https://console.firebase.google.com/"
echo "   - Select: digifence-c5243"
echo "   - Navigate to: Build → App Check"
echo "   - Add these tokens:"
echo "     • ED2F8B6E-4131-4F20-9D4E-1DA7486FE0DB"
echo "     • 90C31477-ABBE-4599-90B0-6481848C3B98"
echo ""
echo "2. Deploy Cloud Functions (optional):"
echo "   firebase deploy --only functions"
echo ""
echo "3. Restart your iOS app and try creating an event"
echo ""

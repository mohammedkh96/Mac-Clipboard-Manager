#!/bin/bash

# Mac Clipboard Manager - GitHub Release Script
# This script creates a GitHub release using the GitHub CLI

set -e  # Exit on error

echo "🚀 Creating GitHub Release for Mac Clipboard Manager v7.0.0..."

# Check if gh is installed
if ! command -v gh &> /dev/null; then
    echo "❌ GitHub CLI not found. Installing..."
    brew install gh
fi

# Check if authenticated
if ! gh auth status &> /dev/null; then
    echo "🔐 Please authenticate with GitHub..."
    gh auth login
fi

# Create the release
echo "📦 Creating release v7.0.0..."
gh release create v7.0.0 \
    --title "Mac Clipboard Manager v7.0.0" \
    --notes-file RELEASE_NOTES.md \
    MacClipboardManager-v7.0.0.dmg

echo "✅ Release created successfully!"
echo "🔗 View it at: https://github.com/mohammedkh96/Mac-Clipboard-Manager/releases/tag/v7.0.0"

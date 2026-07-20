#!/bin/bash

# DartCam Beta Release Script
# Builds APK and replaces the GitHub release (same URL every time)

set -e

TAG="v0.2.0-beta"
APK_NAME="DartCam-${TAG}.apk"
BUILD_DIR="build/app/outputs/flutter-apk"

echo "Building APK..."
ENV_FILE=""
if [ -f ".env" ]; then
  ENV_FILE="--dart-define-from-file=.env"
  echo "  Loading cloud config from .env"
fi
flutter build apk --debug $ENV_FILE

echo "Renaming APK..."
cp "${BUILD_DIR}/app-debug.apk" "${BUILD_DIR}/${APK_NAME}"

echo "Replacing GitHub release..."
gh release delete "$TAG" --yes 2>/dev/null || true
gh release create "$TAG" "${BUILD_DIR}/${APK_NAME}" \
  --title "$TAG" \
  --notes "Latest beta — camera detection + manual scoring."

echo "Done! Release: https://github.com/sayanmohsin/dartcam/releases/tag/${TAG}"

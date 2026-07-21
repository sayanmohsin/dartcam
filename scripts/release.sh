#!/bin/bash

# DartCam Beta Release Script
# Builds release AAB + split APKs and replaces the GitHub release (same URL every time)

set -e

TAG="v0.2.0-beta"
APK_NAME="DartCam-${TAG}.apk"
BUILD_DIR="build/app/outputs"

echo "Building release artifacts..."
ENV_FILE=""
if [ -f ".env" ]; then
  ENV_FILE="--dart-define-from-file=.env"
  echo "  Loading cloud config from .env"
fi

flutter build appbundle --release $ENV_FILE
echo "  ✓ AAB: ${BUILD_DIR}/bundle/release/app-release.aab"

flutter build apk --release --split-per-abi $ENV_FILE
echo "  ✓ APK (arm64-v8a): ${BUILD_DIR}/flutter-apk/app-arm64-v8a-release.apk"

echo "Renaming APK..."
cp "${BUILD_DIR}/flutter-apk/app-arm64-v8a-release.apk" "${BUILD_DIR}/flutter-apk/${APK_NAME}"

echo "Replacing GitHub release..."
gh release delete "$TAG" --yes 2>/dev/null || true
gh release create "$TAG" \
  "${BUILD_DIR}/flutter-apk/${APK_NAME}" \
  --title "$TAG" \
  --notes "Latest beta — camera detection + manual scoring."

echo "Done! Release: https://github.com/sayanmohsin/dartcam/releases/tag/${TAG}"

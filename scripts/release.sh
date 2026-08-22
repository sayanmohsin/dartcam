#!/bin/bash

# DartCam Release Script
# Builds release AAB + split APKs and publishes a versioned GitHub release.

set -e

VERSION="$(awk '/^version:/{print $2; exit}' pubspec.yaml)"
APP_VERSION="${VERSION%%+*}"
TAG="v${APP_VERSION}"
APK_NAME="DartCam-${TAG}.apk"
BUILD_DIR="build/app/outputs"

echo "Building release artifacts..."
ENV_FILE=""
if [ "${DARTCAM_INCLUDE_CLOUD_CONFIG:-false}" = "true" ] && [ -f ".env" ]; then
  ENV_FILE="--dart-define-from-file=.env"
  echo "  Loading cloud config from .env"
else
  echo "  Building without cloud config"
fi

flutter build appbundle --release $ENV_FILE
echo "  ✓ AAB: ${BUILD_DIR}/bundle/release/app-release.aab"

flutter build apk --release --split-per-abi $ENV_FILE
echo "  ✓ APK (arm64-v8a): ${BUILD_DIR}/flutter-apk/app-arm64-v8a-release.apk"

echo "Renaming APK..."
cp "${BUILD_DIR}/flutter-apk/app-arm64-v8a-release.apk" "${BUILD_DIR}/flutter-apk/${APK_NAME}"

echo "Creating GitHub release..."
gh release create "$TAG" \
  "${BUILD_DIR}/bundle/release/app-release.aab" \
  "${BUILD_DIR}/flutter-apk/${APK_NAME}" \
  --title "$TAG" \
  --notes "DartCam ${APP_VERSION} — camera detection + manual scoring."

echo "Done! Release: https://github.com/sayanmohsin/dartcam/releases/tag/${TAG}"

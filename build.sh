#!/usr/bin/env bash
set -euo pipefail

APP_NAME="HelloWorldApp"
BUILD_DIR="${PWD}/build"
APP_BUNDLE="${BUILD_DIR}/${APP_NAME}.app"

rm -rf "${BUILD_DIR}"
mkdir -p "${APP_BUNDLE}/Contents/MacOS"
cp Resources/Info.plist "${APP_BUNDLE}/Contents/Info.plist"

swiftc Sources/App/main.swift \
  -parse-as-library \
  -framework Cocoa \
  -o "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"

echo "Created bundle at ${APP_BUNDLE}"
echo "Launch with: open \"${APP_BUNDLE}\""

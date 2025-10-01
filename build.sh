#!/usr/bin/env bash
set -euo pipefail

APP_NAME="HelloWorldApp"
BUILD_DIR="${PWD}/build"
APP_BUNDLE="${BUILD_DIR}/${APP_NAME}.app"

rm -rf "${BUILD_DIR}"
mkdir -p "${APP_BUNDLE}/Contents/MacOS"
mkdir -p "${APP_BUNDLE}/Contents/Resources"
cp Resources/Info.plist "${APP_BUNDLE}/Contents/Info.plist"

if compgen -G "Scripts/*.sh" > /dev/null; then
  rsync -a Scripts/ "${APP_BUNDLE}/Contents/Resources/Scripts/"
  chmod +x "${APP_BUNDLE}/Contents/Resources/Scripts/"*.sh
fi

swiftc Sources/App/main.swift \
  -parse-as-library \
  -framework Cocoa \
  -o "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"

echo "Created bundle at ${APP_BUNDLE}"
echo "Launch with: open \"${APP_BUNDLE}\""

#!/usr/bin/env bash
# Copyright The k3sm Authors.
# SPDX-License-Identifier: Apache-2.0
#
# build-app.sh <outdir> -- build "k3sm.app" for arm64 and ad-hoc sign it.
#
# Builds the release executable with SwiftPM, assembles the bundle from
# Resources/Info.plist, signs it inside out (nested code first, the bundle root
# last, never --deep), verifies the signature, and prints the Swift toolchain
# version so the build log records what produced the bundle.
set -euo pipefail

if [ "$#" -ne 1 ] || [ -z "$1" ]; then
	echo "usage: hack/build-app.sh <outdir>" >&2
	exit 2
fi

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
mkdir -p "$1"
OUT="$(cd "$1" && pwd)"
APP="$OUT/k3sm.app"
PRODUCT=K3smApp   # the SwiftPM executable product
EXE=k3sm-app      # the bundle executable (CFBundleExecutable in Resources/Info.plist)

echo "==> toolchain"
swift --version 2>&1 | sed 's/^/    /'

echo "==> swift build -c release --arch arm64"
( cd "$ROOT" && swift build -c release --arch arm64 --product "$PRODUCT" )
BIN_DIR="$(cd "$ROOT" && swift build -c release --arch arm64 --show-bin-path)"
[ -x "$BIN_DIR/$PRODUCT" ] || { echo "build-app: $BIN_DIR/$PRODUCT not found" >&2; exit 1; }

echo "==> assemble $APP"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$ROOT/Resources/Info.plist" "$APP/Contents/Info.plist"
cp "$BIN_DIR/$PRODUCT" "$APP/Contents/MacOS/$EXE"
chmod 0755 "$APP/Contents/MacOS/$EXE"
plutil -lint "$APP/Contents/Info.plist" >/dev/null
[ "$(plutil -extract CFBundleExecutable raw "$APP/Contents/Info.plist")" = "$EXE" ] \
	|| { echo "build-app: Info.plist CFBundleExecutable is not $EXE" >&2; exit 1; }

echo "==> ad-hoc sign (inside out)"
# Nested code first. The bundle holds one executable today; any helper or
# framework added under Contents/ must be signed here before the root.
codesign --force --sign - --timestamp=none "$APP/Contents/MacOS/$EXE"
codesign --force --sign - --timestamp=none "$APP"

echo "==> verify"
codesign --verify --strict --verbose=2 "$APP"
lipo -archs "$APP/Contents/MacOS/$EXE" | grep -qx arm64 \
	|| { echo "build-app: executable is not arm64-only" >&2; exit 1; }
echo "build-app: $APP"

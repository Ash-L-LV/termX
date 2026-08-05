#!/bin/bash
# Builds dist/TermX.app (ad-hoc signed) from the SwiftPM sources.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "==> Building release binary…"
swift build -c release

BUNDLE="$ROOT/dist/TermX.app"
mkdir -p "$BUNDLE/Contents/MacOS" "$BUNDLE/Contents/Resources"

echo "==> Assembling $BUNDLE"
cp .build/release/TermX "$BUNDLE/Contents/MacOS/TermX"
cp Resources/Info.plist "$BUNDLE/Contents/Info.plist"
cp Resources/AppIcon.icns "$BUNDLE/Contents/Resources/AppIcon.icns"

# SwiftTerm's Metal renderer loads its shader source from this bundle at
# runtime; without it Metal silently falls back to the slower Core Graphics
# path.
if [ -d ".build/arm64-apple-macosx/release/SwiftTerm_SwiftTerm.bundle" ]; then
    ditto ".build/arm64-apple-macosx/release/SwiftTerm_SwiftTerm.bundle" \
          "$BUNDLE/Contents/Resources/SwiftTerm_SwiftTerm.bundle"
    echo "==> Bundled SwiftTerm shader resources"
else
    echo "==> WARNING: SwiftTerm shader bundle not found; Metal will be unavailable"
fi

echo "==> Ad-hoc signing…"
codesign --force --sign - "$BUNDLE"

echo "==> Done: $BUNDLE"

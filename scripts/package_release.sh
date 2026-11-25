#!/bin/zsh
# Builds a universal "Zinkx Arena.app" and packages it for a GitHub release.
# Output: dist/ZinkxArena-<version>-macOS-universal.zip (+ .sha256)
set -e
cd "${0:A:h}/.."

VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" Resources/Info.plist)
UNIVERSAL=1 ./build.sh

mkdir -p dist
ZIP="dist/ZinkxArena-${VERSION}-macOS-universal.zip"
rm -f "$ZIP" "$ZIP.sha256"
ditto -c -k --sequesterRsrc --keepParent "build/Zinkx Arena.app" "$ZIP"
(cd dist && shasum -a 256 "$(basename "$ZIP")" > "$(basename "$ZIP").sha256")

lipo -info "build/Zinkx Arena.app/Contents/MacOS/PlayHub"
echo "Packaged $ZIP"

#!/bin/zsh
# Builds "Zinkx Arena.app" into ./build
#   ./build.sh               → native build for this Mac
#   UNIVERSAL=1 ./build.sh   → universal binary (Apple Silicon + Intel), used for releases
set -e
cd "${0:A:h}"

rm -rf /tmp/playhub-src
mkdir -p .build/release /tmp/clang-module-cache /tmp/playhub-src
cp Sources/PlayHub/*.swift /tmp/playhub-src/
SWIFTC_FLAGS=(-module-cache-path /tmp/clang-module-cache -parse-as-library -swift-version 5 -O)
if [ "${UNIVERSAL:-0}" = "1" ]; then
  for arch in arm64 x86_64; do
    swiftc "${SWIFTC_FLAGS[@]}" -target "$arch-apple-macos15.0" /tmp/playhub-src/*.swift -o ".build/release/PlayHub-$arch"
  done
  lipo -create -output .build/release/PlayHub .build/release/PlayHub-arm64 .build/release/PlayHub-x86_64
else
  swiftc "${SWIFTC_FLAGS[@]}" /tmp/playhub-src/*.swift -o .build/release/PlayHub
fi

APP="build/Zinkx Arena.app"
rm -rf "$APP" build/PlayHub.app
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/PlayHub "$APP/Contents/MacOS/PlayHub"
cp Resources/Info.plist "$APP/Contents/Info.plist"

if [ ! -f build/AppIcon.icns ] || [ Sources/PlayHub/Logo.swift -nt build/AppIcon.icns ] || [ scripts/make_icon/main.swift -nt build/AppIcon.icns ]; then
  rm -rf build/AppIcon.iconset
  swiftc -swift-version 5 -O scripts/make_icon/main.swift Sources/PlayHub/Logo.swift -o build/make_icon
  build/make_icon build/AppIcon.iconset
  iconutil -c icns build/AppIcon.iconset -o build/AppIcon.icns
fi
cp build/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

codesign --force --deep -i com.zinkx.playhub -s - "$APP"
echo "Built $APP"

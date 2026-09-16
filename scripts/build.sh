#!/bin/bash
set -euo pipefail
root=$(cd "$(dirname "$0")/.." && pwd)
video_dir=${1:?Usage: ./scripts/build.sh /absolute/path/to/videos}
video_dir=$(cd "$video_dir" && pwd)
staging=$(mktemp -d /tmp/snoopy-build.XXXXXX)
trap 'rm -rf "$staging"' EXIT
mkdir -p "$root/build"
build_saver() {
    local variant=$1 title=$2 executable=$3 video=$4
    local bundle="$staging/$title.saver"
    mkdir -p "$bundle/Contents/MacOS" "$bundle/Contents/Resources"
    cp "$root/Resources/$variant/Info.plist" "$bundle/Contents/Info.plist"
    cp "$root/Resources/$variant/"*.png "$bundle/Contents/Resources/"
    cp -X "$video_dir/$video.mp4" "$bundle/Contents/Resources/$video.mp4"
    for arch in arm64 x86_64; do
        xcrun swiftc -swift-version 5 -emit-library -module-name "$executable" \
          -target "$arch-apple-macos13.0" \
          -framework AppKit -framework AVFoundation -framework ScreenSaver \
          "$root/Sources/$variant.swift" -o "$staging/$variant-$arch"
    done
    xcrun lipo -create "$staging/$variant-arm64" "$staging/$variant-x86_64" \
      -output "$bundle/Contents/MacOS/$executable"
    xattr -cr "$bundle"
    codesign --force --sign - "$bundle"
    codesign --verify --strict "$bundle"
    ditto --noextattr --norsrc "$bundle" "$root/build/$title.saver"
    ditto -c -k --keepParent --norsrc "$bundle" "$root/build/$title.zip"
}
build_saver MorningRoutine 'Snoopy Morning Routine' SnoopyMorningRoutine 'Morning Routine'
build_saver Space 'Snoopy Space' SnoopySpace 'Snoopy Space'
printf 'Built both screen savers in %s/build\n' "$root"

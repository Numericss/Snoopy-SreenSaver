#!/bin/bash
# Credentials stay in the user's Keychain; never put passwords in this script.
set -euo pipefail
root=$(cd "$(dirname "$0")/.." && pwd)
identity=${1:?Usage: ./scripts/notarize.sh 'Developer ID Application: Name (TEAMID)' keychain-profile [build-directory]}
profile=${2:?Supply the notarytool Keychain profile name}
build_dir=${3:-"$root/build"}
case "$identity" in
  'Developer ID Application: '*) ;;
  *) printf 'Use a Developer ID Application identity, not an ad-hoc or development signature.\n' >&2; exit 1 ;;
esac
security find-identity -v -p codesigning | grep -F -- "\"$identity\"" >/dev/null || {
    printf 'The requested valid signing identity and private key are not available in Keychain.\n' >&2
    exit 1
}
# Validate authentication before altering or uploading any package.
xcrun notarytool history --keychain-profile "$profile" --output-format json >/dev/null
for title in 'Snoopy Morning Routine' 'Snoopy Space'; do
    test -f "$build_dir/$title.saver/Contents/Info.plist" || {
        printf 'Missing bundle: %s/%s.saver. Run build.sh first.\n' "$build_dir" "$title" >&2; exit 1
    }
done
out="$root/build/notarized/$(date -u +%Y%m%dT%H%M%SZ)"
mkdir -p "$out"
staging=$(mktemp -d /tmp/snoopy-notarize.XXXXXX)
trap 'rm -rf "$staging"' EXIT
package_saver() {
    local title=$1 slug=$2
    local folder="$staging/$slug"
    local bundle="$folder/$title.saver"
    local dmg="$out/$slug.dmg"
    mkdir -p "$folder"
    ditto --noextattr --norsrc "$build_dir/$title.saver" "$bundle"
    cat > "$folder/START HERE.txt" <<GUIDE
$title — MAC SCREEN SAVER

Double-click $title.saver and install for your current user.
Then open System Settings > Wallpaper > Screen Saver (macOS Tahoe),
or System Settings > Screen Saver on earlier macOS versions.
Under Other > Show All, choose $title and set an automatic start delay.

The video is included, silent, and loops to fill your display.
5K resolution is upscaled from 1080p. Edges may be cropped to fill.
Requires macOS 13 or later. Apple silicon and Intel binaries included;
playback was tested on Apple silicon with macOS 26.7.

This package uses Developer ID signing. For the verification record,
see the GitHub release notes accompanying this disk image.
Not an official Apple or Peanuts product. Video and character rights
remain with their respective owners.

To uninstall, move ~/Library/Screen Savers/$title.saver to Trash.
GUIDE
    # The bundled code is unchanged; distribution adds a verified identity,
    # a secure timestamp, and the hardened runtime signature flag.
    codesign --force --options runtime --timestamp --sign "$identity" "$bundle"
    codesign --verify --strict --verbose=2 "$bundle"
    hdiutil create -volname "$title" -srcfolder "$folder" -format UDZO "$dmg"
    codesign --sign "$identity" --timestamp "$dmg"
    codesign --verify --strict "$dmg"
    # Preserve submission metadata, including the ID, for diagnosis/resumption.
    xcrun notarytool submit "$dmg" --keychain-profile "$profile" --wait \
        --output-format json > "$out/$slug-submission.json"
    local status submission_id
    status=$(plutil -extract status raw "$out/$slug-submission.json")
    submission_id=$(plutil -extract id raw "$out/$slug-submission.json")
    if [ "$status" != Accepted ]; then
        xcrun notarytool log "$submission_id" --keychain-profile "$profile" "$out/$slug-log.json" || true
        printf 'Notarization status: %s. Inspect %s; do not publish this package.\n' "$status" "$out" >&2
        exit 1
    fi
    xcrun stapler staple "$dmg"
    xcrun stapler validate "$dmg"
    spctl --assess --type open --context context:primary-signature --verbose=2 "$dmg"
    shasum -a 256 "$dmg" > "$out/$slug.sha256"
}
package_saver 'Snoopy Morning Routine' Snoopy-Morning-Routine
package_saver 'Snoopy Space' Snoopy-Space
printf 'Both packages accepted and verified: %s\n' "$out"
printf 'Publish only the verified DMGs; the existing ZIPs remain ad-hoc signed.\n'

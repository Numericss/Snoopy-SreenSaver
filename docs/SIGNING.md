# Developer ID signing and notarization

The v1.0.0 ZIPs are ad-hoc signed and are not notarized. This workflow prepares a future verified release; adding the script does not change the status of existing downloads.

## One-time setup on your Mac

1. In Xcode > Settings > Accounts, sign in to the Apple Developer Program account.
2. Select the developer team and open Manage Certificates. Create a **Developer ID Application** certificate if you are authorized to do so. If your team already has one on another Mac, import its certificate **and private key** from a securely transferred `.p12` instead. A `.cer` alone is insufficient without the matching private key.
3. Confirm availability with `security find-identity -v -p codesigning`.
4. Store notarization credentials interactively in Keychain:

   ```sh
   xcrun notarytool store-credentials SnoopyNotary
   ```

   Follow Apple's prompts for your Apple Account, Team ID, and an app-specific password, or configure an App Store Connect API key using notarytool's documented options. Enter secrets locally. Do not paste passwords or private keys into chat, commit them, or place them in release notes.

## Prepare and notarize

Build the bundles as described in the README, then run:

```sh
./scripts/notarize.sh 'Developer ID Application: Your Name (TEAMID)' SnoopyNotary
```

The script signs each saver with the Developer ID Application identity, a secure timestamp, and the hardened runtime flag. It puts each saver in its own signed DMG, submits each DMG to Apple's notary service, requires an **Accepted** result, attaches the ticket, and verifies the result with `stapler` and Gatekeeper. Submission results are saved alongside the files for diagnosis.

A DMG carries the stapled ticket for offline verification. Do not replace a signed DMG's contents after notarization. Publish the verified DMGs from the timestamped `build/notarized/` directory as a new GitHub release. Do not describe old ZIPs as notarized.

If a submission remains in progress, use the ID in its submission output with `xcrun notarytool info`, `wait`, or `log` and the same Keychain profile before submitting another copy.

## Release verification

- Confirm Developer ID authority and secure timestamp on both embedded bundles.
- Require Accepted notarization status for each DMG.
- Require successful `stapler validate` and Gatekeeper assessment on each DMG.
- Test installation and screen saver playback from the downloaded release, ideally on a separate Mac.
- Update user installation instructions to open the DMG, then double-click its `.saver`.

References: [Developer ID](https://developer.apple.com/developer-id/), [notarization workflow](https://developer.apple.com/documentation/security/customizing-the-notarization-workflow), [distribution packaging](https://developer.apple.com/documentation/xcode/packaging-mac-software-for-distribution).

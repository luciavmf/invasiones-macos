# Continuous integration

`.github/workflows/macos-build.yml` builds, signs, and notarizes the app on every push to `main`, then publishes the DMG to the rolling [`latest-macos-build`](https://github.com/luciavmf/invasiones-macos/releases/tag/latest-macos-build) release. It uses `Invasiones.xcodeproj`'s shared `Invasiones` scheme (`xcshareddata/xcschemes/`) and `ci/exportOptions.plist` (Developer ID, manual signing, team `44DMMFA3SQ`).

To enable it, add these secrets under **Settings → Secrets and variables → Actions** in the GitHub repo:

| Secret | How to get it |
|---|---|
| `BUILD_CERTIFICATE_BASE64` | In Keychain Access, export your **Developer ID Application** certificate (with private key) as a `.p12`, then run `base64 -i cert.p12 \| pbcopy` and paste the result. |
| `P12_PASSWORD` | The password you set when exporting the `.p12`. |
| `KEYCHAIN_PASSWORD` | Any random string — used only to protect the temporary CI keychain for the run. |
| `APPLE_ID` | Your Apple ID email (must be a member of the `44DMMFA3SQ` team). |
| `APPLE_APP_SPECIFIC_PASSWORD` | Generate one at [appleid.apple.com](https://appleid.apple.com) → Sign-In and Security → App-Specific Passwords. Used for `notarytool`, not your real Apple ID password. |

Once the secrets are set, push to `main` (or run the workflow manually from the Actions tab) to trigger a build.

# CruxShotter

CruxShotter is a macOS 14+ menu-bar screenshot app built with Swift 6, AppKit and SwiftUI.

## Build

```bash
# Run unit tests for the core library
swift test --package-path CruxShotKit

# Generate the Xcode project (requires XcodeGen) and build the app
xcodegen generate
xcodebuild -project CruxShot.xcodeproj -scheme CruxShot -configuration Debug build
```

## Install

```bash
brew tap qDonl/crux-shotter https://github.com/qDonl/crux-shotter
brew install --cask crux-shotter
```

## Releasing

`scripts/build-release.sh <version> [--skip-sign]` builds `build/CruxShotter-<version>.dmg` and prints its sha256
(`--skip-sign` gives an ad-hoc signed, non-notarized build). Pushing a `v*` tag runs
`.github/workflows/release.yml`, which signs, notarizes and publishes the DMG plus `appcast.xml`; without the
signing secrets (`DEVELOPER_ID_CERT_P12`, `DEVELOPER_ID_CERT_PASSWORD`, `APPLE_ID`, `APPLE_TEAM_ID`,
`APPLE_APP_PASSWORD`) it only emits a notice. After publishing, update `version` and `sha256` in
`Casks/crux-shotter.rb`.

### Auto-update (Sparkle)

Updates are disabled until an EdDSA key is configured:

1. Run Sparkle's `generate_keys` once (private key stays in your login keychain).
2. Put the printed public key in `SPARKLE_PUBLIC_KEY` in `project.yml`.
3. Export the private key (`generate_keys -x file`) and store it as the GitHub secret `SPARKLE_PRIVATE_KEY`.

Until then the 「检查更新…」 menu item and the Settings button are disabled.

## License

MIT

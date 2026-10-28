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

## License

MIT

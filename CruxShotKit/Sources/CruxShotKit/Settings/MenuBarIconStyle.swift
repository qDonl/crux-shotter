import Foundation

/// The two switchable menu bar icons. Images live in the app's asset catalog as template images.
public enum MenuBarIconStyle: String, CaseIterable, Sendable {
    case monogram
    case scissors

    public var assetName: String {
        switch self {
        case .monogram: "MenuBarIconC"
        case .scissors: "MenuBarIconScissors"
        }
    }

    public var title: String {
        switch self {
        case .monogram: "字母 C"
        case .scissors: "剪刀"
        }
    }
}

import Foundation
import Combine

@MainActor
public final class Preferences: ObservableObject {
    public static let shared = Preferences(defaults: .standard)

    public static let fallbackDirectory: URL =
        FileManager.default.urls(for: .picturesDirectory, in: .userDomainMask).first
        ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Pictures")

    static var defaultSaveDirectory: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Desktop").appendingPathComponent("CruxShotter")
    }

    private let defaults: UserDefaults

    @Published public var automaticallyChecksForUpdates: Bool {
        didSet { defaults.set(automaticallyChecksForUpdates, forKey: Key.automaticallyChecksForUpdates) }
    }
    @Published public var saveDirectory: URL {
        didSet { defaults.set(saveDirectory.path, forKey: Key.saveDirectory) }
    }
    @Published public var imageFormat: ImageFormat {
        didSet { defaults.set(imageFormat.rawValue, forKey: Key.imageFormat) }
    }
    @Published public var fileNameTemplate: String {
        didSet { defaults.set(fileNameTemplate, forKey: Key.fileNameTemplate) }
    }
    @Published public var lastColor: PaletteColor {
        didSet { defaults.set(lastColor.rawValue, forKey: Key.lastColor) }
    }
    @Published public var lastLineWidth: LineWidth {
        didSet { defaults.set(Double(lastLineWidth.rawValue), forKey: Key.lastLineWidth) }
    }
    @Published public var lastArrowStyle: ArrowStyle {
        didSet { defaults.set(lastArrowStyle.rawValue, forKey: Key.lastArrowStyle) }
    }
    @Published public var colorFormat: ColorFormat {
        didSet { defaults.set(colorFormat.rawValue, forKey: Key.colorFormat) }
    }
    @Published public var mosaicMode: MosaicMode {
        didSet { defaults.set(mosaicMode.rawValue, forKey: Key.mosaicMode) }
    }
    @Published public var menuBarIconStyle: MenuBarIconStyle {
        didSet { defaults.set(menuBarIconStyle.rawValue, forKey: Key.menuBarIconStyle) }
    }

    private enum Key {
        static let automaticallyChecksForUpdates = "cruxshot.updates.automatic"
        static let saveDirectory = "cruxshot.saveDirectory"
        static let imageFormat = "cruxshot.imageFormat"
        static let fileNameTemplate = "cruxshot.fileNameTemplate"
        static let lastColor = "cruxshot.lastColor"
        static let lastLineWidth = "cruxshot.lastLineWidth"
        static let lastArrowStyle = "cruxshot.lastArrowStyle"
        static let colorFormat = "cruxshot.colorFormat"
        static let mosaicMode = "cruxshot.mosaicMode"
        static let menuBarIconStyle = "cruxshot.menuBarIconStyle"
    }

    public init(defaults: UserDefaults) {
        self.defaults = defaults
        automaticallyChecksForUpdates = defaults.object(forKey: Key.automaticallyChecksForUpdates) as? Bool ?? true
        if let path = defaults.string(forKey: Key.saveDirectory), !path.isEmpty {
            saveDirectory = URL(fileURLWithPath: path, isDirectory: true)
        } else {
            saveDirectory = Self.defaultSaveDirectory
        }
        imageFormat = defaults.string(forKey: Key.imageFormat).flatMap(ImageFormat.init(rawValue:)) ?? .png
        fileNameTemplate = defaults.string(forKey: Key.fileNameTemplate) ?? FileNameTemplate.default.pattern
        lastColor = defaults.string(forKey: Key.lastColor).flatMap(PaletteColor.init(rawValue:)) ?? .red
        lastLineWidth = (defaults.object(forKey: Key.lastLineWidth) as? Double)
            .flatMap { LineWidth(rawValue: CGFloat($0)) } ?? .medium
        lastArrowStyle = defaults.string(forKey: Key.lastArrowStyle).flatMap(ArrowStyle.init(rawValue:)) ?? .classic
        colorFormat = defaults.string(forKey: Key.colorFormat).flatMap(ColorFormat.init(rawValue:)) ?? .hex
        mosaicMode = defaults.string(forKey: Key.mosaicMode).flatMap(MosaicMode.init(rawValue:)) ?? .pixelate
        menuBarIconStyle = defaults.string(forKey: Key.menuBarIconStyle)
            .flatMap(MenuBarIconStyle.init(rawValue:)) ?? .monogram
    }
}

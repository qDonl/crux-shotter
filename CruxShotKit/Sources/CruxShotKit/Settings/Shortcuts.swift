import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    public static let captureArea = Self("captureArea", default: .init(.a, modifiers: [.control, .shift]))
    public static let captureFullScreen = Self("captureFullScreen", default: .init(.f, modifiers: [.control, .shift]))
    public static let captureOCR = Self("captureOCR", default: .init(.o, modifiers: [.control, .shift]))
    public static let pinClipboard = Self("pinClipboard", default: .init(.p, modifiers: [.control, .shift]))
    public static let togglePins = Self("togglePins", default: .init(.h, modifiers: [.control, .shift]))
    public static let restorePin = Self("restorePin", default: .init(.z, modifiers: [.control, .shift]))
}

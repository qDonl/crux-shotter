import AppKit

public enum OverlayAction: Equatable {
    case cancel, copy, save, pin, ocr, undo, redo
    case selectTool(CanvasTool)
    case nudge(dx: Int, dy: Int)
    case resize(dw: Int, dh: Int)
    case copyColor, toggleColorFormat
}

public enum OverlayKeyMap {
    public static func action(keyCode: UInt16, characters: String?, modifiers: NSEvent.ModifierFlags,
                              phase: SelectionModel.Phase, isEditingText: Bool) -> OverlayAction? {
        // While editing text the view handles everything (including Esc).
        if isEditingText { return nil }
        let mods = modifiers.intersection([.command, .shift, .option, .control])

        if keyCode == 53 { return .cancel }

        if let (dx, dy) = arrowDelta(keyCode) {
            if mods == [] { return .nudge(dx: dx, dy: dy) }
            if mods == .shift { return .nudge(dx: dx * 10, dy: dy * 10) }
            if mods == .option { return .resize(dw: dx, dh: dy) }
            return nil
        }

        let ch = characters?.lowercased()
        switch phase {
        case .selecting:
            if mods == [], ch == "c" { return .copyColor }
            return nil
        case .adjusting:
            if mods == [], keyCode == 36 || keyCode == 76 { return .copy }
            if mods == .command {
                switch ch {
                case "s": return .save
                case "t": return .pin
                case "z": return .undo
                default: return nil
                }
            }
            if mods == [.command, .shift] {
                switch ch {
                case "c": return .ocr
                case "z": return .redo
                default: return nil
                }
            }
            if mods == [] {
                switch ch {
                case "r": return .selectTool(.rect)
                case "a": return .selectTool(.arrow)
                case "p": return .selectTool(.pen)
                case "t": return .selectTool(.text)
                case "n": return .selectTool(.counter)
                case "m": return .selectTool(.mosaic)
                default: return nil
                }
            }
            return nil
        }
    }

    private static func arrowDelta(_ keyCode: UInt16) -> (Int, Int)? {
        switch keyCode {
        case 123: (-1, 0)
        case 124: (1, 0)
        case 125: (0, -1)
        case 126: (0, 1)
        default: nil
        }
    }
}

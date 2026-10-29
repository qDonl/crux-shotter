import AppKit

public enum PinAction: Equatable {
    case close, resetScale, rotateCW, rotateCCW, flipH, flipV, edit, toggleClickThrough, copy, save
}

public enum PinKeyMap {
    public static func action(characters: String?, keyCode: UInt16, modifiers: NSEvent.ModifierFlags) -> PinAction? {
        let mods = modifiers.intersection([.command, .shift, .option, .control])
        if keyCode == 53 { return .close }
        guard let ch = characters else { return nil }
        if mods == .command {
            switch ch {
            case "c": return .copy
            case "s": return .save
            default: return nil
            }
        }
        if ch == "R", mods.isSubset(of: .shift) { return .rotateCCW }
        if ch == "r", mods == .shift { return .rotateCCW }
        guard mods.isEmpty else { return nil }
        switch ch {
        case "1": return .resetScale
        case "r": return .rotateCW
        case "h": return .flipH
        case "v": return .flipV
        case "e": return .edit
        case "t": return .toggleClickThrough
        default: return nil
        }
    }
}

/// What a key does while a pin is being edited; mirrors the capture editor's shortcuts.
public enum PinEditAction: Equatable {
    /// ↩ / ✓: keep the changes. Esc: discard everything since editing began.
    case done, cancel, undo, redo, copy, save, ocr
    case toggleTool(CanvasTool)
}

public enum PinEditKeyMap {
    private static let toolKeys: [String: CanvasTool] = [
        "r": .rect, "a": .arrow, "p": .pen, "t": .text, "n": .counter, "m": .mosaic,
    ]

    public static func action(characters: String?, keyCode: UInt16, modifiers: NSEvent.ModifierFlags) -> PinEditAction? {
        let mods = modifiers.intersection([.command, .shift, .option, .control])
        if keyCode == 53 { return .cancel }
        if mods.isEmpty, keyCode == 36 || keyCode == 76 { return .done }
        let ch = characters?.lowercased()
        switch (mods, ch) {
        case (.command, "z"): return .undo
        case ([.command, .shift], "z"): return .redo
        case (.command, "c"): return .copy
        case (.command, "s"): return .save
        case ([.command, .shift], "c"): return .ocr
        case ([], let c?): return toolKeys[c].map { .toggleTool($0) }
        default: return nil
        }
    }
}

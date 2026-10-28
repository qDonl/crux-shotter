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

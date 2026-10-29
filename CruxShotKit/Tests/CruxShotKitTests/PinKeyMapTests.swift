import AppKit
import Testing
@testable import CruxShotKit

@Suite struct PinKeyMapTests {
    @Test func pinKeys() {
        #expect(PinKeyMap.action(characters: "1", keyCode: 18, modifiers: []) == .resetScale)
        #expect(PinKeyMap.action(characters: "R", keyCode: 15, modifiers: .shift) == .rotateCCW)
        #expect(PinKeyMap.action(characters: "r", keyCode: 15, modifiers: .shift) == .rotateCCW)
        #expect(PinKeyMap.action(characters: "r", keyCode: 15, modifiers: []) == .rotateCW)
        #expect(PinKeyMap.action(characters: "t", keyCode: 17, modifiers: []) == .toggleClickThrough)
        #expect(PinKeyMap.action(characters: nil, keyCode: 53, modifiers: []) == .close)
        #expect(PinKeyMap.action(characters: "h", keyCode: 4, modifiers: []) == .flipH)
        #expect(PinKeyMap.action(characters: "v", keyCode: 9, modifiers: []) == .flipV)
        #expect(PinKeyMap.action(characters: "e", keyCode: 14, modifiers: []) == .edit)
        #expect(PinKeyMap.action(characters: "c", keyCode: 8, modifiers: .command) == .copy)
        #expect(PinKeyMap.action(characters: "s", keyCode: 1, modifiers: .command) == .save)
        #expect(PinKeyMap.action(characters: "c", keyCode: 8, modifiers: [.command, .shift]) == nil)
        #expect(PinKeyMap.action(characters: "h", keyCode: 4, modifiers: .command) == nil)
        #expect(PinKeyMap.action(characters: "z", keyCode: 6, modifiers: []) == nil)
    }

    @Test func editKeysMirrorTheCaptureEditor() {
        #expect(PinEditKeyMap.action(characters: nil, keyCode: 53, modifiers: []) == .cancel)
        #expect(PinEditKeyMap.action(characters: "\r", keyCode: 36, modifiers: []) == .done)
        #expect(PinEditKeyMap.action(characters: "\r", keyCode: 76, modifiers: []) == .done)
        #expect(PinEditKeyMap.action(characters: "z", keyCode: 6, modifiers: .command) == .undo)
        #expect(PinEditKeyMap.action(characters: "Z", keyCode: 6, modifiers: [.command, .shift]) == .redo)
        #expect(PinEditKeyMap.action(characters: "c", keyCode: 8, modifiers: .command) == .copy)
        #expect(PinEditKeyMap.action(characters: "s", keyCode: 1, modifiers: .command) == .save)
        #expect(PinEditKeyMap.action(characters: "C", keyCode: 8, modifiers: [.command, .shift]) == .ocr)
        let tools: [(String, CanvasTool)] = [("r", .rect), ("a", .arrow), ("p", .pen), ("t", .text), ("n", .counter), ("m", .mosaic)]
        for (ch, tool) in tools {
            #expect(PinEditKeyMap.action(characters: ch, keyCode: 0, modifiers: []) == .toggleTool(tool))
        }
        #expect(PinEditKeyMap.action(characters: "h", keyCode: 4, modifiers: []) == nil)
        #expect(PinEditKeyMap.action(characters: "\r", keyCode: 36, modifiers: .command) == nil)
        #expect(PinEditKeyMap.action(characters: "e", keyCode: 14, modifiers: []) == nil)
    }
}

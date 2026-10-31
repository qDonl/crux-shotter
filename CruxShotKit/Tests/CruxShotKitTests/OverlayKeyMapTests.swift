import AppKit
import Testing
@testable import CruxShotKit

@Suite struct OverlayKeyMapTests {
    func act(_ code: UInt16, _ ch: String?, _ mods: NSEvent.ModifierFlags = [], _ phase: SelectionModel.Phase = .adjusting, editing: Bool = false) -> OverlayAction? {
        OverlayKeyMap.action(keyCode: code, characters: ch, modifiers: mods, phase: phase, isEditingText: editing)
    }

    @Test func keyMap() {
        #expect(act(36, "\r") == .copy)
        #expect(act(76, "\u{3}") == .copy)
        #expect(act(1, "s", .command) == .save)
        #expect(act(17, "t", .command) == .pin)
        #expect(act(8, "c", [.command, .shift]) == .ocr)
        #expect(act(6, "z", .command) == .undo)
        #expect(act(6, "z", [.command, .shift]) == .redo)
        #expect(act(124, nil, .shift, .selecting) == .nudge(dx: 10, dy: 0))
        #expect(act(15, "r") == .selectTool(.rect))
        #expect(act(15, "r", [], .adjusting, editing: true) == nil)
        #expect(act(8, "c", [], .selecting) == .copyColor)
    }
    @Test func arrows() {
        #expect(act(126, nil, [], .selecting) == .nudge(dx: 0, dy: 1))
        #expect(act(125, nil) == .nudge(dx: 0, dy: -1))
        #expect(act(123, nil) == .nudge(dx: -1, dy: 0))
        #expect(act(126, nil, .shift) == .nudge(dx: 0, dy: 10))
        #expect(act(124, nil, .option) == .resize(dw: 1, dh: 0))
        #expect(act(125, nil, .option, .selecting) == .resize(dw: 0, dh: -1))
    }
    @Test func tools() {
        #expect(act(0, "a") == .selectTool(.arrow))
        #expect(act(35, "P") == .selectTool(.pen))
        #expect(act(17, "t") == .selectTool(.text))
        #expect(act(45, "n") == .selectTool(.counter))
        #expect(act(46, "m") == .selectTool(.mosaic))
        #expect(act(15, "r", [], .selecting) == nil)
    }
    @Test func escape() {
        #expect(act(53, nil, [], .selecting) == .cancel)
        #expect(act(53, nil) == .cancel)
        #expect(act(53, nil, [], .adjusting, editing: true) == nil)
    }
    @Test func editingSwallowsEverything() {
        #expect(act(124, nil, .shift, .adjusting, editing: true) == nil)
        #expect(act(1, "s", .command, .adjusting, editing: true) == nil)
    }
    @Test func unrelatedKeys() {
        #expect(act(1, "s") == nil)
        #expect(act(6, "z", [.command, .option]) == nil)
    }
}

@Test func selectionToolShortcutDoesNotInterceptTextInput() {
    #expect(OverlayKeyMap.action(keyCode: 9, characters: "v", modifiers: [], phase: .adjusting,
                                isEditingText: false) == .selectTool(nil))
    #expect(OverlayKeyMap.action(keyCode: 9, characters: "v", modifiers: [], phase: .adjusting,
                                isEditingText: true) == nil)
    #expect(OverlayKeyMap.action(keyCode: 9, characters: "v", modifiers: [], phase: .selecting,
                                isEditingText: false) == nil)
    #expect(PinEditKeyMap.action(characters: "v", keyCode: 9, modifiers: []) == .select)
    #expect(PinKeyMap.action(characters: "v", keyCode: 9, modifiers: []) == .flipV)
}

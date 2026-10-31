import AppKit
import Testing
@testable import CruxShotKit

@Suite struct LineWidthInteractionTests {
    @Test func stepsAcrossEveryIntegerWidthAndClampsAtEnds() {
        var width = LineWidth.one
        #expect(width.stepped(by: -1) == .one)
        for value in 2...12 {
            width = width.stepped(by: 1)
            #expect(Int(width.rawValue) == value)
        }
        #expect(width.stepped(by: 1) == .twelve)
        #expect(width.stepped(by: -1) == .eleven)
        #expect(LineWidth.medium.stepped(by: -1) == .three)
    }

    @Test(arguments: [CanvasTool.rect, .arrow, .pen])
    @MainActor func changingWidthWhileDraggingUpdatesTheVisibleStrokeAndCommittedMark(_ tool: CanvasTool) throws {
        _ = NSApplication.shared
        let doc = AnnotationDocument(image: makeImage(width: 100, height: 100) { _, _ in RGBColor(r: 255, g: 255, b: 255) }, scale: 1)
        let canvas = CanvasView(document: doc)
        canvas.tool = tool
        canvas.onLineWidthStep = { [weak canvas] delta, _ in
            guard let canvas else { return }
            canvas.applyLineWidth(canvas.style.lineWidth.stepped(by: delta))
        }
        let window = NSWindow(contentRect: CGRect(x: 0, y: 0, width: 100, height: 100),
                              styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        defer { window.close() }
        window.contentView = canvas

        func event(_ type: NSEvent.EventType, at point: CGPoint) throws -> NSEvent {
            try #require(NSEvent.mouseEvent(with: type, location: canvas.convert(point, to: nil),
                                            modifierFlags: [], timestamp: 0, windowNumber: window.windowNumber,
                                            context: nil, eventNumber: 0, clickCount: 1, pressure: 1))
        }
        func pixels() throws -> Data {
            let bitmap = try #require(canvas.bitmapImageRepForCachingDisplay(in: canvas.bounds))
            canvas.cacheDisplay(in: canvas.bounds, to: bitmap)
            return try #require(bitmap.representation(using: .png, properties: [:]))
        }

        canvas.mouseDown(with: try event(.leftMouseDown, at: CGPoint(x: 20, y: 20)))
        canvas.mouseDragged(with: try event(.leftMouseDragged, at: CGPoint(x: 80, y: 80)))
        let before = try pixels()
        func press(_ keyCode: UInt16, _ character: String) throws {
            let key = try #require(NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [],
                                                  timestamp: 0, windowNumber: window.windowNumber, context: nil,
                                                  characters: character, charactersIgnoringModifiers: character,
                                                  isARepeat: false, keyCode: keyCode))
            canvas.keyDown(with: key)
        }
        try press(18, "1")
        #expect(canvas.style.lineWidth == .three)
        #expect(try pixels() != before)
        try press(19, "2")
        #expect(canvas.style.lineWidth == .medium)
        #expect(try pixels() == before)
        try press(19, "2")
        #expect(canvas.style.lineWidth == .five)
        #expect(try pixels() != before)
        try press(18, "1")
        #expect(canvas.style.lineWidth == .medium)
        try press(19, "2")
        #expect(canvas.style.lineWidth == .five)
        #expect(try pixels() != before)
        canvas.mouseUp(with: try event(.leftMouseUp, at: CGPoint(x: 80, y: 80)))
        #expect(doc.annotations.first?.style.lineWidth == .five)
    }

    @Test @MainActor func alternatingKeysAlsoUpdateAnExistingSelectedMarkThroughTheHost() throws {
        _ = NSApplication.shared
        let mark = Annotation(kind: .rect(CGRect(x: 10, y: 10, width: 40, height: 40)))
        let doc = AnnotationDocument(image: makeImage(width: 80, height: 80) { _, _ in RGBColor(r: 255, g: 255, b: 255) },
                                     scale: 1, annotations: [mark])
        let canvas = CanvasView(document: doc)
        canvas.select(mark.id)
        let window = NSWindow(contentRect: CGRect(x: 0, y: 0, width: 80, height: 80),
                              styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        defer { window.close() }
        window.contentView = canvas
        window.makeFirstResponder(canvas)
        canvas.onLineWidthStep = { [weak canvas] delta, point in
            guard let canvas else { return }
            let current = canvas.selectedAnnotationStyle?.lineWidth ?? canvas.style.lineWidth
            let next = current.stepped(by: delta)
            canvas.applyLineWidth(next)
            canvas.showLineWidth(next, near: point)
        }
        func key(_ code: UInt16, _ character: String) throws -> NSEvent {
            try #require(NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [],
                                          timestamp: 0, windowNumber: window.windowNumber, context: nil,
                                          characters: character, charactersIgnoringModifiers: character,
                                          isARepeat: false, keyCode: code))
        }
        #expect(canvas.handleLineWidthKey(try key(18, "1")))
        #expect(doc.annotations[0].style.lineWidth == .three)
        #expect(canvas.handleLineWidthKey(try key(19, "2")))
        #expect(doc.annotations[0].style.lineWidth == .medium)
        canvas.keyDown(with: try key(19, "2"))
        #expect(doc.annotations[0].style.lineWidth == .five)
        canvas.keyDown(with: try key(18, "1"))
        #expect(doc.annotations[0].style.lineWidth == .medium)
        #expect(window.firstResponder === canvas)
    }
}

import AppKit
import Testing
@testable import CruxShotKit

@Suite @MainActor struct PostDrawEditingTests {
    @Test func selectedPropertiesLeaveNextMarkDefaultsAndMosaicCanBeRestyled() {
        let document = AnnotationDocument(image: makeImage(width: 120, height: 120) { _, _ in RGBColor(r: 255, g: 255, b: 255) }, scale: 1)
        let canvas = CanvasView(document: document)
        let arrow = Annotation(kind: .arrow(from: CGPoint(x: 10, y: 10), to: CGPoint(x: 50, y: 50)))
        let mosaic = Annotation(kind: .mosaic(CGRect(x: 60, y: 60, width: 20, height: 20), .pixelate))
        document.add(arrow)
        document.add(mosaic)
        canvas.tool = .arrow
        canvas.select(arrow.id)
        canvas.applyArrowStyle(.dashed)
        canvas.applyColor(.blue)
        canvas.applyLineWidth(.thick)
        #expect(document.annotations[0].style.arrowStyle == .dashed)
        #expect(document.annotations[0].style.color == .blue)
        #expect(document.annotations[0].style.lineWidth == .thick)
        #expect(canvas.style == AnnotationStyle())
        canvas.select(mosaic.id)
        canvas.applyMosaicMode(.blur)
        #expect(document.annotations[1].kind == .mosaic(CGRect(x: 60, y: 60, width: 20, height: 20), .blur))
        #expect(canvas.mosaicMode == .pixelate)
        document.undo()
        #expect(document.annotations[1] == mosaic)
    }

    @Test(arguments: [CanvasTool.rect, .arrow])
    func newMarkCanChangeWidthAndMoveAfterMouseUp(_ tool: CanvasTool) throws {
        _ = NSApplication.shared
        let document = AnnotationDocument(image: makeImage(width: 120, height: 120) { _, _ in RGBColor(r: 255, g: 255, b: 255) }, scale: 1)
        let canvas = CanvasView(document: document)
        canvas.tool = tool
        func event(_ type: NSEvent.EventType, _ p: CGPoint) throws -> NSEvent {
            try #require(NSEvent.mouseEvent(with: type, location: canvas.convert(p, to: nil), modifierFlags: [],
                                            timestamp: 0, windowNumber: 0, context: nil, eventNumber: 0,
                                            clickCount: 1, pressure: 1))
        }
        canvas.mouseDown(with: try event(.leftMouseDown, CGPoint(x: 20, y: 20)))
        canvas.mouseDragged(with: try event(.leftMouseDragged, CGPoint(x: 80, y: 80)))
        canvas.mouseUp(with: try event(.leftMouseUp, CGPoint(x: 80, y: 80)))
        let created = try #require(document.annotations.first)
        #expect(canvas.tool == tool)
        #expect(canvas.selectedID == created.id)
        canvas.applyLineWidth(.thick)
        #expect(document.annotations[0].style.lineWidth == .thick)
        let grab = CGPoint(x: 50, y: 50)
        canvas.mouseDown(with: try event(.leftMouseDown, grab))
        canvas.mouseDragged(with: try event(.leftMouseDragged, CGPoint(x: grab.x + 10, y: grab.y + 10)))
        canvas.mouseUp(with: try event(.leftMouseUp, CGPoint(x: grab.x + 10, y: grab.y + 10)))
        #expect(document.annotations[0].bounds.minX > created.bounds.minX)
        canvas.mouseDown(with: try event(.leftMouseDown, CGPoint(x: 5, y: 100)))
        canvas.mouseDragged(with: try event(.leftMouseDragged, CGPoint(x: 20, y: 115)))
        canvas.mouseUp(with: try event(.leftMouseUp, CGPoint(x: 20, y: 115)))
        #expect(document.annotations.count == 2)
        #expect(canvas.tool == tool)
        #expect(canvas.selectedID == document.annotations.last?.id)
    }

    @Test func textCanMoveAfterEditingEnds() throws {
        _ = NSApplication.shared
        let document = AnnotationDocument(image: makeImage(width: 120, height: 120) { _, _ in RGBColor(r: 255, g: 255, b: 255) }, scale: 1)
        let canvas = CanvasView(document: document)
        canvas.tool = .text
        func event(_ type: NSEvent.EventType, _ p: CGPoint) throws -> NSEvent {
            try #require(NSEvent.mouseEvent(with: type, location: canvas.convert(p, to: nil), modifierFlags: [],
                                            timestamp: 0, windowNumber: 0, context: nil, eventNumber: 0,
                                            clickCount: 1, pressure: 1))
        }
        canvas.mouseDown(with: try event(.leftMouseDown, CGPoint(x: 20, y: 20)))
        let editor = try #require(canvas.subviews.compactMap { $0 as? NSTextView }.first)
        editor.string = "测试"
        canvas.commitTextEditing()
        let created = try #require(document.annotations.first)
        #expect(canvas.tool == .text)
        #expect(canvas.selectedID == created.id)
        let point = CGPoint(x: created.bounds.midX, y: created.bounds.midY)
        canvas.mouseDown(with: try event(.leftMouseDown, point))
        canvas.mouseDragged(with: try event(.leftMouseDragged, CGPoint(x: point.x + 10, y: point.y + 10)))
        canvas.mouseUp(with: try event(.leftMouseUp, CGPoint(x: point.x + 10, y: point.y + 10)))
        #expect(document.annotations[0].bounds.minX > created.bounds.minX)
        canvas.mouseDown(with: try event(.leftMouseDown, CGPoint(x: 80, y: 80)))
        try #require(canvas.subviews.compactMap { $0 as? NSTextView }.first).string = "第二条"
        canvas.commitTextEditing()
        #expect(document.annotations.count == 2)
        #expect(canvas.tool == .text)
        #expect(canvas.selectedID == document.annotations.last?.id)
    }

    @Test func clickThatFinishesTextKeepsItSelected() throws {
        _ = NSApplication.shared
        let document = AnnotationDocument(image: makeImage(width: 120, height: 120) { _, _ in RGBColor(r: 255, g: 255, b: 255) }, scale: 1)
        let canvas = CanvasView(document: document)
        canvas.tool = .text
        func event(_ p: CGPoint) throws -> NSEvent {
            try #require(NSEvent.mouseEvent(with: .leftMouseDown, location: canvas.convert(p, to: nil),
                                            modifierFlags: [], timestamp: 0, windowNumber: 0,
                                            context: nil, eventNumber: 0, clickCount: 1, pressure: 1))
        }
        canvas.mouseDown(with: try event(CGPoint(x: 20, y: 20)))
        try #require(canvas.subviews.compactMap { $0 as? NSTextView }.first).string = "文字"
        canvas.mouseDown(with: try event(CGPoint(x: 90, y: 90)))
        #expect(canvas.selectedID == document.annotations.first?.id)
        #expect(canvas.tool == .text)
    }
}

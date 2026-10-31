import AppKit
import Testing
@testable import CruxShotKit

/// Component tests call the event handlers directly; no windows or system input are used.
@MainActor
struct CaptureReframeTests {
    let display = DisplayInfo(displayID: 1, frame: CGRect(x: -300, y: -100, width: 300, height: 200), scale: 2)
    let initial = CGRect(x: -240, y: -50, width: 100, height: 80)

    func snapshot() -> CaptureSnapshot {
        let image = makeImage(width: 600, height: 400) { x, y in
            RGBColor(r: UInt8(x % 256), g: UInt8(y % 256), b: 20)
        }
        let other = DisplayInfo(displayID: 2, frame: CGRect(x: 0, y: -100, width: 200, height: 200), scale: 1)
        return CaptureSnapshot(frames: [CapturedFrame(display: display, image: image),
            CapturedFrame(display: other, image: makeImage(width: 200, height: 200) { _, _ in .init(r: 0, g: 0, b: 255) })], windows: [])
    }

    func controller() -> OverlayController {
        let controller = OverlayController(snapshot: snapshot(), mode: .annotate,
            preferences: Preferences(defaults: UserDefaults(suiteName: "CaptureReframeTests.\(UUID())")!))
        controller.mouseDown(at: initial.origin, clickCount: 1)
        controller.mouseUp(at: CGPoint(x: initial.maxX, y: initial.maxY))
        return controller
    }

    func key(_ controller: OverlayController, code: UInt16, characters: String = "", modifiers: NSEvent.ModifierFlags = []) throws {
        let event = try #require(NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: modifiers,
            timestamp: 0, windowNumber: 0, context: nil, characters: characters,
            charactersIgnoringModifiers: characters, isARepeat: false, keyCode: code))
        #expect(controller.handleKey(event))
    }

    @Test func annotatedResizeIsOneUndoableEditAndUsesOriginalPixels() throws {
        let c = controller()
        let d = try #require(c.document)
        let mark = Annotation(kind: .pen([CGPoint(x: 30, y: 25)]))
        d.add(mark)
        #expect(c.isGeometryEditable)
        c.mouseDown(at: CGPoint(x: initial.minX, y: initial.maxY), clickCount: 1)
        c.mouseDragged(to: CGPoint(x: -260, y: 40))
        c.mouseDragged(to: CGPoint(x: -270, y: 45))
        // The final event position is applied even without another drag event.
        c.mouseUp(at: CGPoint(x: -280, y: 50))
        let expanded = CGRect(x: -280, y: -50, width: 140, height: 100)
        #expect(c.document === d)
        #expect(c.model.rect == expanded && d.captureFrame == expanded)
        #expect(d.annotations == [mark.translated(by: CGVector(dx: 40, dy: 20))])
        #expect(d.image.width == 280 && d.image.height == 200)
        #expect(PixelSampler(image: d.image).color(atPixel: 0, 0) == RGBColor(r: 40, g: 100, b: 20))
        let rendered = AnnotationRenderer.render(d)
        #expect(rendered.width == 280 && rendered.height == 200)
        let ink = try #require(PixelSampler(image: rendered).color(atPixel: 140, 90))
        #expect(ink.r > 200 && ink.g < 100)
        try key(c, code: 6, characters: "z", modifiers: .command)
        #expect(c.model.rect == initial && d.captureFrame == initial)
        #expect(d.image.width == 200 && d.image.height == 160 && d.annotations == [mark])
        try key(c, code: 6, characters: "z", modifiers: .command)
        #expect(d.annotations.isEmpty) // Annotation history survived the resize.
        try key(c, code: 6, characters: "z", modifiers: [.command, .shift])
        try key(c, code: 6, characters: "z", modifiers: [.command, .shift])
        #expect(d.captureFrame == expanded && d.annotations.count == 1)
    }

    @Test func cancellingDragRestoresSelectionWithoutHistoryAndBlocksPrematureExport() throws {
        let c = controller(), d = try #require(c.document)
        c.mouseDown(at: CGPoint(x: initial.maxX, y: initial.midY), clickCount: 1)
        c.mouseDragged(to: CGPoint(x: -100, y: initial.midY))
        try key(c, code: 36) // Return must not export the old crop while previewing a new one.
        #expect(c.document === d && d.captureFrame == initial)
        try key(c, code: 53)
        #expect(c.model.rect == initial && !d.canUndo)
        c.mouseDown(at: CGPoint(x: initial.maxX, y: initial.midY), clickCount: 1)
        c.mouseUp(at: CGPoint(x: -100, y: initial.midY))
        #expect(d.captureFrame?.width == 140 && d.canUndo)
    }

    @Test func emptySpaceMovesCropButMarksKeepGlobalPosition() throws {
        let c = controller(), d = try #require(c.document)
        let mark = Annotation(kind: .pen([CGPoint(x: 30, y: 25)]))
        d.add(mark)
        #expect(!c.isSelectionBackground(at: CGPoint(x: -210, y: 5)))
        let empty = CGPoint(x: -160, y: -30)
        #expect(c.isSelectionBackground(at: empty))
        c.mouseDown(at: empty, clickCount: 1)
        c.mouseUp(at: CGPoint(x: empty.x + 20, y: empty.y + 10))
        #expect(d.captureFrame == initial.offsetBy(dx: 20, dy: 10))
        #expect(d.annotations == [mark.translated(by: CGVector(dx: -20, dy: 10))])
    }

    @Test func cropNeverSwitchesToAdjacentDisplayAndKeyboardUsesPixelSteps() throws {
        let c = controller(), d = try #require(c.document)
        c.mouseDown(at: CGPoint(x: initial.maxX, y: initial.midY), clickCount: 1)
        c.mouseUp(at: CGPoint(x: 190, y: initial.midY))
        #expect(d.captureFrame == CGRect(x: -240, y: -50, width: 240, height: 80))
        #expect(d.scale == 2 && d.image.width == 480)
        try key(c, code: 124) // Right edge at display boundary: no movement or shrink.
        #expect(d.captureFrame?.maxX == 0 && d.image.width == 480)
        try key(c, code: 123)
        #expect(d.captureFrame?.minX == -240.5 && d.captureFrame?.width == 240)
        try key(c, code: 123, modifiers: .option)
        #expect(d.captureFrame?.width == 239.5 && d.image.width == 479)
    }

    @Test func shrinkingThenExpandingRetainsEveryAnnotationKindAndStyle() throws {
        let pixels = SnapshotPixels(snapshot: snapshot())
        let crop = try #require(pixels.crop(initial))
        let d = AnnotationDocument(image: crop.image, scale: 2, captureFrame: crop.globalRect)
        var marks: [Annotation] = [
            .init(kind: .rect(CGRect(x: 1, y: 1, width: 15, height: 10))),
            .init(kind: .pen([CGPoint(x: 2, y: 3), CGPoint(x: 4, y: 5)])),
            .init(kind: .text(origin: CGPoint(x: 5, y: 5), string: "测试")),
            .init(kind: .counter(center: CGPoint(x: 5, y: 5), number: 1)),
            .init(kind: .mosaic(CGRect(x: 0, y: 0, width: 15, height: 15), .pixelate)),
            .init(kind: .mosaic(CGRect(x: 5, y: 5, width: 15, height: 15), .blur))]
        marks += ArrowStyle.allCases.map { .init(kind: .arrow(from: CGPoint(x: 2, y: 3), to: CGPoint(x: 30, y: 20)),
            style: AnnotationStyle(color: .blue, lineWidth: .thick, arrowStyle: $0), arrowBend: 0.4) }
        marks.forEach(d.add)
        let small = try #require(pixels.crop(CGRect(x: -200, y: -50, width: 60, height: 40)))
        #expect(d.reframe(image: small.image, scale: 2, frame: small.globalRect))
        #expect(d.annotations == marks.map { $0.translated(by: CGVector(dx: -40, dy: -40)) })
        #expect(d.reframe(image: crop.image, scale: 2, frame: crop.globalRect))
        #expect(d.annotations == marks)
        #expect(!d.reframe(image: crop.image, scale: 2, frame: crop.globalRect))
        #expect(!d.reframe(image: small.image, scale: 2, frame: initial)) // Invalid dimensions.
        d.undo()
        #expect(d.captureFrame == small.globalRect)
        d.add(.init(kind: .pen([CGPoint(x: 1, y: 1)])))
        #expect(!d.canRedo)
    }
}

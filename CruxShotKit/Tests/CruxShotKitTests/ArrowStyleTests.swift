import AppKit
import Testing
@testable import CruxShotKit

@Suite struct ArrowGeometryTests {
    @Test func sixSelectedStylesAndClassicDefault() {
        #expect(ArrowStyle.allCases == [.classic, .fine, .tapered, .doubleEnded, .dashed, .handDrawn])
        #expect(AnnotationStyle().arrowStyle == .classic)
    }

    @Test(arguments: ArrowStyle.allCases)
    func shortReversedAndVerticalArrowsStayFinite(_ style: ArrowStyle) {
        for length: CGFloat in [0.01, 2, 12, 150] {
            for end in [CGPoint(x: length, y: 0), CGPoint(x: -length, y: 0), CGPoint(x: 0, y: length), CGPoint(x: length, y: -length)] {
                for width in LineWidth.allCases {
                    let geometry = ArrowGeometry(from: .zero, to: end, style: style, lineWidth: width.rawValue)
                    let bounds = geometry.bounds
                    #expect(!bounds.isNull)
                    #expect(bounds.minX.isFinite && bounds.minY.isFinite && bounds.width.isFinite && bounds.height.isFinite)
                    #expect(bounds.width < hypot(end.x, end.y) * 3 + width.rawValue * 2)
                    #expect(bounds.height < hypot(end.x, end.y) * 3 + width.rawValue * 2)
                }
            }
        }
        #expect(ArrowGeometry(from: .zero, to: .zero, style: style, lineWidth: 4).bounds.isNull)
        #expect(ArrowGeometry(from: .zero, to: CGPoint(x: CGFloat.nan, y: 10), style: style, lineWidth: 4).bounds.isNull)
    }

    @Test func visibleArrowheadsAreSelectableAndOpenHeadStaysOpen() {
        let end = CGPoint(x: 100, y: 0)
        let classic = ArrowGeometry(from: .zero, to: end, style: .classic, lineWidth: 4)
        let fine = ArrowGeometry(from: .zero, to: end, style: .fine, lineWidth: 4)
        let double = ArrowGeometry(from: .zero, to: end, style: .doubleEnded, lineWidth: 4)
        #expect(classic.contains(CGPoint(x: 85, y: 7), tolerance: 0))
        #expect(classic.contains(CGPoint(x: 86, y: 5), tolerance: 0))
        #expect(!fine.contains(CGPoint(x: 86, y: 5), tolerance: 0))
        #expect(double.contains(CGPoint(x: 10, y: 4), tolerance: 0))
        #expect(!classic.contains(CGPoint(x: 10, y: 4), tolerance: 0))
    }

    @Test func curveHitTestingFollowsTheCurveInsteadOfTheStraightChord() {
        let end = CGPoint(x: 100, y: 0)
        let geometry = ArrowGeometry(from: .zero, to: end, style: .handDrawn, lineWidth: 4)
        let handle = ArrowGeometry.bendHandle(from: .zero, to: end, bend: -0.18)
        #expect(handle == CGPoint(x: 50, y: -18))
        #expect(geometry.contains(handle, tolerance: 1))
        #expect(!geometry.contains(CGPoint(x: 50, y: 0), tolerance: 1))
        #expect(geometry.bounds.contains(handle))
    }

    @Test func movingAndResizingRetainStyleAndCurvature() {
        let a = Annotation(kind: .arrow(from: CGPoint(x: 10, y: 30), to: CGPoint(x: 110, y: 30)),
                           style: AnnotationStyle(arrowStyle: .handDrawn), arrowBend: -0.3)
        let moved = a.translated(by: CGVector(dx: 20, dy: -10))
        #expect(moved.kind == .arrow(from: CGPoint(x: 30, y: 20), to: CGPoint(x: 130, y: 20)))
        #expect(moved.style == a.style && moved.arrowBend == a.arrowBend && moved.id == a.id)
        let handles = AnnotationResizer.handles(for: a)
        #expect(handles.map(\.0) == [.arrowStart, .arrowEnd, .arrowBend])
        let curved = AnnotationResizer.resized(a, handle: .arrowBend, to: CGPoint(x: 60, y: 70))
        #expect(abs(curved.arrowBend - 0.4) < 0.0001)
        #expect(curved.kind == a.kind && curved.style == a.style)
        let endpoint = AnnotationResizer.resized(curved, handle: .arrowEnd, to: CGPoint(x: 150, y: 50))
        #expect(endpoint.arrowBend == curved.arrowBend && endpoint.style == a.style)
        let clamped = AnnotationResizer.resized(a, handle: .arrowBend, to: CGPoint(x: 60, y: 1000))
        #expect(clamped.arrowBend == 0.75)
    }
}

@Suite @MainActor struct ArrowEditingTests {
    private func document(_ annotations: [Annotation]) -> AnnotationDocument {
        AnnotationDocument(image: makeImage(width: 200, height: 150) { _, _ in RGBColor(r: 255, g: 255, b: 255) },
                           scale: 1, annotations: annotations)
    }

    @Test func styleChangeOnlyTouchesSelectedArrowAndUndoesOnce() {
        let first = Annotation(kind: .arrow(from: .zero, to: CGPoint(x: 100, y: 30)))
        let second = Annotation(kind: .arrow(from: CGPoint(x: 10, y: 80), to: CGPoint(x: 100, y: 80)))
        let doc = document([first, second])
        let canvas = CanvasView(document: doc)
        canvas.select(first.id)
        canvas.applyArrowStyle(.classic)
        #expect(!doc.canUndo)
        canvas.applyArrowStyle(.handDrawn)
        #expect(doc.annotations[0].style.arrowStyle == .handDrawn)
        #expect(doc.annotations[0].kind == first.kind && doc.annotations[0].arrowBend == first.arrowBend)
        #expect(doc.annotations[1] == second)
        #expect(canvas.selectedArrowStyle == .handDrawn)
        doc.undo()
        #expect(doc.annotations == [first, second] && !doc.canUndo)
        doc.redo()
        #expect(doc.annotations[0].style.arrowStyle == .handDrawn)
    }

    @Test func colorAndWidthDoNotResetSelectedArrowVariant() {
        let a = Annotation(kind: .arrow(from: .zero, to: CGPoint(x: 100, y: 30)), style: AnnotationStyle(arrowStyle: .tapered))
        let doc = document([a])
        let canvas = CanvasView(document: doc)
        canvas.select(a.id)
        canvas.applyStyle(AnnotationStyle(color: .blue, lineWidth: .thick, arrowStyle: .classic))
        #expect(doc.annotations[0].style.arrowStyle == .tapered)
        #expect(doc.annotations[0].style.color == .blue && doc.annotations[0].style.lineWidth == .thick)
        doc.undo()
        #expect(doc.annotations[0] == a)
    }

    @Test func individualColorAndWidthEditsPreserveOtherSelectedAttributes() {
        let a = Annotation(kind: .arrow(from: .zero, to: CGPoint(x: 100, y: 30)),
                           style: AnnotationStyle(color: .green, lineWidth: .thick, arrowStyle: .dashed))
        let doc = document([a])
        let canvas = CanvasView(document: doc)
        canvas.select(a.id)
        canvas.applyColor(.blue)
        #expect(doc.annotations[0].style == AnnotationStyle(color: .blue, lineWidth: .thick, arrowStyle: .dashed))
        canvas.applyLineWidth(.thin)
        #expect(doc.annotations[0].style == AnnotationStyle(color: .blue, lineWidth: .thin, arrowStyle: .dashed))
        doc.undo()
        #expect(doc.annotations[0].style.lineWidth == .thick && doc.annotations[0].style.color == .blue)
        doc.undo()
        #expect(doc.annotations == [a] && !doc.canUndo)
    }

    @Test func iconPickerOffersOnlySelectedVariantsAndRoutesToCurrentArrow() {
        let a = Annotation(kind: .arrow(from: .zero, to: CGPoint(x: 100, y: 30)), style: AnnotationStyle(arrowStyle: .dashed))
        let doc = document([a]), toolbar = ToolbarView()
        let canvas = CanvasView(document: doc)
        canvas.select(a.id)
        toolbar.update(tool: nil, color: .red, lineWidth: .medium, mosaicMode: .pixelate,
                       canUndo: false, canRedo: false, selectedArrowStyle: canvas.selectedArrowStyle)
        #expect(toolbar.arrowStyleChoices.count == ArrowStyle.allCases.count)
        #expect(toolbar.arrowStyleChoices.filter { $0.value.isActive }.map(\.key) == [.dashed])
        #expect(toolbar.arrowStyleChoices.values.allSatisfy { $0.title.isEmpty && $0.toolTip != nil })
        #expect(toolbar.arrowStylePopover.contentViewController?.preferredContentSize.width ?? 0 > 100)
        #expect(toolbar.arrowStylePopover.contentViewController?.preferredContentSize.height ?? 0 > 100)
        toolbar.onCommand = { if case .arrowStyle(let style) = $0 { canvas.applyArrowStyle(style) } }
        // Dispatch the picker action in-process; no popup or external app is driven.
        toolbar.arrowStyleChoices[.handDrawn]?.performClick(nil)
        #expect(doc.annotations[0].style.arrowStyle == .handDrawn)
        #expect(canvas.selectedID == a.id)
        doc.undo()
        #expect(doc.annotations == [a])
    }

    @Test func changingDefaultDoesNotRestyleNonArrowOrCreateUndoEntry() {
        let a = Annotation(kind: .rect(CGRect(x: 10, y: 10, width: 20, height: 20)))
        let doc = document([a])
        let canvas = CanvasView(document: doc)
        canvas.select(a.id)
        canvas.applyArrowStyle(.doubleEnded)
        #expect(canvas.style.arrowStyle == .doubleEnded)
        #expect(doc.annotations == [a] && !doc.canUndo)
    }

    @Test func bendDragCommitsWhenArrowEndpointsDoNotChange() throws {
        let a = Annotation(kind: .arrow(from: CGPoint(x: 30, y: 70), to: CGPoint(x: 170, y: 70)),
                           style: AnnotationStyle(arrowStyle: .handDrawn))
        let doc = document([a])
        let canvas = CanvasView(document: doc)
        canvas.select(a.id)
        let handle = ArrowGeometry.bendHandle(from: CGPoint(x: 30, y: 70), to: CGPoint(x: 170, y: 70), bend: a.arrowBend)
        func event(_ type: NSEvent.EventType, at point: CGPoint) throws -> NSEvent {
            try #require(NSEvent.mouseEvent(with: type, location: canvas.convert(point, to: nil), modifierFlags: [],
                timestamp: 0, windowNumber: 0, context: nil, eventNumber: 0, clickCount: 1, pressure: 1))
        }
        // Direct component calls, not events posted to an application or UI automation.
        canvas.mouseDown(with: try event(.leftMouseDown, at: handle))
        canvas.mouseDragged(with: try event(.leftMouseDragged, at: CGPoint(x: 100, y: 105)))
        canvas.mouseUp(with: try event(.leftMouseUp, at: CGPoint(x: 100, y: 105)))
        #expect(doc.annotations[0].kind == a.kind)
        #expect(abs(doc.annotations[0].arrowBend - 0.25) < 0.0001)
        doc.undo()
        #expect(doc.annotations == [a] && !doc.canUndo)
    }

    @Test func defaultArrowStylePersistsAndInvalidValueFallsBack() {
        let suite = "cruxshot.arrow.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        #expect(Preferences(defaults: defaults).lastArrowStyle == .classic)
        Preferences(defaults: defaults).lastArrowStyle = .dashed
        #expect(Preferences(defaults: defaults).lastArrowStyle == .dashed)
        defaults.set("unsupported", forKey: "cruxshot.lastArrowStyle")
        #expect(Preferences(defaults: defaults).lastArrowStyle == .classic)
    }
}

@Suite @MainActor struct ArrowExportTests {
    private func source(scale: Int = 1) -> CGImage {
        makeImage(width: 200 * scale, height: 150 * scale) { _, _ in RGBColor(r: 255, g: 255, b: 255) }
    }
    private func pixels(_ image: CGImage) -> Data { image.dataProvider!.data! as Data }
    private func arrow(_ style: ArrowStyle) -> Annotation {
        Annotation(kind: .arrow(from: CGPoint(x: 25, y: 90), to: CGPoint(x: 170, y: 70)),
                   style: AnnotationStyle(arrowStyle: style))
    }

    @Test func sixStylesProduceDistinctOutputAndHandDrawnIsDeterministic() {
        let image = source()
        let results = ArrowStyle.allCases.map { style in
            pixels(AnnotationRenderer.render(AnnotationDocument(image: image, scale: 1, annotations: [arrow(style)])))
        }
        #expect(Set(results).count == 6)
        let hand = AnnotationDocument(image: image, scale: 1, annotations: [arrow(.handDrawn)])
        #expect(pixels(AnnotationRenderer.render(hand)) == pixels(AnnotationRenderer.render(hand)))
    }

    @Test(arguments: ArrowStyle.allCases)
    func pinAndCaptureExportMatchAtRetinaScale(_ style: ArrowStyle) {
        let image = source(scale: 2), annotations = [arrow(style)]
        let captured = AnnotationRenderer.render(AnnotationDocument(image: image, scale: 2, annotations: annotations))
        var pin = PinItem(image: image, imageScale: 2, frame: .zero, annotations: annotations)
        pin.transform.scale = 2.5
        #expect(pixels(captured) == pixels(pin.composedImage()))
        pin.transform.rotateCW()
        let rotated = pin.composedImage()
        #expect(rotated.width == 300 && rotated.height == 400)
    }

    @Test func dashedShaftHasVisibleStrokesAndGaps() {
        let a = Annotation(kind: .arrow(from: CGPoint(x: 20, y: 70), to: CGPoint(x: 170, y: 70)),
                           style: AnnotationStyle(arrowStyle: .dashed))
        let rendered = AnnotationRenderer.render(AnnotationDocument(image: source(), scale: 1, annotations: [a]))
        let sampler = PixelSampler(image: rendered)
        let row = (25..<145).compactMap { sampler.color(atPixel: $0, 70) }
        #expect(row.contains { $0.r == 255 && $0.g == 255 && $0.b == 255 })
        #expect(row.contains { $0.r > 180 && $0.g < 100 })
    }

    @Test(arguments: ArrowStyle.allCases)
    func selectionBoundsCoverRenderedPixels(_ style: ArrowStyle) {
        let a = arrow(style)
        let image = AnnotationRenderer.render(AnnotationDocument(image: source(), scale: 1, annotations: [a]))
        let sampler = PixelSampler(image: image), bounds = a.bounds.insetBy(dx: -1, dy: -1)
        var count = 0
        for y in 0..<image.height {
            for x in 0..<image.width {
                guard let c = sampler.color(atPixel: x, y), c.g < 240 else { continue }
                count += 1
                #expect(bounds.contains(CGPoint(x: CGFloat(x) + 0.5, y: CGFloat(y) + 0.5)))
            }
        }
        #expect(count > 0)
    }
}

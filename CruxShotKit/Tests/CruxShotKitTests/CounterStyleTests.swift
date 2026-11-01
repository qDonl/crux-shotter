import AppKit
import Testing
@testable import CruxShotKit

@Suite struct CounterGeometryTests {
    @Test func selectedStylesAndAdaptiveBounds() {
        #expect(CounterStyle.allCases == [.preciseRing, .openRing, .baseline])
        #expect(AnnotationStyle().counterStyle == .preciseRing)
        let center = CGPoint(x: 80, y: 70)
        for (number, ringSide, baselineWidth) in [(1, 27.0, 25.0), (12, 35.0, 32.0), (100, 44.0, 42.0)] {
            for style in CounterStyle.allCases {
                let geometry = CounterGeometry(center: center, number: number, style: style)
                let bounds = geometry.bounds
                #expect(bounds.midX == center.x && bounds.midY == center.y)
                #expect(abs(bounds.width - CGFloat(style == .baseline ? baselineWidth : ringSide)) < 0.001)
                #expect(abs(bounds.height - CGFloat(style == .baseline ? 29 : ringSide)) < 0.001)
            }
        }
    }

    @Test func hitAreaFollowsEachStyleAndAllowsSmallMargin() {
        let center = CGPoint(x: 80, y: 70)
        for style in CounterStyle.allCases {
            let a = Annotation(kind: .counter(center: center, number: 12), style: AnnotationStyle(counterStyle: style))
            #expect(AnnotationHitTester.hit(center, in: [a]) == a.id)
            #expect(AnnotationHitTester.hit(CGPoint(x: a.bounds.maxX + 2, y: center.y), in: [a]) == a.id)
            #expect(AnnotationHitTester.hit(CGPoint(x: a.bounds.maxX + 8, y: center.y), in: [a]) == nil)
        }
    }
}

@Suite @MainActor struct CounterStyleIntegrationTests {
    private func source() -> CGImage {
        makeImage(width: 180, height: 140) { x, y in
            (x + y) % 3 == 0 ? RGBColor(r: 45, g: 58, b: 68) : RGBColor(r: 230, g: 221, b: 202)
        }
    }

    @Test func threeVariantsRenderDifferentlyAndMatchPinExport() {
        let image = source()
        let variants = CounterStyle.allCases.map { style -> Data in
            let mark = Annotation(kind: .counter(center: CGPoint(x: 75, y: 70), number: 12),
                                  style: AnnotationStyle(color: .blue, counterStyle: style))
            let captured = AnnotationRenderer.render(AnnotationDocument(image: image, scale: 1, annotations: [mark]))
            let pin = PinItem(image: image, imageScale: 1, frame: .zero, annotations: [mark])
            #expect(captured.dataProvider?.data as Data? == pin.composedImage().dataProvider?.data as Data?)
            return captured.dataProvider!.data! as Data
        }
        #expect(Set(variants).count == 3)
    }

    @Test func changingSelectedStyleOnlyTouchesThatMarkAndIsUndoable() {
        let first = Annotation(kind: .counter(center: CGPoint(x: 40, y: 40), number: 1))
        let second = Annotation(kind: .counter(center: CGPoint(x: 90, y: 40), number: 2))
        let doc = AnnotationDocument(image: source(), scale: 1, annotations: [first, second])
        let canvas = CanvasView(document: doc)
        canvas.select(first.id)
        canvas.applyCounterStyle(.openRing)
        #expect(doc.annotations[0].style.counterStyle == .openRing)
        #expect(doc.annotations[1] == second)
        #expect(canvas.style.counterStyle == .preciseRing)
        doc.undo()
        #expect(doc.annotations == [first, second])
        canvas.applyCounterStyle(.baseline)
        canvas.applyColor(.blue)
        #expect(doc.annotations[0].style.counterStyle == .baseline)
        #expect(doc.annotations[0].style.color == .blue)
        #expect(doc.annotations[1] == second)
    }

    @Test func deletingMiddleNumberRenumbersWithoutChangingOtherStyles() {
        let first = Annotation(kind: .counter(center: CGPoint(x: 30, y: 30), number: 1),
                               style: AnnotationStyle(counterStyle: .preciseRing))
        let middle = Annotation(kind: .counter(center: CGPoint(x: 60, y: 30), number: 2),
                                style: AnnotationStyle(counterStyle: .openRing))
        let last = Annotation(kind: .counter(center: CGPoint(x: 90, y: 30), number: 3),
                              style: AnnotationStyle(counterStyle: .baseline))
        let doc = AnnotationDocument(image: source(), scale: 1, annotations: [first, middle, last])
        doc.remove(id: middle.id)
        #expect(doc.annotations.map(\.counterNumber) == [1, 2])
        #expect(doc.annotations[1].id == last.id && doc.annotations[1].style.counterStyle == .baseline)
        doc.undo()
        #expect(doc.annotations == [first, middle, last])
    }

    @Test func counterToolPlacesAgainWithoutReselectingAndKeepsStyle() throws {
        _ = NSApplication.shared
        let doc = AnnotationDocument(image: source(), scale: 1)
        let canvas = CanvasView(document: doc)
        canvas.tool = .counter
        canvas.applyCounterStyle(.baseline)
        func click(_ point: CGPoint) throws {
            let event = try #require(NSEvent.mouseEvent(with: .leftMouseDown,
                location: canvas.convert(point, to: nil), modifierFlags: [], timestamp: 0,
                windowNumber: 0, context: nil, eventNumber: 0, clickCount: 1, pressure: 1))
            canvas.mouseDown(with: event)
        }
        try click(CGPoint(x: 40, y: 50))
        try click(CGPoint(x: 110, y: 50))
        #expect(doc.annotations.map(\.counterNumber) == [1, 2])
        #expect(doc.annotations.allSatisfy { $0.style.counterStyle == .baseline })
        #expect(canvas.tool == .counter)
        #expect(canvas.selectedID == doc.annotations.last?.id)
        let selected = try #require(doc.annotations.last)
        try click(CGPoint(x: 110, y: 50))
        let drag = try #require(NSEvent.mouseEvent(with: .leftMouseDragged,
            location: canvas.convert(CGPoint(x: 120, y: 60), to: nil), modifierFlags: [], timestamp: 0,
            windowNumber: 0, context: nil, eventNumber: 0, clickCount: 1, pressure: 1))
        let up = try #require(NSEvent.mouseEvent(with: .leftMouseUp,
            location: canvas.convert(CGPoint(x: 120, y: 60), to: nil), modifierFlags: [], timestamp: 0,
            windowNumber: 0, context: nil, eventNumber: 0, clickCount: 1, pressure: 1))
        canvas.mouseDragged(with: drag)
        canvas.mouseUp(with: up)
        #expect(doc.annotations.count == 2)
        #expect(doc.annotations.last?.bounds.midX == selected.bounds.midX + 10)
        #expect(doc.annotations.last?.style.counterStyle == .baseline)
    }

    @Test func pickerRoutesChoiceAndPreferencesPersist() throws {
        _ = NSApplication.shared
        let suite = "cruxshot.counter.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let preferences = Preferences(defaults: defaults)
        #expect(preferences.lastCounterStyle == .preciseRing)
        preferences.lastCounterStyle = .baseline
        #expect(Preferences(defaults: defaults).lastCounterStyle == .baseline)
        defaults.set("unknown", forKey: "cruxshot.lastCounterStyle")
        #expect(Preferences(defaults: defaults).lastCounterStyle == .preciseRing)

        let toolbar = ToolbarView()
        toolbar.update(tool: .counter, color: .red, lineWidth: .medium, mosaicMode: .pixelate,
                       canUndo: false, canRedo: false, counterStyle: .openRing)
        func descendants(_ view: NSView) -> [NSView] {
            view.subviews.flatMap { [$0] + descendants($0) }
        }
        let styleButton = try #require(toolbar.counterStyleChoices[.openRing])
        #expect(!toolbar.propertyBar.isHidden && !styleButton.isHidden)
        #expect(descendants(toolbar.toolRack).contains { $0 === styleButton })
        #expect(toolbar.counterStyleChoices.count == 3)
        #expect(toolbar.counterStyleChoices.filter { $0.value.isActive }.map(\.key) == [.openRing])
        #expect(toolbar.counterStyleChoices.values.allSatisfy { $0.title.isEmpty && $0.toolTip != nil })
        var command: CounterStyle?
        toolbar.onCommand = { if case .counterStyle(let style) = $0 { command = style } }
        toolbar.counterStyleChoices[.baseline]?.performClick(nil)
        #expect(command == .baseline)
        toolbar.update(tool: nil, color: .red, lineWidth: .medium, mosaicMode: .pixelate,
                       canUndo: false, canRedo: false, selectedCounterStyle: .baseline,
                       selectedTool: .counter, hasSelection: true)
        #expect(!toolbar.propertyBar.isHidden)
        #expect(toolbar.counterStyleChoices.filter { $0.value.isActive }.map(\.key) == [.baseline])
    }
}

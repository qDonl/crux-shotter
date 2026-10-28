import Testing
import Foundation
import CoreGraphics
@testable import CruxShotKit

@MainActor
private func doc() -> AnnotationDocument {
    let image = makeImage(width: 200, height: 100) { _, _ in RGBColor(r: 255, g: 255, b: 255) }
    return AnnotationDocument(image: image, scale: 2)
}

private func rect() -> Annotation {
    Annotation(kind: .rect(CGRect(x: 10, y: 10, width: 20, height: 20)))
}

private func counter(_ n: Int) -> Annotation {
    Annotation(kind: .counter(center: CGPoint(x: 5, y: 5), number: n))
}

@MainActor
struct AnnotationDocumentTests {
    @Test func pointSizeUsesScale() {
        #expect(doc().pointSize == CGSize(width: 100, height: 50))
    }

    @Test func addAndUndoRedo() {
        let d = doc(); d.add(rect()); #expect(d.annotations.count == 1)
        d.undo(); #expect(d.annotations.isEmpty && d.canRedo)
        d.redo(); #expect(d.annotations.count == 1)
    }

    @Test func newEditClearsRedo() {
        let d = doc(); d.add(rect()); d.undo(); d.add(rect()); #expect(!d.canRedo)
    }

    @Test func undoOnEmptyIsNoop() {
        let d = doc(); d.undo(); #expect(d.annotations.isEmpty && !d.canUndo)
    }

    @Test func countersIncrement() {
        let d = doc()
        d.add(counter(d.nextCounterNumber)); d.add(counter(d.nextCounterNumber))
        #expect(d.nextCounterNumber == 3)
    }

    @Test func removingCounterRenumbers() {
        let d = doc()
        let a = counter(1), b = counter(2), c = counter(3)
        [a, b, c].forEach(d.add)
        d.remove(id: b.id)
        #expect(d.annotations.compactMap(\.counterNumber) == [1, 2])
        d.undo()
        #expect(d.annotations.compactMap(\.counterNumber) == [1, 2, 3])
    }

    @Test func translateMovesRect() {
        let d = doc(); let r = rect(); d.add(r)
        d.translate(id: r.id, by: CGVector(dx: 5, dy: -5))
        #expect(d.annotations[0].kind == .rect(CGRect(x: 15, y: 5, width: 20, height: 20)))
    }

    @Test func undoStackCappedAt100() {
        let d = doc(); for _ in 0..<150 { d.add(rect()) }
        for _ in 0..<150 { d.undo() }
        #expect(d.annotations.count == 50)
    }

    @Test func updateAppliesTransformAndIsUndoable() {
        let d = doc(); let r = rect(); d.add(r)
        d.update(id: r.id) { $0.style.color = .blue }
        #expect(d.annotations[0].style.color == .blue)
        d.undo(); #expect(d.annotations[0].style.color == .red)
    }

    @Test func boundsCoverGeometry() {
        let arrow = Annotation(kind: .arrow(from: CGPoint(x: 10, y: 20), to: CGPoint(x: 30, y: 5)))
        #expect(arrow.bounds == CGRect(x: 10, y: 5, width: 20, height: 15))
        let pen = Annotation(kind: .pen([CGPoint(x: 1, y: 2), CGPoint(x: 4, y: 8)]))
        #expect(pen.bounds == CGRect(x: 1, y: 2, width: 3, height: 6))
    }
}

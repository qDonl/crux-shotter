import CoreGraphics
import Testing
@testable import CruxShotKit

@Suite struct AnnotationHitTesterTests {
    func ann(_ kind: AnnotationKind) -> Annotation { Annotation(kind: kind) }

    @Test func rectHitsBorderNotInterior() {
        let r = ann(.rect(CGRect(x: 0, y: 0, width: 100, height: 100)))
        #expect(AnnotationHitTester.hit(.init(x: 2, y: 50), in: [r]) == r.id)
        #expect(AnnotationHitTester.hit(.init(x: 50, y: 50), in: [r]) == nil)
    }

    @Test func topmostWins() {
        let a = ann(.mosaic(CGRect(x: 0, y: 0, width: 100, height: 100), .blur))
        let b = ann(.counter(center: .init(x: 50, y: 50), number: 1))
        #expect(AnnotationHitTester.hit(.init(x: 50, y: 50), in: [a, b]) == b.id)
    }

    @Test func arrowHitsNearLine() {
        let a = ann(.arrow(from: .zero, to: .init(x: 100, y: 0)))
        #expect(AnnotationHitTester.hit(.init(x: 50, y: 5), in: [a]) == a.id)
        #expect(AnnotationHitTester.hit(.init(x: 50, y: 20), in: [a]) == nil)
    }

    @Test func mosaicHitsWholeArea() {
        let m = ann(.mosaic(CGRect(x: 0, y: 0, width: 100, height: 100), .pixelate))
        #expect(AnnotationHitTester.hit(.init(x: 50, y: 50), in: [m]) == m.id)
        #expect(AnnotationHitTester.hit(.init(x: 150, y: 50), in: [m]) == nil)
    }

    @Test func penHitsNearSegment() {
        let p = ann(.pen([.zero, .init(x: 50, y: 0), .init(x: 50, y: 50)]))
        #expect(AnnotationHitTester.hit(.init(x: 52, y: 25), in: [p]) == p.id)
        #expect(AnnotationHitTester.hit(.init(x: 20, y: 30), in: [p]) == nil)
    }

    @Test func textHitsBounds() {
        let t = ann(.text(origin: .init(x: 10, y: 10), string: "hello"))
        #expect(AnnotationHitTester.hit(CGPoint(x: t.bounds.midX, y: t.bounds.midY), in: [t]) == t.id)
        #expect(AnnotationHitTester.hit(.init(x: 500, y: 500), in: [t]) == nil)
    }
}

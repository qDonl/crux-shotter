import CoreGraphics
import Testing
@testable import CruxShotKit

@Suite struct AnnotationResizerTests {
    let rect = Annotation(kind: .rect(CGRect(x: 10, y: 10, width: 100, height: 50)))

    func r(_ a: Annotation) -> CGRect {
        if case .rect(let x) = a.kind { return x }
        if case .mosaic(let x, _) = a.kind { return x }
        return .zero
    }

    @Test func cornerResize() {
        let out = AnnotationResizer.resized(rect, handle: .bottomRight, to: .init(x: 150, y: 100))
        #expect(r(out) == CGRect(x: 10, y: 10, width: 140, height: 90))
    }

    @Test func edgeResizeKeepsOtherAxis() {
        let out = AnnotationResizer.resized(rect, handle: .right, to: .init(x: 200, y: 999))
        #expect(r(out) == CGRect(x: 10, y: 10, width: 190, height: 50))
        let top = AnnotationResizer.resized(rect, handle: .top, to: .init(x: 999, y: 0))
        #expect(r(top) == CGRect(x: 10, y: 0, width: 100, height: 60))
    }

    @Test func flipPastOppositeEdgeNormalizes() {
        let out = AnnotationResizer.resized(rect, handle: .left, to: .init(x: 150, y: 0))
        #expect(r(out) == CGRect(x: 110, y: 10, width: 40, height: 50))
    }

    @Test func minimumSize() {
        let out = AnnotationResizer.resized(rect, handle: .right, to: .init(x: 10, y: 0))
        #expect(r(out).width >= 2)
    }

    @Test func arrowEndpointMove() {
        let a = Annotation(kind: .arrow(from: .zero, to: .init(x: 50, y: 50)))
        let out = AnnotationResizer.resized(a, handle: .arrowEnd, to: .init(x: 80, y: 20))
        #expect(out.kind == .arrow(from: .zero, to: .init(x: 80, y: 20)))
        let s = AnnotationResizer.resized(a, handle: .arrowStart, to: .init(x: 5, y: 6))
        #expect(s.kind == .arrow(from: .init(x: 5, y: 6), to: .init(x: 50, y: 50)))
    }

    @Test func handleCounts() {
        #expect(AnnotationResizer.handles(for: rect).count == 8)
        let m = Annotation(kind: .mosaic(CGRect(x: 0, y: 0, width: 10, height: 10), .blur))
        #expect(AnnotationResizer.handles(for: m).count == 8)
        let a = Annotation(kind: .arrow(from: .zero, to: .init(x: 5, y: 5)))
        #expect(AnnotationResizer.handles(for: a).map(\.0) == [.arrowStart, .arrowEnd])
        #expect(AnnotationResizer.handles(for: Annotation(kind: .pen([.zero, .init(x: 1, y: 1)]))).isEmpty)
        #expect(AnnotationResizer.handles(for: Annotation(kind: .text(origin: .zero, string: "a"))).isEmpty)
        #expect(AnnotationResizer.handles(for: Annotation(kind: .counter(center: .zero, number: 1))).isEmpty)
    }

    @Test func handleHitAndMiss() {
        #expect(AnnotationResizer.handle(at: .init(x: 112, y: 12), for: rect) == .topRight)
        #expect(AnnotationResizer.handle(at: .init(x: 60, y: 10), for: rect) == .top)
        #expect(AnnotationResizer.handle(at: .init(x: 60, y: 35), for: rect) == nil)
    }
}

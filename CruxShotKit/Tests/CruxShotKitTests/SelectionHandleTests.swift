import CoreGraphics
import Testing
@testable import CruxShotKit

@Suite struct SelectionHandleTests {
    let r = CGRect(x: 100, y: 100, width: 200, height: 100)

    @Test func handlesMatchOnBothSidesWithoutInnerEdges() {
        #expect(SelectionHandle.hit(CGPoint(x: 104, y: 196), in: r, innerEdges: false) == .topLeft)
        #expect(SelectionHandle.hit(CGPoint(x: 96, y: 204), in: r, innerEdges: false) == .topLeft)
        #expect(SelectionHandle.hit(CGPoint(x: 200, y: 105), in: r, innerEdges: false) == .bottom)
    }

    @Test func innerEdgeStripOnlyWhenAllowed() {
        let inside = CGPoint(x: 150, y: 197)   // 3pt inside the top edge, away from handles
        let outside = CGPoint(x: 150, y: 203)  // 3pt outside
        #expect(SelectionHandle.hit(inside, in: r) == .top)
        #expect(SelectionHandle.hit(inside, in: r, innerEdges: false) == nil)
        #expect(SelectionHandle.hit(outside, in: r, innerEdges: false) == .top)
        #expect(SelectionHandle.hit(CGPoint(x: 150, y: 150), in: r) == nil)
    }
}

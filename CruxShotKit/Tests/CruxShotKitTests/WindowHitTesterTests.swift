import CoreGraphics
import Testing
@testable import CruxShotKit

@Suite struct WindowHitTesterTests {
    let back  = WindowInfo(windowID: 1, frame: CGRect(x: 0, y: 0, width: 500, height: 500), title: nil, appName: "A", zIndex: 1)
    let front = WindowInfo(windowID: 2, frame: CGRect(x: 100, y: 100, width: 100, height: 100), title: nil, appName: "B", zIndex: 0)

    @Test func frontmostWins() { #expect(WindowHitTester.window(at: CGPoint(x: 150, y: 150), in: [back, front]) == front) }
    @Test func fallsThroughToBack() { #expect(WindowHitTester.window(at: CGPoint(x: 10, y: 10), in: [back, front]) == back) }
    @Test func nothingOutside() { #expect(WindowHitTester.window(at: CGPoint(x: 900, y: 900), in: [back, front]) == nil) }
}

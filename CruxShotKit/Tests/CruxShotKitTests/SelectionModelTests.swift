import CoreGraphics
import Testing
@testable import CruxShotKit

@Suite struct SelectionModelTests {
    let bounds = CGRect(x: -1920, y: 0, width: 3360, height: 1080)
    let win = WindowInfo(windowID: 1, frame: CGRect(x: 0, y: 0, width: 200, height: 200), title: nil, appName: "A", zIndex: 0)

    func adjusting(_ rect: CGRect) -> SelectionModel {
        var m = SelectionModel(bounds: bounds)
        m.commit(rect)
        return m
    }

    @Test func dragCreatesRect() {
        var m = SelectionModel(bounds: bounds)
        m.mouseDown(at: .init(x: 10, y: 10)); m.mouseDragged(to: .init(x: 110, y: 60)); m.mouseUp(at: .init(x: 110, y: 60))
        #expect(m.rect == CGRect(x: 10, y: 10, width: 100, height: 50) && m.phase == .adjusting)
    }
    @Test func dragUpLeftNormalizes() {
        var m = SelectionModel(bounds: bounds)
        m.mouseDown(at: .init(x: 110, y: 60)); m.mouseDragged(to: .init(x: 10, y: 10))
        #expect(m.rect == CGRect(x: 10, y: 10, width: 100, height: 50) && m.phase == .selecting)
    }
    @Test func tinyDragIsTreatedAsClick() {
        var m = SelectionModel(bounds: bounds); m.hover(at: .init(x: 50, y: 50), windows: [win])
        m.mouseDown(at: .init(x: 50, y: 50)); m.mouseUp(at: .init(x: 52, y: 51))
        #expect(m.rect == win.frame && m.phase == .adjusting)
    }
    @Test func clickWithoutWindowKeepsSelectingPhase() {
        var m = SelectionModel(bounds: bounds); m.hover(at: .init(x: 5, y: 5), windows: [])
        m.mouseDown(at: .init(x: 5, y: 5)); m.mouseUp(at: .init(x: 5, y: 5))
        #expect(m.rect == nil && m.phase == .selecting)
    }
    @Test func clickWindowOutsideBoundsStaysSelecting() {
        var m = SelectionModel(bounds: CGRect(x: 500, y: 500, width: 100, height: 100))
        m.hover(at: .init(x: 50, y: 50), windows: [win])
        m.mouseDown(at: .init(x: 50, y: 50)); m.mouseUp(at: .init(x: 50, y: 50))
        #expect(m.rect == nil && m.phase == .selecting)
    }
    @Test func hoverIgnoredWhenAdjusting() {
        var m = adjusting(CGRect(x: 300, y: 300, width: 50, height: 50))
        m.hover(at: .init(x: 50, y: 50), windows: [win])
        #expect(m.hoveredWindow == nil)
    }
    @Test func mouseEventsNoOpWhenAdjusting() {
        var m = adjusting(CGRect(x: 300, y: 300, width: 50, height: 50))
        m.mouseDown(at: .init(x: 0, y: 0)); m.mouseDragged(to: .init(x: 90, y: 90)); m.mouseUp(at: .init(x: 90, y: 90))
        #expect(m.rect == CGRect(x: 300, y: 300, width: 50, height: 50))
    }
    @Test func selectionClampedToUnionOfDisplays() {
        var m = SelectionModel(bounds: bounds)
        m.mouseDown(at: .init(x: -2000, y: 10)); m.mouseDragged(to: .init(x: -1800, y: 50)); m.mouseUp(at: .init(x: -1800, y: 50))
        #expect(m.rect?.minX == -1920)
    }
    @Test func nudgeOnRetinaMovesHalfPoint() {
        var m = adjusting(CGRect(x: 10, y: 10, width: 10, height: 10))
        m.nudge(dx: 1, dy: 0, pixelScale: 2); #expect(m.rect?.minX == 10.5)
    }
    @Test func nudgeStaysInBounds() {
        var m = adjusting(CGRect(x: -1920, y: 0, width: 10, height: 10))
        m.nudge(dx: -10, dy: -10, pixelScale: 1)
        #expect(m.rect == CGRect(x: -1920, y: 0, width: 10, height: 10))
    }
    @Test func nudgeWithoutRectIsNoOp() {
        var m = SelectionModel(bounds: bounds); m.nudge(dx: 1, dy: 1, pixelScale: 1); #expect(m.rect == nil)
    }
    @Test func resizeNeverBelowOnePixel() {
        var m = adjusting(CGRect(x: 0, y: 0, width: 1, height: 1))
        m.resize(dw: -5, dh: -5, pixelScale: 1); #expect(m.rect?.size == CGSize(width: 1, height: 1))
    }
    @Test func resizeGrowsAndClamps() {
        var m = adjusting(CGRect(x: 0, y: 0, width: 10, height: 10))
        m.resize(dw: 4, dh: 2, pixelScale: 2); #expect(m.rect?.size == CGSize(width: 12, height: 11))
    }
    @Test func setRectClamps() {
        var m = adjusting(CGRect(x: 0, y: 0, width: 10, height: 10))
        m.setRect(CGRect(x: -2000, y: -5, width: 100, height: 100))
        #expect(m.rect == CGRect(x: -1920, y: 0, width: 20, height: 95))
    }
}

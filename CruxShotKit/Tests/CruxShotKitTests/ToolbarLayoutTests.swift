import CoreGraphics
import Testing
@testable import CruxShotKit

@Suite struct ToolbarLayoutTests {
    private let tools = CGSize(width: 44, height: 253)
    private let actions = CGSize(width: 340, height: 80)

    @Test func keepsControlsOutsideAnOrdinarySelection() {
        let selection = CGRect(x: 200, y: 200, width: 500, height: 320)
        let layout = ToolbarLayout(selection: selection, available: CGRect(x: 0, y: 0, width: 1000, height: 800),
                                   toolSize: tools, actionSize: actions)
        #expect(layout.tools.maxX < selection.minX)
        #expect(layout.actions.maxY < selection.minY)
        #expect(!layout.tools.intersects(layout.actions))
    }

    @Test func screenEdgesSmallCropsAndFullScreenRemainUsable() {
        for screen in [CGRect(x: 0, y: 0, width: 800, height: 600),
                       CGRect(x: -1440, y: 120, width: 1440, height: 900)] {
            let selections = [
                CGRect(x: screen.minX, y: screen.minY, width: 1, height: 1),
                CGRect(x: screen.maxX - 2, y: screen.maxY - 2, width: 2, height: 2),
                CGRect(x: screen.minX, y: screen.maxY - 30, width: 30, height: 30),
                CGRect(x: screen.maxX - 30, y: screen.minY, width: 30, height: 30),
                screen,
            ]
            for selection in selections {
                let layout = ToolbarLayout(selection: selection, available: screen, toolSize: tools, actionSize: actions)
                #expect(screen.contains(layout.tools))
                #expect(screen.contains(layout.actions))
                #expect(!layout.tools.intersects(layout.actions))
            }
        }
    }
}

import Testing
import CoreGraphics
@testable import CruxShotKit

@Test func cgToAppKitFlipsY() {
    #expect(Geometry.appKitRect(fromCG: CGRect(x: 10, y: 20, width: 100, height: 50),
                                primaryScreenHeight: 900) == CGRect(x: 10, y: 830, width: 100, height: 50))
}
@Test func pixelRectOnRetinaPrimary() {
    let d = DisplayInfo(displayID: 1, frame: CGRect(x: 0, y: 0, width: 1440, height: 900), scale: 2)
    #expect(Geometry.pixelRect(for: CGRect(x: 100, y: 100, width: 200, height: 50), on: d)
            == CGRect(x: 200, y: 1500, width: 400, height: 100))
}
@Test func pixelRectOnNegativeOriginDisplay() {
    let d = DisplayInfo(displayID: 2, frame: CGRect(x: 1440, y: -200, width: 1920, height: 1080), scale: 1)
    #expect(Geometry.pixelRect(for: CGRect(x: 1540, y: 0, width: 100, height: 100), on: d)
            == CGRect(x: 100, y: 780, width: 100, height: 100))
}
@Test func pixelRectRoundsOutwardAndClips() {
    let d = DisplayInfo(displayID: 1, frame: CGRect(x: 0, y: 0, width: 100, height: 100), scale: 2)
    #expect(Geometry.pixelRect(for: CGRect(x: 10.3, y: 10.3, width: 5.2, height: 5.2), on: d)
            == CGRect(x: 20, y: 169, width: 11, height: 11))
    #expect(Geometry.pixelRect(for: CGRect(x: -10, y: 90, width: 30, height: 30), on: d)
            == CGRect(x: 0, y: 0, width: 40, height: 20))
}
@Test func globalToImagePoint() {
    #expect(Geometry.imagePoint(fromGlobal: CGPoint(x: 150, y: 400),
                                imageOriginGlobal: CGRect(x: 100, y: 300, width: 200, height: 200))
            == CGPoint(x: 50, y: 100))
}

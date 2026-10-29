import Testing
@testable import CruxShotKit

@Suite struct ColorLiteralTests {
    private func c(_ r: UInt8, _ g: UInt8, _ b: UInt8, _ a: Double = 1) -> ColorLiteral {
        ColorLiteral(rgb: RGBColor(r: r, g: g, b: b), alpha: a)
    }

    @Test func hexForms() {
        #expect(ColorLiteral.parse("#FF6A00") == c(255, 106, 0))
        #expect(ColorLiteral.parse("  #ff6a00\n") == c(255, 106, 0))
        #expect(ColorLiteral.parse("#F60") == c(255, 102, 0))
        #expect(ColorLiteral.parse("#FF6A0080") == c(255, 106, 0, 128.0 / 255))
        #expect(ColorLiteral.parse("#F608") == c(255, 102, 0, 136.0 / 255))
    }

    @Test func rgbForms() {
        #expect(ColorLiteral.parse("rgb(255, 106, 0)") == c(255, 106, 0))
        #expect(ColorLiteral.parse("RGB(255,106,0)") == c(255, 106, 0))
        #expect(ColorLiteral.parse("rgba(255, 106, 0, 0.5)") == c(255, 106, 0, 0.5))
        #expect(ColorLiteral.parse("rgb(255 106 0 / 50%)") == c(255, 106, 0, 0.5))
        #expect(ColorLiteral.parse("rgb(100%, 0%, 0%)") == c(255, 0, 0))
    }

    @Test func hslForms() {
        #expect(ColorLiteral.parse("hsl(0, 100%, 50%)") == c(255, 0, 0))
        #expect(ColorLiteral.parse("hsl(120deg 100% 25%)") == c(0, 128, 0))
        #expect(ColorLiteral.parse("hsla(240, 100%, 50%, 0.25)") == c(0, 0, 255, 0.25))
    }

    @Test func rejectsNonColors() {
        for s in ["FF6A00", "#GG0000", "#12345", "rgb(1, 2)", "rgb(300, 0, 0)", "rgba(0, 0, 0, 2)",
                  "hello #FF0000", "#FF0000 is red", "cmyk(0, 0, 0, 0)", "", "rgb()"] {
            #expect(ColorLiteral.parse(s) == nil, "\(s)")
        }
    }

    @Test func strings() {
        #expect(c(255, 106, 0).hexString == "#FF6A00")
        #expect(c(255, 106, 0).rgbString == "rgb(255, 106, 0)")
        #expect(c(255, 106, 0, 0.5).hexString == "#FF6A0080")
        #expect(c(255, 106, 0, 0.5).rgbString == "rgba(255, 106, 0, 0.5)")
        #expect(c(0, 0, 0, 1.0 / 3).rgbString == "rgba(0, 0, 0, 0.33)")
    }
}

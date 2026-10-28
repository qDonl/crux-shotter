import Testing
@testable import CruxShotKit

@Suite struct TextCardRendererTests {
    @Test func truncatesTo80Lines() {
        let tall = TextCardRenderer.render((1...10_000).map(String.init).joined(separator: "\n"), dark: false, scale: 1)
        let eighty = TextCardRenderer.render((1...81).map(String.init).joined(separator: "\n"), dark: false, scale: 1)
        #expect(tall.height == eighty.height)
        let exact = TextCardRenderer.render((1...80).map(String.init).joined(separator: "\n"), dark: false, scale: 1)
        #expect(exact.height < eighty.height)
    }
    @Test func truncatesLongLines() {
        let a = TextCardRenderer.render(String(repeating: "x", count: 5_000), dark: false, scale: 1)
        let b = TextCardRenderer.render(String(repeating: "x", count: 301), dark: false, scale: 1)
        #expect(a.width == b.width)
    }
    @Test func scaleMultipliesPixels() {
        let a = TextCardRenderer.render("hello", dark: true, scale: 1)
        let b = TextCardRenderer.render("hello", dark: true, scale: 2)
        #expect(abs(b.width - 2 * a.width) <= 1 && abs(b.height - 2 * a.height) <= 1)
    }
    @Test func tabsExpand() {
        let a = TextCardRenderer.render("\tx", dark: false, scale: 1)
        let b = TextCardRenderer.render("    x", dark: false, scale: 1)
        #expect(a.width == b.width)
    }
    @Test func emptyTextStillRenders() {
        let a = TextCardRenderer.render("", dark: false, scale: 1)
        #expect(a.width > 0 && a.height > 0)
    }
}

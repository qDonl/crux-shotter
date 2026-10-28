import CoreGraphics
import Foundation
import Testing
@testable import CruxShotKit

@MainActor
final class FakePresenter: PinPresenting {
    var shown: [PinItem.ID] = []
    var updated: [PinItem.ID] = []
    var closed: [PinItem.ID] = []
    var hidden: Bool?
    func show(_ item: PinItem) { shown.append(item.id) }
    func update(_ item: PinItem) { updated.append(item.id) }
    func close(id: PinItem.ID) { closed.append(id) }
    func setHidden(_ hidden: Bool) { self.hidden = hidden }
}

@MainActor
private func item() -> PinItem {
    PinItem(image: makeImage(width: 2, height: 2) { _, _ in RGBColor(r: 1, g: 2, b: 3) }, imageScale: 2, frame: CGRect(x: 0, y: 0, width: 1, height: 1))
}

@MainActor @Suite struct PinManagerTests {
    @Test func restoreLastClosed() {
        let p = FakePresenter(); let m = PinManager(presenter: p); let a = item(), b = item()
        m.add(a); m.add(b); m.close(id: a.id)
        #expect(p.closed == [a.id])
        #expect(m.canRestore)
        #expect(m.restoreLast() && m.items.map(\.id).contains(a.id))
        #expect(p.shown.filter { $0 == a.id }.count == 2)
        #expect(!m.canRestore)
    }
    @Test func closedStackCappedAt10() {
        let m = PinManager(presenter: FakePresenter())
        for _ in 0..<12 { let i = item(); m.add(i); m.close(id: i.id) }
        var n = 0; while m.restoreLast() { n += 1 }; #expect(n == 10)
    }
    @Test func closeAllPushesInOrder() {
        let m = PinManager(presenter: FakePresenter()); let a = item(), b = item()
        m.add(a); m.add(b); m.closeAll()
        #expect(m.items.isEmpty)
        #expect(m.restoreLast()); #expect(m.items.first?.id == b.id)
    }
    @Test func showingResetsClickThrough() {
        let p = FakePresenter(), m = PinManager(presenter: p)
        var i = item(); i.clickThrough = true; m.add(i)
        m.toggleHidden(); #expect(m.isHidden && p.hidden == true)
        m.toggleHidden()
        #expect(m.items.allSatisfy { !$0.clickThrough } && p.hidden == false)
        #expect(p.updated.contains(i.id))
    }
    @Test func addWhileHiddenUnhides() {
        let p = FakePresenter(), m = PinManager(presenter: p)
        m.add(item()); m.toggleHidden(); m.add(item())
        #expect(!m.isHidden && p.hidden == false)
    }
    @Test func updateAndUnknownIds() {
        let p = FakePresenter(), m = PinManager(presenter: p)
        var i = item(); m.add(i); i.clickThrough = true; m.update(i)
        #expect(m.items[0].clickThrough && p.updated == [i.id])
        m.update(item()); m.close(id: UUID())
        #expect(m.items.count == 1 && p.closed.isEmpty && !m.canRestore)
    }
}

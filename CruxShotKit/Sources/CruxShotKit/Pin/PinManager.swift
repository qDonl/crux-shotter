import Foundation
import Combine

@MainActor
public protocol PinPresenting: AnyObject {
    func show(_ item: PinItem)
    func update(_ item: PinItem)
    func close(id: PinItem.ID)
    func setHidden(_ hidden: Bool)
}

@MainActor
public final class PinManager: ObservableObject {
    static let closedLimit = 10

    private let presenter: PinPresenting
    @Published public private(set) var items: [PinItem] = []
    public private(set) var isHidden = false
    private var closed: [PinItem] = []

    public init(presenter: PinPresenting) { self.presenter = presenter }

    public var canRestore: Bool { !closed.isEmpty }

    public func add(_ item: PinItem) {
        if isHidden { showAll() }
        items.append(item)
        presenter.show(item)
    }

    public func update(_ item: PinItem) {
        guard let i = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[i] = item
        presenter.update(item)
    }

    public func close(id: PinItem.ID) {
        guard let i = items.firstIndex(where: { $0.id == id }) else { return }
        let item = items.remove(at: i)
        presenter.close(id: id)
        pushClosed(item)
    }

    public func closeAll() {
        let all = items
        items = []
        for item in all {
            presenter.close(id: item.id)
            pushClosed(item)
        }
    }

    public func toggleHidden() {
        if isHidden { showAll() } else {
            isHidden = true
            presenter.setHidden(true)
        }
    }

    @discardableResult
    public func restoreLast() -> Bool {
        guard let item = closed.popLast() else { return false }
        add(item)
        return true
    }

    private func showAll() {
        isHidden = false
        presenter.setHidden(false)
        for i in items.indices where items[i].clickThrough {
            items[i].clickThrough = false
            presenter.update(items[i])
        }
    }

    private func pushClosed(_ item: PinItem) {
        closed.append(item)
        if closed.count > Self.closedLimit { closed.removeFirst(closed.count - Self.closedLimit) }
    }
}

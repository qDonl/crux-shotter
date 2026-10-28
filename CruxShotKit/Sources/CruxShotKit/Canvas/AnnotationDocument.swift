import Foundation
import CoreGraphics
import Combine

@MainActor
public final class AnnotationDocument: ObservableObject {
    public static let maxUndoDepth = 100

    public let image: CGImage
    public let scale: CGFloat
    @Published public private(set) var annotations: [Annotation] = []

    private var undoStack: [[Annotation]] = []
    private var redoStack: [[Annotation]] = []

    public init(image: CGImage, scale: CGFloat) {
        self.image = image
        self.scale = scale
    }

    public var pointSize: CGSize {
        CGSize(width: CGFloat(image.width) / scale, height: CGFloat(image.height) / scale)
    }

    public var canUndo: Bool { !undoStack.isEmpty }
    public var canRedo: Bool { !redoStack.isEmpty }

    public var nextCounterNumber: Int {
        (annotations.compactMap(\.counterNumber).max() ?? 0) + 1
    }

    public func add(_ annotation: Annotation) {
        mutate { $0.append(annotation) }
    }

    public func remove(id: Annotation.ID) {
        guard annotations.contains(where: { $0.id == id }) else { return }
        mutate { list in
            list.removeAll { $0.id == id }
            var n = 0
            for i in list.indices {
                if case .counter(let c, _) = list[i].kind {
                    n += 1
                    list[i].kind = .counter(center: c, number: n)
                }
            }
        }
    }

    public func update(id: Annotation.ID, _ transform: (inout Annotation) -> Void) {
        guard let idx = annotations.firstIndex(where: { $0.id == id }) else { return }
        mutate { transform(&$0[idx]) }
    }

    public func translate(id: Annotation.ID, by v: CGVector) {
        update(id: id) { $0 = $0.translated(by: v) }
    }

    public func undo() {
        guard let prev = undoStack.popLast() else { return }
        redoStack.append(annotations)
        annotations = prev
    }

    public func redo() {
        guard let next = redoStack.popLast() else { return }
        undoStack.append(annotations)
        annotations = next
    }

    private func mutate(_ body: (inout [Annotation]) -> Void) {
        undoStack.append(annotations)
        if undoStack.count > Self.maxUndoDepth { undoStack.removeFirst() }
        redoStack.removeAll()
        var copy = annotations
        body(&copy)
        annotations = copy
    }
}

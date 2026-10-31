import Foundation
import CoreGraphics
import Combine

@MainActor
public final class AnnotationDocument: ObservableObject {
    public static let maxUndoDepth = 100

    @Published public private(set) var image: CGImage
    public private(set) var scale: CGFloat
    /// Actual pixel-snapped capture rectangle in AppKit global coordinates, when editing a capture.
    public private(set) var captureFrame: CGRect?
    @Published public private(set) var annotations: [Annotation] = []

    private struct State {
        let image: CGImage
        let scale: CGFloat
        let captureFrame: CGRect?
        let annotations: [Annotation]
    }
    private var undoStack: [State] = []
    private var redoStack: [State] = []
    private var state: State { State(image: image, scale: scale, captureFrame: captureFrame, annotations: annotations) }

    /// `annotations` are the starting content (not undoable), e.g. when re-editing a pin.
    public init(image: CGImage, scale: CGFloat, annotations: [Annotation] = [], captureFrame: CGRect? = nil) {
        self.image = image
        self.scale = scale
        self.annotations = annotations
        self.captureFrame = captureFrame
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

    /// Re-crop the original frozen snapshot. Marks keep their global position, even when temporarily
    /// outside the new crop; widening the selection later reveals them again. One call = one undo.
    @discardableResult
    public func reframe(image: CGImage, scale: CGFloat, frame: CGRect) -> Bool {
        guard let previous = captureFrame, scale.isFinite, scale > 0,
              frame.minX.isFinite, frame.minY.isFinite, frame.width.isFinite, frame.height.isFinite,
              frame.width > 0, frame.height > 0,
              abs(frame.width * scale - CGFloat(image.width)) < 0.001,
              abs(frame.height * scale - CGFloat(image.height)) < 0.001,
              previous != frame || self.scale != scale else { return false }
        recordEdit()
        let delta = CGVector(dx: previous.minX - frame.minX, dy: frame.maxY - previous.maxY)
        let translated = annotations.map { $0.translated(by: delta) }
        restore(State(image: image, scale: scale, captureFrame: frame, annotations: translated))
        return true
    }

    public func undo() {
        guard let prev = undoStack.popLast() else { return }
        redoStack.append(state)
        restore(prev)
    }

    public func redo() {
        guard let next = redoStack.popLast() else { return }
        undoStack.append(state)
        restore(next)
    }

    private func restore(_ state: State) {
        image = state.image
        scale = state.scale
        captureFrame = state.captureFrame
        annotations = state.annotations
    }

    private func recordEdit() {
        undoStack.append(state)
        if undoStack.count > Self.maxUndoDepth { undoStack.removeFirst() }
        redoStack.removeAll()
    }

    private func mutate(_ body: (inout [Annotation]) -> Void) {
        recordEdit()
        var copy = annotations
        body(&copy)
        annotations = copy
    }
}

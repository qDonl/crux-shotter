import AppKit

/// In-place annotation editing on a pin: a `CanvasView` over the pin view plus a compact
/// toolbar (drawing tools, undo/redo, done) in a child panel under the pin window.
@MainActor
final class PinEditor {
    static let toolbarGap: CGFloat = 8

    let document: AnnotationDocument
    private let canvas: CanvasView
    private let toolbar = ToolbarView(variant: .pinEdit)
    private let toolbarPanel: NSPanel
    private weak var host: PinView?
    private let preferences: Preferences
    var onDone: (() -> Void)?

    private static let toolKeys: [String: CanvasTool] = [
        "r": .rect, "a": .arrow, "p": .pen, "t": .text, "n": .counter, "m": .mosaic,
    ]

    init(item: PinItem, host: PinView, preferences: Preferences = .shared) {
        self.host = host
        self.preferences = preferences
        document = AnnotationDocument(image: item.image, scale: item.imageScale, annotations: item.annotations)
        canvas = CanvasView(document: document)
        toolbarPanel = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel],
                               backing: .buffered, defer: false)
        toolbarPanel.isOpaque = false
        toolbarPanel.backgroundColor = .clear
        toolbarPanel.hasShadow = true
        toolbarPanel.hidesOnDeactivate = false
        toolbarPanel.isReleasedWhenClosed = false
        toolbarPanel.level = .floating
        toolbarPanel.contentView = toolbar

        canvas.style = currentStyle
        canvas.mosaicMode = preferences.mosaicMode
        canvas.tool = .rect
        canvas.onChange = { [weak self] in self?.updateToolbar() }
        toolbar.onCommand = { [weak self] in self?.handle($0) }
        host.addSubview(canvas)
        if let window = host.window {
            window.addChildWindow(toolbarPanel, ordered: .above)
            window.makeKey()
            window.makeFirstResponder(canvas)
        }
        layout()
        updateToolbar()
    }

    /// Fits the canvas to the (possibly zoomed) host and places the toolbar under the window.
    func layout() {
        guard let host else { return }
        canvas.frame = host.bounds
        canvas.bounds = CGRect(origin: .zero, size: document.pointSize)
        canvas.needsDisplay = true
        guard let parent = host.window else { return }
        let size = toolbar.fittingSize
        let pf = parent.frame
        let vf = (parent.screen ?? NSScreen.main)?.visibleFrame ?? pf
        let x = min(max(pf.maxX - size.width, vf.minX), vf.maxX - size.width)
        var y = pf.minY - Self.toolbarGap - size.height
        if y < vf.minY { y = min(pf.maxY + Self.toolbarGap, vf.maxY - size.height) }
        toolbarPanel.setFrame(CGRect(origin: CGPoint(x: x, y: y), size: size), display: true)
    }

    /// Commits pending text and removes the editing UI. Returns the final annotations.
    func finish() -> [Annotation] {
        canvas.commitTextEditing()
        let result = document.annotations
        canvas.removeFromSuperview()
        toolbarPanel.parent?.removeChildWindow(toolbarPanel)
        toolbarPanel.orderOut(nil)
        if let host { host.window?.makeFirstResponder(host) }
        return result
    }

    /// Keys that reach the pin view while editing (the canvas handles Delete and deselect).
    func handleKey(_ event: NSEvent) -> Bool {
        let mods = event.modifierFlags.intersection([.command, .shift, .option, .control])
        let ch = event.charactersIgnoringModifiers?.lowercased()
        switch (event.keyCode, mods, ch) {
        case (53, _, _), (36, [], _), (76, [], _):
            onDone?()
        case (_, .command, "z"):
            document.undo(); updateToolbar()
        case (_, [.command, .shift], "z"):
            document.redo(); updateToolbar()
        case (_, [], let c?) where Self.toolKeys[c] != nil:
            let tool = Self.toolKeys[c]!
            canvas.tool = canvas.tool == tool ? nil : tool
            updateToolbar()
        default:
            return false
        }
        return true
    }

    private var currentStyle: AnnotationStyle {
        AnnotationStyle(color: preferences.lastColor, lineWidth: preferences.lastLineWidth)
    }

    private func handle(_ command: ToolbarCommand) {
        switch command {
        case .action(.undo): document.undo()
        case .action(.redo): document.redo()
        case .action: break
        case .toggleTool(let tool): canvas.tool = canvas.tool == tool ? nil : tool
        case .color(let color):
            preferences.lastColor = color
            canvas.applyStyle(currentStyle)
        case .lineWidth(let width):
            preferences.lastLineWidth = width
            canvas.applyStyle(currentStyle)
        case .mosaicMode(let mode):
            preferences.mosaicMode = mode
            canvas.mosaicMode = mode
        case .done:
            onDone?()
            return
        }
        updateToolbar()
    }

    private func updateToolbar() {
        toolbar.update(tool: canvas.tool, color: preferences.lastColor, lineWidth: preferences.lastLineWidth,
                       mosaicMode: preferences.mosaicMode, canUndo: document.canUndo, canRedo: document.canRedo)
        layout()
        canvas.needsDisplay = true
    }
}

import AppKit

/// How an editing session ends. `.discard` restores the annotations from before editing;
/// the others keep the changes, and copy/save/OCR then act on the result.
enum PinEditExit { case keep, discard, copy, save, ocr }

/// In-place annotation editing on a pin: a `CanvasView` over the pin view plus the capture
/// split tool rack and output bar in child panels beside and below the pin window.
@MainActor
final class PinEditor {
    let document: AnnotationDocument
    private let canvas: CanvasView
    private let toolbar = ToolbarView(variant: .pinEdit)
    private let toolbarPanel: NSPanel
    private let toolPanel: NSPanel
    private weak var host: PinView?
    private let preferences: Preferences
    var onExit: ((PinEditExit) -> Void)?

    init(item: PinItem, host: PinView, preferences: Preferences = .shared) {
        self.host = host
        self.preferences = preferences
        document = AnnotationDocument(image: item.image, scale: item.imageScale, annotations: item.annotations)
        canvas = CanvasView(document: document)
        toolbarPanel = Self.panel(content: toolbar)
        toolPanel = Self.panel(content: toolbar.toolRack)

        canvas.style = currentStyle
        canvas.mosaicMode = preferences.mosaicMode
        canvas.tool = .rect
        canvas.onChange = { [weak self] in self?.updateToolbar() }
        toolbar.onCommand = { [weak self] in self?.handle($0) }
        host.addSubview(canvas)
        if let window = host.window {
            window.addChildWindow(toolbarPanel, ordered: .above)
            window.addChildWindow(toolPanel, ordered: .above)
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
        let available = (parent.screen ?? NSScreen.main)?.visibleFrame ?? parent.frame
        let placement = ToolbarLayout(selection: parent.frame, available: available,
                                      toolSize: toolbar.toolRack.fittingSize, actionSize: toolbar.fittingSize)
        toolbarPanel.setFrame(placement.actions, display: true)
        toolPanel.setFrame(placement.tools, display: true)
    }

    /// Commits pending text and removes the editing UI. Returns the final annotations.
    func finish() -> [Annotation] {
        canvas.commitTextEditing()
        let result = document.annotations
        canvas.removeFromSuperview()
        for panel in [toolbarPanel, toolPanel] {
            panel.parent?.removeChildWindow(panel)
            panel.orderOut(nil)
        }
        if let host { host.window?.makeFirstResponder(host) }
        return result
    }

    /// Keys that reach the pin view while editing (the canvas handles Delete and deselect).
    func handleKey(_ event: NSEvent) -> Bool {
        guard let action = PinEditKeyMap.action(characters: event.charactersIgnoringModifiers,
                                                keyCode: event.keyCode, modifiers: event.modifierFlags)
        else { return false }
        switch action {
        case .done: onExit?(.keep)
        case .cancel: onExit?(.discard)
        case .select: canvas.tool = nil; updateToolbar()
        case .copy: onExit?(.copy)
        case .save: onExit?(.save)
        case .ocr: onExit?(.ocr)
        case .undo: document.undo(); updateToolbar()
        case .redo: document.redo(); updateToolbar()
        case .toggleTool(let tool):
            canvas.tool = canvas.tool == tool ? nil : tool
            updateToolbar()
        }
        return true
    }

    private static func panel(content: NSView) -> NSPanel {
        let panel = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel],
                            backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.level = .floating
        panel.contentView = content
        return panel
    }

    private var currentStyle: AnnotationStyle {
        AnnotationStyle(color: preferences.lastColor, lineWidth: preferences.lastLineWidth, arrowStyle: preferences.lastArrowStyle)
    }

    private func handle(_ command: ToolbarCommand) {
        switch command {
        case .action(.undo): canvas.commitTextEditing(); document.undo()
        case .action(.redo): canvas.commitTextEditing(); document.redo()
        case .action(.copy): onExit?(.copy); return
        case .action(.save): onExit?(.save); return
        case .action(.ocr): onExit?(.ocr); return
        case .action: break
        case .select: canvas.tool = nil
        case .toggleTool(let tool): canvas.tool = canvas.tool == tool ? nil : tool
        case .color(let color):
            preferences.lastColor = color
            canvas.applyColor(color)
        case .lineWidth(let width):
            preferences.lastLineWidth = width
            canvas.applyLineWidth(width)
        case .arrowStyle(let style):
            preferences.lastArrowStyle = style
            canvas.applyArrowStyle(style)
        case .mosaicMode(let mode):
            preferences.mosaicMode = mode
            canvas.mosaicMode = mode
        case .discard:
            onExit?(.discard)
            return
        case .done:
            onExit?(.keep)
            return
        }
        updateToolbar()
    }

    private func updateToolbar() {
        let selectedStyle = canvas.selectedAnnotationStyle
        toolbar.update(tool: canvas.tool, color: selectedStyle?.color ?? preferences.lastColor,
                       lineWidth: selectedStyle?.lineWidth ?? preferences.lastLineWidth,
                       mosaicMode: preferences.mosaicMode, canUndo: document.canUndo, canRedo: document.canRedo,
                       arrowStyle: preferences.lastArrowStyle, selectedArrowStyle: canvas.selectedArrowStyle)
        layout()
        canvas.needsDisplay = true
    }
}

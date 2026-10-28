import AppKit

/// Floating panel with the recognised text in an editable text view, plus 「复制」 (as edited,
/// line breaks kept) and 「复制为单行」 (lines joined via `joinedAsSingleLine`). One panel is
/// reused; showing new text replaces the old.
@MainActor
public enum OCRResultPanel {
    private static var controller: Controller?

    public static func show(text: String) {
        let c = controller ?? Controller()
        controller = c
        c.show(text: text)
    }

    /// Lines of `text` as `joinedAsSingleLine` expects: trimmed, blank lines dropped.
    static func singleLine(from text: String) -> String {
        text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joinedAsSingleLine
    }
}

@MainActor
private final class Controller: NSObject {
    private let panel: NSPanel
    private let textView: NSTextView

    override init() {
        panel = NSPanel(contentRect: CGRect(x: 0, y: 0, width: 420, height: 320),
                        styleMask: [.titled, .closable, .resizable, .utilityWindow],
                        backing: .buffered, defer: true)
        panel.title = "识别结果"
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.minSize = CGSize(width: 280, height: 180)
        panel.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]

        let scroll = NSTextView.scrollableTextView()
        textView = scroll.documentView as! NSTextView
        super.init()

        textView.isEditable = true
        textView.isRichText = false
        textView.allowsUndo = true
        textView.font = .systemFont(ofSize: 13)
        textView.textContainerInset = CGSize(width: 6, height: 6)
        textView.setAccessibilityLabel("识别的文字")
        scroll.borderType = .bezelBorder
        scroll.translatesAutoresizingMaskIntoConstraints = false

        let copy = NSButton(title: "复制", target: self, action: #selector(copyText))
        let copySingle = NSButton(title: "复制为单行", target: self, action: #selector(copySingleLine))
        let buttons = NSStackView(views: [copySingle, copy])
        buttons.orientation = .horizontal
        buttons.spacing = 8
        buttons.translatesAutoresizingMaskIntoConstraints = false

        let content = NSView()
        content.addSubview(scroll)
        content.addSubview(buttons)
        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: content.topAnchor, constant: 12),
            scroll.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 12),
            scroll.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -12),
            buttons.topAnchor.constraint(equalTo: scroll.bottomAnchor, constant: 12),
            buttons.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -12),
            buttons.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -12),
        ])
        panel.contentView = content
    }

    func show(text: String) {
        textView.string = text
        textView.undoManager?.removeAllActions()
        if !panel.isVisible { panel.center() }
        ActivationHelper.activateForKeyboard()
        panel.makeKeyAndOrderFront(nil)
        panel.makeFirstResponder(textView)
        textView.setSelectedRange(NSRange(location: 0, length: 0))
    }

    @objc private func copyText() {
        ClipboardWriter.write(text: textView.string)
        Toast.show("已复制")
    }

    @objc private func copySingleLine() {
        ClipboardWriter.write(text: OCRResultPanel.singleLine(from: textView.string))
        Toast.show("已复制为单行")
    }
}

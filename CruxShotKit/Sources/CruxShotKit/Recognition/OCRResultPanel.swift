import AppKit

/// Editable recognition result with a copy-format picker. Switching format preserves the original
/// text; a new result replaces the previous content in this reusable panel.
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
private final class Controller: NSObject, NSTextViewDelegate {
    private let panel: NSPanel
    private let textView: NSTextView
    private let count = NSTextField(labelWithString: "")
    private let format = NSSegmentedControl(labels: ["保留换行", "合并单行"], trackingMode: .selectOne, target: nil, action: nil)
    private let copy = NSButton(title: "复制文字", target: nil, action: nil)

    override init() {
        panel = NSPanel(contentRect: CGRect(x: 0, y: 0, width: 480, height: 360),
                        styleMask: [.titled, .closable, .resizable, .utilityWindow],
                        backing: .buffered, defer: true)
        panel.title = "识别结果"
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.minSize = CGSize(width: 400, height: 260)
        panel.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]

        let scroll = NSTextView.scrollableTextView()
        textView = scroll.documentView as! NSTextView
        super.init()

        textView.isEditable = true
        textView.isRichText = false
        textView.allowsUndo = true
        textView.font = .systemFont(ofSize: 13)
        textView.textContainerInset = CGSize(width: 12, height: 12)
        textView.delegate = self
        textView.setAccessibilityLabel("识别的文字")
        scroll.borderType = .noBorder
        scroll.wantsLayer = true
        scroll.layer?.cornerRadius = 6
        scroll.layer?.masksToBounds = true
        scroll.translatesAutoresizingMaskIntoConstraints = false

        copy.target = self
        copy.action = #selector(copyText)
        copy.bezelStyle = .rounded
        copy.keyEquivalent = "\r"
        format.selectedSegment = 0
        format.setAccessibilityLabel("复制文字的格式")
        count.font = .monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        count.textColor = .secondaryLabelColor
        let hint = NSTextField(labelWithString: "可直接编辑识别结果")
        hint.font = .systemFont(ofSize: 11)
        hint.textColor = .secondaryLabelColor
        let header = NSStackView(views: [hint, NSView(), count])
        header.translatesAutoresizingMaskIntoConstraints = false
        let buttons = NSStackView(views: [format, NSView(), copy])
        buttons.orientation = .horizontal
        buttons.spacing = 12
        buttons.translatesAutoresizingMaskIntoConstraints = false

        let content = NSView()
        content.addSubview(header)
        content.addSubview(scroll)
        content.addSubview(buttons)
        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: content.topAnchor, constant: 16),
            header.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 16),
            header.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -16),
            scroll.topAnchor.constraint(equalTo: header.bottomAnchor, constant: 10),
            scroll.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 16),
            scroll.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -16),
            buttons.topAnchor.constraint(equalTo: scroll.bottomAnchor, constant: 16),
            buttons.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 16),
            buttons.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -16),
            buttons.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -16),
        ])
        panel.contentView = content
    }

    func show(text: String) {
        textView.string = text
        updateCount()
        textView.undoManager?.removeAllActions()
        if !panel.isVisible { panel.center() }
        ActivationHelper.activateForKeyboard()
        panel.makeKeyAndOrderFront(nil)
        panel.makeFirstResponder(textView)
        textView.setSelectedRange(NSRange(location: 0, length: 0))
    }

    func textDidChange(_ notification: Notification) { updateCount() }

    private func updateCount() {
        count.stringValue = "\(textView.string.count) 字符"
        copy.isEnabled = !textView.string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    @objc private func copyText() {
        guard copy.isEnabled else { return }
        let single = format.selectedSegment == 1
        ClipboardWriter.write(text: single ? OCRResultPanel.singleLine(from: textView.string) : textView.string)
        Toast.show(single ? "已复制为单行" : "已复制文字")
    }
}

import AppKit
import Carbon

/// A small window for choosing the hide/show shortcut.
final class ShortcutSettingsWindowController: NSWindowController, NSWindowDelegate {
    private unowned let appDelegate: AppDelegate

    private let recorder = ShortcutRecorderView()
    private let explanationLabel = NSTextField(wrappingLabelWithString:
        "Tap the shortcut to hide or show the circle. Hold it down instead and the circle flips only until you let go."
    )

    init(appDelegate: AppDelegate) {
        self.appDelegate = appDelegate
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 200),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Keyboard Shortcut"
        window.level = .floating
        window.isReleasedWhenClosed = false
        super.init(window: window)
        window.delegate = self
        buildContent()
        sync()
    }

    required init?(coder: NSCoder) {
        fatalError("ShortcutSettingsWindowController is created in code only")
    }

    func show() {
        sync()
        AppActivation.activate()
        window?.center()
        window?.makeKeyAndOrderFront(nil)
    }

    // MARK: Layout

    private func buildContent() {
        recorder.onChange = { [unowned self] hotKey in
            appDelegate.configuration.shortcut = hotKey
        }
        recorder.onRecordingChanged = { [unowned self] isRecording in
            // Otherwise pressing the current shortcut while recording would toggle the circle.
            appDelegate.isShortcutSuspended = isRecording
        }

        let clearButton = NSButton(title: "Clear", target: self, action: #selector(clearShortcut))
        clearButton.bezelStyle = .rounded
        clearButton.controlSize = .small

        let recorderRow = NSStackView(views: [recorder, clearButton])
        recorderRow.orientation = .horizontal
        recorderRow.spacing = 8

        explanationLabel.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        explanationLabel.textColor = .secondaryLabelColor
        // Pin the width so the wrapped height is computed for the width it actually gets.
        explanationLabel.preferredMaxLayoutWidth = 240
        explanationLabel.widthAnchor.constraint(equalToConstant: 240).isActive = true

        let grid = NSGridView(views: [
            [label("Shortcut:"), recorderRow],
            [NSGridCell.emptyContentView, explanationLabel]
        ])
        grid.rowSpacing = 10
        grid.columnSpacing = 10
        grid.column(at: 0).xPlacement = .trailing
        grid.rowAlignment = .firstBaseline

        let doneButton = NSButton(title: "Done", target: self, action: #selector(done))
        doneButton.bezelStyle = .rounded
        doneButton.keyEquivalent = "\r"

        let stack = NSStackView(views: [grid, doneButton])
        stack.orientation = .vertical
        stack.alignment = .trailing
        stack.spacing = 16
        stack.edgeInsets = NSEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)

        // Handing the stack to a view controller lets the window size itself to fit the content.
        let controller = NSViewController()
        controller.view = stack
        window?.contentViewController = controller
    }

    private func label(_ text: String) -> NSTextField {
        let field = NSTextField(labelWithString: text)
        field.alignment = .right
        return field
    }

    private func sync() {
        recorder.hotKey = appDelegate.configuration.shortcut
    }

    // MARK: Actions

    @objc private func clearShortcut() {
        recorder.stopRecording()
        recorder.hotKey = nil
        appDelegate.configuration.shortcut = nil
    }

    @objc private func done() {
        window?.close()
    }

    func windowWillClose(_ notification: Notification) {
        recorder.stopRecording()
    }
}

/// Click it, press a key combination, and it becomes the shortcut. Escape cancels, Delete clears.
final class ShortcutRecorderView: NSView {
    var hotKey: HotKey? {
        didSet { needsDisplay = true }
    }
    var onChange: ((HotKey?) -> Void)?
    var onRecordingChanged: ((Bool) -> Void)?

    private(set) var isRecording = false {
        didSet {
            guard isRecording != oldValue else { return }
            needsDisplay = true
            onRecordingChanged?(isRecording)
        }
    }

    override var intrinsicContentSize: NSSize { NSSize(width: 170, height: 24) }
    override var acceptsFirstResponder: Bool { true }
    override func isAccessibilityElement() -> Bool { true }
    override func accessibilityRole() -> NSAccessibility.Role? { .button }
    override func accessibilityLabel() -> String? { "Shortcut" }
    override func accessibilityValue() -> Any? { displayText }
    /// Let the first click start recording even if the app wasn't active yet.
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override var focusRingMaskBounds: NSRect { bounds }

    override func drawFocusRingMask() {
        NSBezierPath(roundedRect: bounds, xRadius: 6, yRadius: 6).fill()
    }

    override func mouseDown(with event: NSEvent) {
        if isRecording {
            stopRecording()
        } else {
            window?.makeFirstResponder(self)
            isRecording = true
        }
    }

    func stopRecording() {
        isRecording = false
        if window?.firstResponder == self {
            window?.makeFirstResponder(nil)
        }
    }

    override func resignFirstResponder() -> Bool {
        isRecording = false
        return super.resignFirstResponder()
    }

    /// Combinations with ⌘ arrive here before `keyDown`, so both paths funnel into `record`.
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard isRecording else { return super.performKeyEquivalent(with: event) }
        record(event)
        return true
    }

    override func keyDown(with event: NSEvent) {
        guard isRecording else { return super.keyDown(with: event) }
        record(event)
    }

    private func record(_ event: NSEvent) {
        let modifiers = event.modifierFlags.intersection(HotKey.relevantModifiers)
        switch Int(event.keyCode) {
        case kVK_Escape where modifiers.isEmpty:
            stopRecording()
            return
        case kVK_Delete where modifiers.isEmpty, kVK_ForwardDelete where modifiers.isEmpty:
            hotKey = nil
            stopRecording()
            onChange?(nil)
            return
        default:
            break
        }

        let candidate = HotKey(event: event)
        // Bare letters would swallow normal typing everywhere; function keys are fine alone.
        guard !modifiers.isEmpty || candidate.isFunctionKey else {
            NSSound.beep()
            return
        }
        hotKey = candidate
        stopRecording()
        onChange?(candidate)
    }

    private var displayText: String {
        if isRecording { return "Type shortcut…" }
        return hotKey?.displayString ?? "Click to record"
    }

    override func draw(_ dirtyRect: NSRect) {
        let path = NSBezierPath(roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5), xRadius: 6, yRadius: 6)
        NSColor.controlBackgroundColor.setFill()
        path.fill()
        (isRecording ? NSColor.controlAccentColor : NSColor.separatorColor).setStroke()
        path.lineWidth = isRecording ? 1.5 : 1
        path.stroke()

        let text = displayText
        let color: NSColor = hotKey != nil && !isRecording ? .labelColor : .secondaryLabelColor
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: NSFont.systemFontSize),
            .foregroundColor: color
        ]
        let size = text.size(withAttributes: attributes)
        let origin = NSPoint(x: bounds.midX - size.width / 2, y: bounds.midY - size.height / 2)
        text.draw(at: origin, withAttributes: attributes)
    }
}

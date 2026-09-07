import AppKit
import ServiceManagement

/// Builds the menu bar dropdown and keeps it in sync with the current configuration.
final class MenuManager: NSObject, NSMenuDelegate {
    private unowned let appDelegate: AppDelegate

    let menu = NSMenu()

    private let visibilityItem = NSMenuItem()
    private let sizeSlider = SliderMenuItemView(title: "Size", range: AppConstants.Circle.sizeRange) {
        "\(Int($0.rounded())) pt"
    }
    private let thicknessSlider = SliderMenuItemView(title: "Thickness", range: AppConstants.Circle.thicknessRange) {
        "\(Int($0.rounded())) pt"
    }
    private let intensitySlider = SliderMenuItemView(title: "Intensity", range: AppConstants.Animation.intensityRange) {
        "\(Int(($0 * 100).rounded()))%"
    }
    private let colorItem = NSMenuItem(title: "Colour…", action: #selector(chooseColor), keyEquivalent: "")
    private let launchAtLoginItem = NSMenuItem(title: "Launch at Login", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
    private var animationItems: [AnimationType: NSMenuItem] = [:]
    private lazy var shortcutSettings = ShortcutSettingsWindowController(appDelegate: appDelegate)

    init(appDelegate: AppDelegate) {
        self.appDelegate = appDelegate
        super.init()
        buildMenu()
        syncWithConfiguration()
    }

    // MARK: Building

    private func buildMenu() {
        menu.delegate = self
        menu.autoenablesItems = false

        visibilityItem.target = self
        visibilityItem.action = #selector(toggleVisibility)
        menu.addItem(visibilityItem)
        let shortcutItem = NSMenuItem(title: "Keyboard Shortcut…", action: #selector(showShortcutSettings), keyEquivalent: "")
        shortcutItem.target = self
        menu.addItem(shortcutItem)

        menu.addItem(.separator())
        menu.addItem(.sectionHeader(title: "Circle"))
        sizeSlider.onChange = { [unowned self] in appDelegate.configuration.size = $0 }
        thicknessSlider.onChange = { [unowned self] in appDelegate.configuration.thickness = $0 }
        menu.addItem(sizeSlider.menuItem)
        menu.addItem(thicknessSlider.menuItem)
        colorItem.target = self
        menu.addItem(colorItem)

        menu.addItem(.separator())
        menu.addItem(.sectionHeader(title: "Click Animation"))
        for type in AnimationType.allCases {
            let item = NSMenuItem(title: type.displayName, action: #selector(selectAnimation(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = type.rawValue
            item.indentationLevel = 1
            animationItems[type] = item
            menu.addItem(item)
        }
        intensitySlider.onChange = { [unowned self] in appDelegate.configuration.intensity = $0 }
        menu.addItem(intensitySlider.menuItem)

        menu.addItem(.separator())
        launchAtLoginItem.target = self
        menu.addItem(launchAtLoginItem)
        let resetItem = NSMenuItem(title: "Reset to Defaults", action: #selector(resetToDefaults), keyEquivalent: "")
        resetItem.target = self
        menu.addItem(resetItem)

        menu.addItem(.separator())
        let aboutItem = NSMenuItem(title: "About Mouse Circle", action: #selector(showAbout), keyEquivalent: "")
        aboutItem.target = self
        menu.addItem(aboutItem)
        menu.addItem(NSMenuItem(title: "Quit Mouse Circle", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
    }

    /// Push the current configuration into every control.
    private func syncWithConfiguration() {
        let configuration = appDelegate.configuration
        visibilityItem.title = appDelegate.isCircleVisible ? "Hide Circle" : "Show Circle"
        // Display only: the shortcut itself is handled by HotKeyCenter.
        visibilityItem.keyEquivalent = configuration.shortcut?.keyEquivalent ?? ""
        visibilityItem.keyEquivalentModifierMask = configuration.shortcut?.modifierFlags ?? []
        sizeSlider.value = configuration.size
        thicknessSlider.value = configuration.thickness
        intensitySlider.value = configuration.intensity
        colorItem.image = swatchImage(for: configuration.color)
        for (type, item) in animationItems {
            item.state = type == configuration.animation ? .on : .off
        }
        launchAtLoginItem.state = SMAppService.mainApp.status == .enabled ? .on : .off
    }

    /// A small filled circle showing the current colour, drawn over a light/dark checker
    /// so translucent colours read correctly.
    private func swatchImage(for color: NSColor) -> NSImage {
        let size = NSSize(width: 16, height: 16)
        return NSImage(size: size, flipped: false) { rect in
            let circle = NSBezierPath(ovalIn: rect.insetBy(dx: 1, dy: 1))
            NSColor.textBackgroundColor.setFill()
            circle.fill()
            color.setFill()
            circle.fill()
            NSColor.separatorColor.setStroke()
            circle.lineWidth = 1
            circle.stroke()
            return true
        }
    }

    // MARK: Actions

    @objc private func toggleVisibility() {
        appDelegate.isCircleVisible.toggle()
        syncWithConfiguration()
    }

    @objc private func showShortcutSettings() {
        shortcutSettings.show()
    }

    @objc private func selectAnimation(_ sender: NSMenuItem) {
        guard let rawValue = sender.representedObject as? String,
              let type = AnimationType(rawValue: rawValue) else { return }
        appDelegate.configuration.animation = type
        syncWithConfiguration()
    }

    @objc private func toggleLaunchAtLogin() {
        let service = SMAppService.mainApp
        do {
            if service.status == .enabled {
                try service.unregister()
            } else {
                try service.register()
            }
        } catch {
            NSSound.beep()
        }
        syncWithConfiguration()
    }

    @objc private func showAbout() {
        NSApp.activate()
        NSApp.orderFrontStandardAboutPanel(nil)
    }

    @objc private func resetToDefaults() {
        appDelegate.configuration = CircleConfiguration()
        syncWithConfiguration()
    }

    @objc private func chooseColor() {
        let panel = NSColorPanel.shared
        panel.showsAlpha = true
        panel.isContinuous = true
        panel.color = appDelegate.configuration.color
        panel.setTarget(self)
        panel.setAction(#selector(colorPanelDidChange(_:)))
        panel.level = .floating

        // We're a menu bar app with no windows of our own, so we have to activate to show a panel.
        NSApp.activate()
        panel.center()
        panel.makeKeyAndOrderFront(nil)
    }

    @objc private func colorPanelDidChange(_ panel: NSColorPanel) {
        appDelegate.configuration.color = panel.color
        colorItem.image = swatchImage(for: panel.color)
    }

    // MARK: NSMenuDelegate

    func menuWillOpen(_ menu: NSMenu) {
        syncWithConfiguration()
        appDelegate.menuDidOpen()
    }

    func menuDidClose(_ menu: NSMenu) {
        appDelegate.menuDidClose()
    }
}

/// A labelled slider with a live value readout, hosted in a menu item.
final class SliderMenuItemView: NSView {
    let menuItem = NSMenuItem()
    var onChange: ((Double) -> Void)?

    var value: Double {
        get { slider.doubleValue }
        set {
            slider.doubleValue = newValue
            valueLabel.stringValue = format(newValue)
        }
    }

    private let slider = NSSlider()
    private let valueLabel = NSTextField(labelWithString: "")
    private let format: (Double) -> String

    private static let width: CGFloat = 240
    private static let height: CGFloat = 46
    private static let inset: CGFloat = 14

    init(title: String, range: ClosedRange<Double>, format: @escaping (Double) -> String) {
        self.format = format
        super.init(frame: NSRect(x: 0, y: 0, width: Self.width, height: Self.height))

        let contentWidth = Self.width - Self.inset * 2

        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = .menuFont(ofSize: 0)
        titleLabel.frame = NSRect(x: Self.inset, y: 24, width: contentWidth * 0.6, height: 18)
        addSubview(titleLabel)

        valueLabel.font = .monospacedDigitSystemFont(ofSize: NSFont.smallSystemFontSize, weight: .regular)
        valueLabel.textColor = .secondaryLabelColor
        valueLabel.alignment = .right
        valueLabel.frame = NSRect(x: Self.inset + contentWidth * 0.6, y: 25, width: contentWidth * 0.4, height: 16)
        addSubview(valueLabel)

        slider.minValue = range.lowerBound
        slider.maxValue = range.upperBound
        slider.controlSize = .small
        slider.isContinuous = true
        slider.target = self
        slider.action = #selector(sliderMoved)
        slider.frame = NSRect(x: Self.inset, y: 4, width: contentWidth, height: 20)
        addSubview(slider)

        menuItem.view = self
    }

    required init?(coder: NSCoder) {
        fatalError("SliderMenuItemView is created in code only")
    }

    @objc private func sliderMoved() {
        valueLabel.stringValue = format(slider.doubleValue)
        onChange?(slider.doubleValue)
    }
}

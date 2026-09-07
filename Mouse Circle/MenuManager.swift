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
    /// One radio group per mouse button, keyed by button then animation.
    private var animationItems: [MouseButton: [AnimationType: NSMenuItem]] = [:]
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
        menu.addItem(makeItem("Keyboard Shortcut…", symbol: "keyboard", action: #selector(showShortcutSettings)))

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
        for button in MouseButton.allCases {
            let item = makeItem(button.displayName, symbol: button.symbolName, action: nil)
            item.submenu = makeAnimationSubmenu(for: button)
            menu.addItem(item)
        }
        intensitySlider.onChange = { [unowned self] in appDelegate.configuration.intensity = $0 }
        menu.addItem(intensitySlider.menuItem)

        menu.addItem(.separator())
        launchAtLoginItem.target = self
        menu.addItem(launchAtLoginItem)
        menu.addItem(makeItem("Reset to Defaults", symbol: "arrow.counterclockwise", action: #selector(resetToDefaults)))

        menu.addItem(.separator())
        menu.addItem(makeItem("About Mouse Circle", symbol: "info.circle", action: #selector(showAbout)))
        let quitItem = makeItem("Quit Mouse Circle", symbol: "power", action: #selector(NSApplication.terminate(_:)))
        quitItem.target = nil
        quitItem.keyEquivalent = "q"
        menu.addItem(quitItem)
    }

    private func makeItem(_ title: String, symbol: String, action: Selector?) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        item.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
        return item
    }

    private func makeAnimationSubmenu(for button: MouseButton) -> NSMenu {
        let submenu = NSMenu(title: button.displayName)
        var items: [AnimationType: NSMenuItem] = [:]
        for type in AnimationType.allCases {
            let item = NSMenuItem(title: type.displayName, action: #selector(selectAnimation(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = AnimationChoice(button: button, animation: type)
            items[type] = item
            submenu.addItem(item)
        }
        animationItems[button] = items
        return submenu
    }

    /// Push the current configuration into every control.
    private func syncWithConfiguration() {
        let configuration = appDelegate.configuration
        let visible = appDelegate.isCircleVisible
        visibilityItem.title = visible ? "Hide Circle" : "Show Circle"
        visibilityItem.image = NSImage(systemSymbolName: visible ? "eye.slash" : "eye", accessibilityDescription: nil)
        // Display only: the shortcut itself is handled by HotKeyCenter.
        visibilityItem.keyEquivalent = configuration.shortcut?.keyEquivalent ?? ""
        visibilityItem.keyEquivalentModifierMask = configuration.shortcut?.modifierFlags ?? []
        sizeSlider.value = configuration.size
        thicknessSlider.value = configuration.thickness
        intensitySlider.value = configuration.intensity
        colorItem.image = swatchImage(for: configuration.color)
        for (button, items) in animationItems {
            for (type, item) in items {
                item.state = type == configuration.animation(for: button) ? .on : .off
            }
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
        guard let choice = sender.representedObject as? AnimationChoice else { return }
        appDelegate.configuration.setAnimation(choice.animation, for: choice.button)
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
        AppActivation.activate()
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
        // A menu bar app is rarely the active app, and panels hide themselves when the app is
        // inactive, so opt out of that or the panel vanishes as soon as it appears.
        panel.hidesOnDeactivate = false

        AppActivation.activate()
        panel.center()
        panel.makeKeyAndOrderFront(nil)
    }

    /// Target of the colour panel's continuous action. Internal so tests can drive it.
    @objc func colorPanelDidChange(_ panel: NSColorPanel) {
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

/// Carried by each animation menu item so one action can serve both submenus.
final class AnimationChoice: NSObject {
    let button: MouseButton
    let animation: AnimationType

    init(button: MouseButton, animation: AnimationType) {
        self.button = button
        self.animation = animation
    }
}

/// A labelled slider with a live value readout, hosted in a menu item.
/// Laid out with Auto Layout so it stretches to the menu's width and the text lines up
/// with the other items.
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

    init(title: String, range: ClosedRange<Double>, format: @escaping (Double) -> String) {
        self.format = format
        super.init(frame: NSRect(x: 0, y: 0, width: AppConstants.MenuBar.sliderRowWidth, height: 46))
        autoresizingMask = [.width]

        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = .menuFont(ofSize: 0)

        valueLabel.font = .monospacedDigitSystemFont(ofSize: NSFont.smallSystemFontSize, weight: .regular)
        valueLabel.textColor = .secondaryLabelColor
        valueLabel.alignment = .right
        valueLabel.setContentHuggingPriority(.required, for: .horizontal)

        slider.minValue = range.lowerBound
        slider.maxValue = range.upperBound
        slider.controlSize = .small
        slider.isContinuous = true
        slider.target = self
        slider.action = #selector(sliderMoved)

        for view in [titleLabel, valueLabel, slider] {
            view.translatesAutoresizingMaskIntoConstraints = false
            addSubview(view)
        }

        let leading = AppConstants.MenuBar.sliderLeadingInset
        let trailing = AppConstants.MenuBar.sliderTrailingInset
        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: leading),
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 4),
            valueLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -trailing),
            valueLabel.firstBaselineAnchor.constraint(equalTo: titleLabel.firstBaselineAnchor),
            valueLabel.leadingAnchor.constraint(greaterThanOrEqualTo: titleLabel.trailingAnchor, constant: 8),
            slider.leadingAnchor.constraint(equalTo: leadingAnchor, constant: leading),
            slider.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -trailing),
            slider.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -4)
        ])

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

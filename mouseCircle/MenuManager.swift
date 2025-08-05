import AppKit

/**
 * Custom slider class that properly handles mouse events in menu context
 */
class MenuSlider: NSSlider {
    override func mouseDown(with event: NSEvent) {
        isHighlighted = true
        needsDisplay = true
        
        // Use custom mouse tracking to ensure proper press/release behavior
        let mask: NSEvent.EventTypeMask = [.leftMouseUp, .leftMouseDragged]
        var keepTracking = true
        
        while keepTracking {
            if let nextEvent = window?.nextEvent(matching: mask) {
                let point = convert(nextEvent.locationInWindow, from: nil)
                
                switch nextEvent.type {
                case .leftMouseDragged:
                    if bounds.contains(point) {
                        // Calculate new value based on mouse position
                        let ratio = (point.x - knobThickness/2) / (bounds.width - knobThickness)
                        let clampedRatio = max(0, min(1, ratio))
                        doubleValue = minValue + (maxValue - minValue) * clampedRatio
                        
                        // Send action
                        if let target = target, let action = action {
                            _ = target.perform(action, with: self)
                        }
                        needsDisplay = true
                    }
                    
                case .leftMouseUp:
                    isHighlighted = false
                    needsDisplay = true
                    keepTracking = false
                    
                default:
                    break
                }
            } else {
                keepTracking = false
            }
        }
    }
}

/**
 * MenuManager: Creates and manages the menu bar dropdown interface
 * 
 * Handles the dropdown menu when clicking the menu bar icon, including
 * sliders for circle properties, animation type selection, and color picker.
 */
class MenuManager: NSObject, NSMenuDelegate {
    private weak var appDelegate: AppDelegate?
    
    init(appDelegate: AppDelegate) {
        self.appDelegate = appDelegate
        super.init()
    }
    
    deinit {
        // Clean up color picker notification observer
        NotificationCenter.default.removeObserver(self)
        appDelegate = nil
    }
    
    func createMenu() -> NSMenu {
        let menu = NSMenu()
        menu.delegate = self
        
        let sliderItems = [
            ("Circle Size", 30.0, 800.0, Double(appDelegate?.configuration.size ?? 100), #selector(sizeSliderChanged(_:))),
            ("Animation Intensity", 0.0, 1.0, Double(appDelegate?.configuration.intensity ?? 0.5), #selector(intensitySliderChanged(_:))),
            ("Circle Thickness", 1.0, 30.0, Double(appDelegate?.configuration.thickness ?? 4), #selector(thicknessSliderChanged(_:)))
        ]
        
        for (title, min, max, current, action) in sliderItems {
            menu.addItem(createSliderMenuItem(
                title: title,
                minValue: min,
                maxValue: max,
                currentValue: current,
                action: action
            ))
        }
        
        menu.addItem(NSMenuItem.separator())
        
        let animationMenuItem = NSMenuItem(title: "Animation Type", action: nil, keyEquivalent: "")
        let animationSubmenu = NSMenu()
        
        for type in AnimationType.allCases {
            let item = NSMenuItem(title: type.rawValue, action: #selector(animationTypeChanged(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = type
            item.state = (type == appDelegate?.configuration.type) ? .on : .off
            animationSubmenu.addItem(item)
        }
        
        animationMenuItem.submenu = animationSubmenu
        menu.addItem(animationMenuItem)
        
        let colorMenuItem = NSMenuItem(title: "Circle Color...", action: #selector(openColorPicker), keyEquivalent: "")
        colorMenuItem.target = self
        menu.addItem(colorMenuItem)
        
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        
        return menu
    }
    
    // Note: createColorSubmenu method removed - now using color picker instead
    
    private func createSliderMenuItem(title: String, minValue: Double, maxValue: Double, currentValue: Double, action: Selector) -> NSMenuItem {
        let menuItem = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        let sliderView = NSView(frame: NSRect(x: 0, y: 0, width: 200, height: 50))
        
        let label = NSTextField(frame: NSRect(x: 18, y: 25, width: 164, height: 20))
        label.stringValue = title
        label.isBezeled = false
        label.drawsBackground = false
        label.isEditable = false
        label.isSelectable = false
        sliderView.addSubview(label)
        
        let slider = MenuSlider(frame: NSRect(x: 18, y: 5, width: 164, height: 20))
        slider.minValue = minValue
        slider.maxValue = maxValue
        slider.doubleValue = currentValue
        slider.target = self
        slider.action = action
        
        sliderView.addSubview(slider)
        
        menuItem.view = sliderView
        return menuItem
    }
    
    /**
     * Open the system color picker
     */
    @objc private func openColorPicker() {
        let colorPanel = NSColorPanel.shared
        
        // Remove any existing observers to prevent duplicates
        NotificationCenter.default.removeObserver(
            self,
            name: NSColorPanel.colorDidChangeNotification,
            object: colorPanel
        )
        NotificationCenter.default.removeObserver(
            self,
            name: NSWindow.willCloseNotification,
            object: colorPanel
        )
        NotificationCenter.default.removeObserver(
            self,
            name: NSWindow.didResignKeyNotification,
            object: colorPanel
        )
        NotificationCenter.default.removeObserver(
            self,
            name: NSWindow.didResignMainNotification,
            object: colorPanel
        )
        
        // Set current color in the picker
        if let currentColor = appDelegate?.configuration.color {
            let srgbColor = currentColor.usingColorSpace(.sRGB) ?? currentColor
            colorPanel.color = srgbColor
        }
        
        // Reset mouse state when opening color picker
        appDelegate?.resetMouseState()
        
        colorPanel.showsAlpha = true
        
        // Set up callbacks for color changes and panel close/deactivate
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(colorPickerChanged(_:)),
            name: NSColorPanel.colorDidChangeNotification,
            object: colorPanel
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(colorPickerWillClose(_:)),
            name: NSWindow.willCloseNotification,
            object: colorPanel
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(colorPickerDidResignKey(_:)),
            name: NSWindow.didResignKeyNotification,
            object: colorPanel
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(colorPickerDidResignMain(_:)),
            name: NSWindow.didResignMainNotification,
            object: colorPanel
        )
        
        // Center the color picker on screen
        if let mainScreen = NSScreen.main {
            let screenFrame = mainScreen.visibleFrame
            let panelSize = NSSize(width: 270, height: 400)
            let panelOrigin = NSPoint(
                x: screenFrame.midX - panelSize.width / 2,
                y: screenFrame.midY - panelSize.height / 2
            )
            colorPanel.setFrameOrigin(panelOrigin)
        }
        
        // Show the color picker
        colorPanel.level = .floating
        colorPanel.orderFront(nil)
        colorPanel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    /**
     * Handle color picker changes
     */
    @objc private func colorPickerChanged(_ notification: Notification) {
        if let colorPanel = notification.object as? NSColorPanel {
            let selectedColor = colorPanel.color.usingColorSpace(.sRGB) ?? colorPanel.color
            appDelegate?.configuration.color = selectedColor
        }
    }
    
    /**
     * Handle color picker closing
     */
    @objc private func colorPickerWillClose(_ notification: Notification) {
        appDelegate?.menuDidClose()
    }
    
    /**
     * Handle color picker losing key window status (when user clicks elsewhere)
     */
    @objc private func colorPickerDidResignKey(_ notification: Notification) {
        appDelegate?.menuDidClose()
    }
    
    /**
     * Handle color picker losing main window status
     */
    @objc private func colorPickerDidResignMain(_ notification: Notification) {
        appDelegate?.menuDidClose()
    }
    
    @objc func sizeSliderChanged(_ sender: NSSlider) {
        appDelegate?.configuration.size = CGFloat(sender.doubleValue)
    }
    
    @objc func intensitySliderChanged(_ sender: NSSlider) {
        appDelegate?.configuration.intensity = CGFloat(sender.doubleValue)
    }
    
    @objc func thicknessSliderChanged(_ sender: NSSlider) {
        appDelegate?.configuration.thickness = CGFloat(sender.doubleValue)
    }
    
    
    @objc func animationTypeChanged(_ sender: NSMenuItem) {
        guard let newType = sender.representedObject as? AnimationType else { return }
        
        appDelegate?.configuration.type = newType
        
        if let menu = sender.menu {
            for item in menu.items {
                item.state = (item.representedObject as? AnimationType == appDelegate?.configuration.type) ? .on : .off
            }
        }
    }
    
    // MARK: - NSMenuDelegate
    
    func menuWillOpen(_ menu: NSMenu) {
        // Reset mouse state when menu actually opens
        appDelegate?.resetMouseState()
    }
    
    func menuDidClose(_ menu: NSMenu) {
        appDelegate?.menuDidClose()
        // Force update all views to ensure settings are applied
        appDelegate?.windowManager?.updateAllViews()
    }
}

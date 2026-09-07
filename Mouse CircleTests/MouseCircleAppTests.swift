import XCTest
@testable import MouseCircle

/// Integration tests that run inside the real app: the status item, menu, overlay windows,
/// colour panel and shortcut are the live objects the user interacts with.
final class MouseCircleAppTests: XCTestCase {
    private var appDelegate: AppDelegate!
    private var menu: NSMenu!
    private var savedConfiguration: CircleConfiguration!

    override func setUpWithError() throws {
        appDelegate = try XCTUnwrap(NSApp.delegate as? AppDelegate)
        menu = try XCTUnwrap(appDelegate.statusItem?.menu)
        savedConfiguration = appDelegate.configuration
    }

    override func tearDown() {
        appDelegate.configuration = savedConfiguration
        appDelegate.isCircleVisible = true
        NSColorPanel.shared.close()
        for window in NSApp.windows where window.title == "Keyboard Shortcut" {
            window.close()
        }
    }

    // MARK: Helpers

    private func menuItem(_ title: String) throws -> NSMenuItem {
        try XCTUnwrap(menu.items.first { $0.title == title }, "No menu item titled \(title)")
    }

    /// Runs the item's action the way NSMenu does when the user clicks it.
    private func choose(_ title: String) throws {
        let item = try menuItem(title)
        menu.performActionForItem(at: menu.index(of: item))
    }

    /// The delegate call NSMenu makes right before the menu is shown, which refreshes titles and states.
    private func openMenu() {
        menu.delegate?.menuWillOpen?(menu)
        menu.delegate?.menuDidClose?(menu)
    }

    private func pump(_ seconds: TimeInterval) {
        RunLoop.main.run(until: Date(timeIntervalSinceNow: seconds))
    }

    private var overlayWindows: [OverlayWindow] {
        appDelegate.windowManager?.windows ?? []
    }

    // MARK: Menu bar

    func testMenuBarItemExistsWithAnIcon() throws {
        let statusItem = try XCTUnwrap(appDelegate.statusItem)
        XCTAssertNotNil(statusItem.button?.image)
        XCTAssertTrue(statusItem.isVisible)
    }

    func testMenuHasEveryControl() throws {
        let titles = menu.items.map(\.title)
        for expected in ["Hide Circle", "Keyboard Shortcut…", "Colour…", "Left Click", "Right Click",
                         "Launch at Login", "Reset to Defaults", "About Mouse Circle", "Quit Mouse Circle"] {
            XCTAssertTrue(titles.contains(expected), "Menu is missing \(expected)")
        }
        for button in ["Left Click", "Right Click"] {
            let submenu = try menuItem(button).submenu
            XCTAssertEqual(submenu?.items.map(\.title), ["Ripple", "Pulse", "Flash", "None"])
        }
        XCTAssertEqual(menu.items.filter { $0.view is SliderMenuItemView }.count, 3, "Size, thickness and intensity sliders")
    }

    // MARK: Overlay windows

    func testOneOverlayWindowPerScreenAboveEverything() {
        XCTAssertEqual(overlayWindows.count, NSScreen.screens.count)
        for window in overlayWindows {
            XCTAssertTrue(window.isVisible)
            XCTAssertEqual(window.level, AppConstants.Window.overlayLevel)
            XCTAssertGreaterThan(window.level.rawValue, NSWindow.Level.screenSaver.rawValue, "Must sit above full-screen apps and menus")
            XCTAssertTrue(window.ignoresMouseEvents, "Must be click-through")
            XCTAssertTrue(window.collectionBehavior.contains(.canJoinAllSpaces))
            XCTAssertTrue(window.collectionBehavior.contains(.fullScreenAuxiliary))
            XCTAssertTrue(NSScreen.screens.contains { $0.frame == window.frame }, "Window should cover a whole screen")
            XCTAssertNotNil(window.circleView)
        }
    }

    func testConfigurationChangesReachEveryCircle() {
        appDelegate.configuration.size = 300
        appDelegate.configuration.thickness = 10
        for window in overlayWindows {
            let ring = window.circleView!.ringLayer
            XCTAssertEqual(ring.bounds.width, 310, accuracy: 0.01)
            XCTAssertEqual(ring.lineWidth, 10, accuracy: 0.01)
        }
    }

    func testCircleFollowsTheMouse() throws {
        let manager = try XCTUnwrap(appDelegate.windowManager)
        let window = try XCTUnwrap(overlayWindows.first)
        let target = NSPoint(x: window.frame.midX + 40, y: window.frame.midY - 25)
        manager.moveCircle(to: target)
        let expected = window.convertPoint(fromScreen: target)
        XCTAssertEqual(window.circleView!.ringLayer.position.x, expected.x, accuracy: 0.01)
        XCTAssertEqual(window.circleView!.ringLayer.position.y, expected.y, accuracy: 0.01)
    }

    // MARK: Hide and show

    func testHideAndShowFromMenu() throws {
        try choose("Hide Circle")
        XCTAssertFalse(appDelegate.isCircleVisible)
        XCTAssertTrue(overlayWindows.allSatisfy { !$0.isVisible })

        openMenu()
        XCTAssertNotNil(try? menuItem("Show Circle"), "Title should flip once hidden")

        try choose("Show Circle")
        XCTAssertTrue(appDelegate.isCircleVisible)
        XCTAssertTrue(overlayWindows.allSatisfy(\.isVisible))
    }

    func testShortcutTapToggles() {
        XCTAssertTrue(appDelegate.isCircleVisible)
        appDelegate.shortcutPressed()
        appDelegate.shortcutReleased()
        XCTAssertFalse(appDelegate.isCircleVisible, "A quick tap should leave the circle hidden")

        appDelegate.shortcutPressed()
        appDelegate.shortcutReleased()
        XCTAssertTrue(appDelegate.isCircleVisible)
    }

    func testShortcutHoldIsMomentary() {
        XCTAssertTrue(appDelegate.isCircleVisible)
        appDelegate.shortcutPressed()
        XCTAssertFalse(appDelegate.isCircleVisible, "Circle should flip as soon as the key goes down")
        pump(AppConstants.Timing.shortcutHoldThreshold + 0.1)
        appDelegate.shortcutReleased()
        XCTAssertTrue(appDelegate.isCircleVisible, "A hold should flip back on release")
    }

    func testShortcutKeyRepeatDoesNotFlicker() {
        appDelegate.shortcutPressed()
        appDelegate.shortcutPressed()
        appDelegate.shortcutPressed()
        XCTAssertFalse(appDelegate.isCircleVisible, "Repeated presses from key repeat must count once")
        appDelegate.shortcutReleased()
    }

    func testShortcutIsRegisteredWithTheSystem() {
        let center = HotKeyCenter()
        XCTAssertTrue(center.register(HotKey(keyCode: 0x2F, modifierFlags: [.control, .option, .command, .shift], keyEquivalent: ".")))
        center.unregister()
    }

    // MARK: Colour

    func testColourMenuItemOpensColourPanel() throws {
        XCTAssertFalse(NSColorPanel.shared.isVisible)
        try choose("Colour…")
        pump(0.2)
        XCTAssertTrue(NSColorPanel.shared.isVisible, "Colour panel should be on screen after choosing Colour…")
        XCTAssertFalse(NSColorPanel.shared.hidesOnDeactivate, "Panel must survive the app being inactive")
        XCTAssertTrue(NSColorPanel.shared.showsAlpha)
    }

    func testPickingAColourUpdatesTheCircle() throws {
        try choose("Colour…")
        pump(0.1)
        let panel = NSColorPanel.shared
        let chosen = NSColor(srgbRed: 0.9, green: 0.1, blue: 0.2, alpha: 0.7)
        panel.color = chosen
        // NSColorPanel sends its action to its target as the user drags; do the same.
        try XCTUnwrap(appDelegate.menuManager).colorPanelDidChange(panel)

        let applied = appDelegate.configuration.color.usingColorSpace(.sRGB)!
        XCTAssertEqual(applied.redComponent, 0.9, accuracy: 0.01)
        XCTAssertEqual(applied.alphaComponent, 0.7, accuracy: 0.01)
        for window in overlayWindows {
            let stroke = window.circleView!.ringLayer.strokeColor.map { NSColor(cgColor: $0)?.usingColorSpace(.sRGB) } ?? nil
            XCTAssertEqual(stroke?.redComponent ?? -1, 0.9, accuracy: 0.01)
        }
        openMenu()
        XCTAssertNotNil(try menuItem("Colour…").image, "Swatch should show the current colour")
    }

    // MARK: Other menu actions

    func testKeyboardShortcutItemOpensSettingsWindow() throws {
        try choose("Keyboard Shortcut…")
        pump(0.2)
        let window = try XCTUnwrap(NSApp.windows.first { $0.title == "Keyboard Shortcut" })
        XCTAssertTrue(window.isVisible)
        XCTAssertFalse(window.hidesOnDeactivate)
    }

    private func chooseAnimation(_ title: String, for button: String) throws {
        let submenu = try XCTUnwrap(menuItem(button).submenu)
        let item = try XCTUnwrap(submenu.items.first { $0.title == title })
        submenu.performActionForItem(at: submenu.index(of: item))
    }

    func testAnimationSelectionIsPerButton() throws {
        try chooseAnimation("Flash", for: "Right Click")
        XCTAssertEqual(appDelegate.configuration.rightClickAnimation, .flash)
        XCTAssertEqual(appDelegate.configuration.leftClickAnimation, .ripple, "Left click should be untouched")

        let rightItems = try XCTUnwrap(menuItem("Right Click").submenu).items
        XCTAssertEqual(rightItems.first { $0.title == "Flash" }?.state, .on)
        XCTAssertEqual(rightItems.first { $0.title == "Pulse" }?.state, .off)

        try chooseAnimation("None", for: "Left Click")
        XCTAssertEqual(appDelegate.configuration.leftClickAnimation, .none)
    }

    func testEachButtonPlaysItsOwnAnimation() throws {
        let manager = try XCTUnwrap(appDelegate.windowManager)
        let view = try XCTUnwrap(overlayWindows.first?.circleView)
        appDelegate.configuration.leftClickAnimation = .ripple
        appDelegate.configuration.rightClickAnimation = .flash
        let point = NSPoint(x: 100, y: 100)

        manager.mousePressed(at: point, button: .right)
        let fill = try XCTUnwrap(view.ringLayer.fillColor, "Flash should fill the circle while pressed")
        XCTAssertGreaterThan(fill.alpha, 0)
        manager.mouseReleased(at: point, button: .right)
        XCTAssertNil(view.ringLayer.fillColor)
        XCTAssertFalse(view.isRippling, "Right click is set to flash, not ripple")

        manager.mousePressed(at: point, button: .left)
        XCTAssertNil(view.ringLayer.fillColor)
        manager.mouseReleased(at: point, button: .left)
        XCTAssertTrue(view.isRippling)
    }

    func testNoneAnimationLeavesTheRingAlone() throws {
        let manager = try XCTUnwrap(appDelegate.windowManager)
        let view = try XCTUnwrap(overlayWindows.first?.circleView)
        appDelegate.configuration.leftClickAnimation = .none
        let before = view.ringLayer.strokeColor
        manager.mousePressed(at: .zero, button: .left)
        XCTAssertEqual(view.ringLayer.strokeColor, before)
        manager.mouseReleased(at: .zero, button: .left)
        XCTAssertFalse(view.isRippling)
    }

    func testResetToDefaultsRestoresEverything() throws {
        appDelegate.configuration.size = 555
        appDelegate.configuration.rightClickAnimation = .none
        appDelegate.configuration.shortcut = nil
        try choose("Reset to Defaults")
        XCTAssertEqual(appDelegate.configuration, CircleConfiguration())
    }

    func testSettingsPersistAcrossLaunches() {
        appDelegate.configuration.size = 222
        XCTAssertEqual(CircleConfiguration.load().size, 222, "Changes should be saved immediately")
    }
}

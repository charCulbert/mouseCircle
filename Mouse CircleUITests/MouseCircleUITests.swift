import XCTest

/// True end-to-end: launches the app and drives it through the menu bar like a user, changes
/// settings, and relaunches to prove they stuck. Runs against its own settings suite so it
/// never touches the real ones. Needs Xcode's UI testing permission the first time it runs.
final class MouseCircleUITests: XCTestCase {
    private static let suite = "MouseCircleUITests"
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--settings-suite", Self.suite, "--reset-settings"]
        app.launch()
    }

    override func tearDown() {
        app.terminate()
    }

    // MARK: Helpers

    private func openMenu() {
        let statusItem = app.statusItems.firstMatch
        XCTAssertTrue(statusItem.waitForExistence(timeout: 5), "Menu bar item should appear")
        statusItem.click()
        XCTAssertTrue(app.menuItems["Keyboard Shortcut…"].waitForExistence(timeout: 5), "Menu should open")
    }

    private func closeMenu() {
        app.typeKey(.escape, modifierFlags: [])
        app.typeKey(.escape, modifierFlags: [])
    }

    /// Items with a badge report the badge as part of their title, so match on the prefix.
    private func menuItem(_ title: String) -> XCUIElement {
        app.menuItems.matching(NSPredicate(format: "title BEGINSWITH %@", title)).firstMatch
    }

    private func clickMenuItem(_ title: String) {
        let item = menuItem(title)
        XCTAssertTrue(item.waitForExistence(timeout: 5), "No menu item \(title)")
        item.click()
    }

    /// Chooses an animation inside the Left Click or Right Click submenu.
    private func chooseAnimation(_ animation: String, for button: String) {
        openMenu()
        clickMenuItem(button)
        let item = menuItem(button).menuItems[animation]
        XCTAssertTrue(item.waitForExistence(timeout: 5), "No \(animation) under \(button)")
        item.click()
    }

    private func sliderReadout(_ title: String) -> String {
        let label = app.staticTexts["\(title) value"]
        XCTAssertTrue(label.waitForExistence(timeout: 5))
        return label.value as? String ?? ""
    }

    private func relaunchKeepingSettings() {
        app.terminate()
        app.launchArguments = ["--settings-suite", Self.suite]
        app.launch()
    }

    private var shortcutWindow: XCUIElement { app.windows["Keyboard Shortcut"] }

    private func openShortcutWindow() {
        openMenu()
        clickMenuItem("Keyboard Shortcut…")
        XCTAssertTrue(shortcutWindow.waitForExistence(timeout: 5))
        XCTAssertTrue(shortcutWindow.buttons["Shortcut"].waitForExistence(timeout: 5))
    }

    // MARK: Flows

    func testMenuListsEveryControl() {
        openMenu()
        for title in ["Hide Circle", "Keyboard Shortcut…", "Colour…", "Left Click", "Right Click",
                      "Launch at Login", "Reset to Defaults", "About Mouse Circle", "Quit Mouse Circle"] {
            XCTAssertTrue(menuItem(title).exists, "Missing \(title)")
        }
        XCTAssertEqual(app.sliders.count, 3)
        XCTAssertEqual(sliderReadout("Size"), "184 pt")
        XCTAssertEqual(sliderReadout("Thickness"), "6 pt")
        XCTAssertEqual(sliderReadout("Intensity"), "50%")
        closeMenu()
    }

    func testHideAndShowFlipTheMenuTitle() {
        openMenu()
        clickMenuItem("Hide Circle")

        openMenu()
        XCTAssertTrue(menuItem("Show Circle").exists, "Title should flip once hidden")
        XCTAssertFalse(menuItem("Hide Circle").exists)
        clickMenuItem("Show Circle")

        openMenu()
        XCTAssertTrue(menuItem("Hide Circle").exists)
        closeMenu()
    }

    func testRightClickAnimationChangeShowsInMenuAndSurvivesRelaunch() {
        openMenu()
        XCTAssertTrue(menuItem("Right Click").title.contains("Pulse"), "Default right click is Pulse")
        closeMenu()

        chooseAnimation("Flash", for: "Right Click")

        openMenu()
        XCTAssertTrue(menuItem("Right Click").title.contains("Flash"), "Badge should show the new choice")
        XCTAssertTrue(menuItem("Left Click").title.contains("Ripple"), "Left click must be untouched")
        closeMenu()

        relaunchKeepingSettings()
        openMenu()
        XCTAssertTrue(menuItem("Right Click").title.contains("Flash"), "Choice should survive a relaunch")
        closeMenu()
    }

    func testDraggingSizeSliderUpdatesReadoutAndSurvivesRelaunch() throws {
        openMenu()
        let slider = app.sliders["Size"]
        XCTAssertTrue(slider.waitForExistence(timeout: 5))
        XCTAssertEqual(sliderReadout("Size"), "184 pt")

        slider.adjust(toNormalizedSliderPosition: 1.0)
        // XCUITest lands near, not exactly on, the end of the track.
        let readout = sliderReadout("Size")
        let shown = try XCTUnwrap(Int(readout.replacingOccurrences(of: " pt", with: "")))
        XCTAssertGreaterThan(shown, 700, "Readout should follow the slider live, got \(readout)")
        closeMenu()

        relaunchKeepingSettings()
        openMenu()
        XCTAssertEqual(sliderReadout("Size"), readout, "Size should survive a relaunch")
        closeMenu()
    }

    func testResetToDefaultsRestoresSliders() {
        openMenu()
        app.sliders["Thickness"].adjust(toNormalizedSliderPosition: 1.0)
        XCTAssertNotEqual(sliderReadout("Thickness"), "6 pt")
        closeMenu()

        openMenu()
        clickMenuItem("Reset to Defaults")

        openMenu()
        XCTAssertEqual(sliderReadout("Thickness"), "6 pt")
        XCTAssertEqual(sliderReadout("Size"), "184 pt")
        closeMenu()
    }

    func testChoosingColourOpensTheColourPanel() {
        openMenu()
        clickMenuItem("Colour…")
        let panel = app.windows.matching(NSPredicate(format: "title BEGINSWITH[c] 'colo'")).firstMatch
        XCTAssertTrue(panel.waitForExistence(timeout: 5), "The system colour panel should open")
    }

    func testShortcutCanBeClearedRecordedAndSurvivesRelaunch() {
        openShortcutWindow()
        let recorder = shortcutWindow.buttons["Shortcut"]
        XCTAssertEqual(recorder.value as? String, "⌃⌥⌘M")

        shortcutWindow.buttons["Clear"].click()
        XCTAssertEqual(recorder.value as? String, "Click to record")

        recorder.click()
        XCTAssertEqual(recorder.value as? String, "Type shortcut…")
        app.typeKey("k", modifierFlags: [.control, .option, .command])
        XCTAssertEqual(recorder.value as? String, "⌃⌥⌘K")
        shortcutWindow.buttons["Done"].click()

        relaunchKeepingSettings()
        openShortcutWindow()
        XCTAssertEqual(shortcutWindow.buttons["Shortcut"].value as? String, "⌃⌥⌘K", "Shortcut should survive a relaunch")
    }

    func testShortcutKeyHidesAndShowsTheCircle() {
        // The default shortcut is registered system-wide; pressing it flips the menu title.
        app.typeKey("m", modifierFlags: [.control, .option, .command])
        openMenu()
        XCTAssertTrue(menuItem("Show Circle").waitForExistence(timeout: 5), "Shortcut should have hidden the circle")
        closeMenu()

        app.typeKey("m", modifierFlags: [.control, .option, .command])
        openMenu()
        XCTAssertTrue(menuItem("Hide Circle").waitForExistence(timeout: 5))
        closeMenu()
    }
}

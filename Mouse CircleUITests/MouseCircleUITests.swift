import XCTest

/// True end-to-end: launches the app and drives it through the menu bar like a user.
/// Needs Xcode's UI testing permission the first time it runs.
final class MouseCircleUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    override func tearDown() {
        app.terminate()
    }

    private func openMenu() -> XCUIElement {
        let statusItem = app.statusItems.firstMatch
        XCTAssertTrue(statusItem.waitForExistence(timeout: 5), "Menu bar item should appear")
        statusItem.click()
        return statusItem
    }

    func testMenuBarMenuListsTheControls() {
        _ = openMenu()
        XCTAssertTrue(app.menuItems["Hide Circle"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.menuItems["Colour…"].exists)
        XCTAssertTrue(app.menuItems["Quit Mouse Circle"].exists)
        app.typeKey(.escape, modifierFlags: [])
    }

    func testChoosingColourOpensTheColourPanel() {
        _ = openMenu()
        let colour = app.menuItems["Colour…"]
        XCTAssertTrue(colour.waitForExistence(timeout: 5))
        colour.click()
        let panel = app.windows.matching(NSPredicate(format: "title BEGINSWITH[c] 'colo'")).firstMatch
        XCTAssertTrue(panel.waitForExistence(timeout: 5), "The system colour panel should open")
    }

    func testKeyboardShortcutWindowOpens() {
        _ = openMenu()
        let item = app.menuItems["Keyboard Shortcut…"]
        XCTAssertTrue(item.waitForExistence(timeout: 5))
        item.click()
        XCTAssertTrue(app.windows["Keyboard Shortcut"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.windows["Keyboard Shortcut"].buttons["Done"].exists)
    }
}

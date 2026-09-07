import XCTest
@testable import MouseCircle

final class CircleConfigurationTests: XCTestCase {
    func testRoundTripThroughJSON() throws {
        var original = CircleConfiguration()
        original.size = 250
        original.thickness = 3
        original.intensity = 0.8
        original.leftClickAnimation = .pulse
        original.rightClickAnimation = .none
        original.color = NSColor(srgbRed: 0.1, green: 0.2, blue: 0.3, alpha: 0.4)
        original.shortcut = HotKey(keyCode: 96, modifierFlags: [.shift], keyEquivalent: "\u{F708}")

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(CircleConfiguration.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    func testMissingKeysFallBackToDefaults() throws {
        let data = Data(#"{"size": 400}"#.utf8)
        let decoded = try JSONDecoder().decode(CircleConfiguration.self, from: data)
        XCTAssertEqual(decoded.size, 400)
        XCTAssertEqual(decoded.thickness, AppConstants.Circle.defaultThickness)
        XCTAssertEqual(decoded.shortcut, HotKey.default, "Older saves without a shortcut should get the default one")
    }

    func testLegacySingleAnimationBecomesLeftClick() throws {
        let data = Data(#"{"animation": "pulse"}"#.utf8)
        let decoded = try JSONDecoder().decode(CircleConfiguration.self, from: data)
        XCTAssertEqual(decoded.leftClickAnimation, .pulse)
        XCTAssertEqual(decoded.rightClickAnimation, CircleConfiguration().rightClickAnimation)
    }

    func testClearedShortcutStaysCleared() throws {
        var configuration = CircleConfiguration()
        configuration.shortcut = nil
        let data = try JSONEncoder().encode(configuration)
        let decoded = try JSONDecoder().decode(CircleConfiguration.self, from: data)
        XCTAssertNil(decoded.shortcut)
    }

    func testGarbageInDefaultsFallsBackToDefaults() {
        let defaults = UserDefaults(suiteName: "MouseCircleTests")!
        defaults.set(Data("not json".utf8), forKey: AppConstants.Storage.configurationKey)
        XCTAssertEqual(CircleConfiguration.load(from: defaults), CircleConfiguration())
        defaults.removePersistentDomain(forName: "MouseCircleTests")
    }
}

final class HotKeyTests: XCTestCase {
    func testDisplayStrings() {
        XCTAssertEqual(HotKey.default.displayString, "⌃⌥⌘M")
        XCTAssertEqual(HotKey(keyCode: 96, modifierFlags: [.shift], keyEquivalent: "\u{F708}").displayString, "⇧F5")
        XCTAssertEqual(HotKey(keyCode: 49, modifierFlags: [.command], keyEquivalent: " ").displayString, "⌘Space")
    }

    func testFunctionKeyDetection() {
        XCTAssertTrue(HotKey(keyCode: 96, modifierFlags: [], keyEquivalent: "\u{F708}").isFunctionKey)
        XCTAssertFalse(HotKey.default.isFunctionKey)
    }

    func testOnlyRelevantModifiersAreKept() {
        let hotKey = HotKey(keyCode: 0, modifierFlags: [.command, .capsLock, .function], keyEquivalent: "a")
        XCTAssertEqual(hotKey.modifierFlags, [.command])
    }
}

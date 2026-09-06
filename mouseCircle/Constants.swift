import AppKit

/// App-wide tunables. Everything user-adjustable has its default here.
enum AppConstants {
    enum Circle {
        static let defaultSize: Double = 184
        static let sizeRange: ClosedRange<Double> = 30...800
        static let defaultThickness: Double = 6
        static let thicknessRange: ClosedRange<Double> = 1...30
        /// Stored as sRGB components so the default survives round-tripping through UserDefaults.
        static let defaultColor = NSColor(srgbRed: 0.20, green: 0.78, blue: 0.35, alpha: 0.5)
    }

    enum Animation {
        static let defaultIntensity: Double = 0.5
        static let intensityRange: ClosedRange<Double> = 0...1
        /// How long the expanding ripple ring is visible after a click.
        static let rippleDuration: TimeInterval = 0.35
        /// Extra scale the ripple reaches at full intensity (2.0 = grows to 3x the circle).
        static let rippleMaxScale: CGFloat = 2.0
        /// How long the pulse takes to shrink or grow back.
        static let pulseDuration: TimeInterval = 0.12
    }

    enum Window {
        /// The shielding level sits above full-screen apps, menus, the Dock, the menu bar
        /// and the screen saver, so the circle is visible over everything on screen.
        static let overlayLevel = NSWindow.Level(rawValue: Int(CGShieldingWindowLevel()))
        static let collectionBehavior: NSWindow.CollectionBehavior = [
            .canJoinAllSpaces,      // Follow the user across Spaces
            .fullScreenAuxiliary,   // Show over other apps' full-screen windows
            .stationary,            // Don't get swept up by Mission Control
            .ignoresCycle           // Never appear in Cmd-` window cycling
        ]
    }

    enum Timing {
        /// Display changes arrive in bursts; wait for them to settle before rebuilding windows.
        static let screenChangeDebounce: TimeInterval = 0.4
        /// While our own menu is open no mouse events reach us, so we poll instead.
        static let menuPollingInterval: TimeInterval = 1.0 / 60.0
        /// A shortcut held longer than this is a "hold", which flips the circle back on release.
        static let shortcutHoldThreshold: TimeInterval = 0.4
    }

    enum MenuBar {
        static let iconName = "circle.circle"
        static let hiddenIconName = "circle.dashed"
        static let accessibilityDescription = "Mouse Circle"
    }

    enum Storage {
        static let configurationKey = "circleConfiguration"
    }
}

/// The visual effect played when the mouse button is clicked.
enum AnimationType: String, CaseIterable, Codable {
    case ripple
    case pulse

    var displayName: String {
        switch self {
        case .ripple: return "Ripple"
        case .pulse: return "Pulse"
        }
    }
}

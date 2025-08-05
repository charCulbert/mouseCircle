import Foundation
import AppKit

// MARK: - Application Constants
// App constants and configuration values

struct AppConstants {
    
    // MARK: - Timing Constants (in seconds)
    // Timing delays and frame rates
    
    struct Timing {
        static let screenChangeDebounceDelay: TimeInterval = 0.3        // Wait time before processing screen changes
        static let windowRecreationDelay: TimeInterval = 0.1           // Delay before recreating windows after cleanup
        static let mouseTrackingReenableDelay: TimeInterval = 0.2      // Delay before re-enabling mouse tracking
        static let animationFrameRate: TimeInterval = 1.0 / 60.0       // 60 FPS for smooth animations (16.67ms per frame)
    }
    
    // MARK: - Animation Settings
    // Animation durations and scaling
    
    struct Animation {
        static let rippleDuration: TimeInterval = 0.3        // How long the ripple effect lasts
        static let pulseDuration: TimeInterval = 0.15        // How long the pulse effect lasts
        static let rippleMaxScale: CGFloat = 2.0             // Maximum size multiplier for ripple effect (200% growth)
        static let pulseMaxScale: CGFloat = 1.0              // Maximum size multiplier for pulse effect
        static let defaultIntensity: CGFloat = 0.5           // Default animation intensity (50% of slider range 0.1-1.0)
    }
    
    // MARK: - Window Configuration
    // Window overlay settings
    
    struct Window {
        // Window level above pop-up menus so circle is always visible
        static let overlayLevel = NSWindow.Level(rawValue: NSWindow.Level.popUpMenu.rawValue + 2)
        
        // Window space and mode behavior
        static let collectionBehavior: NSWindow.CollectionBehavior = [
            .canJoinAllSpaces,      // Appears on all desktop spaces
            .fullScreenAuxiliary,   // Shows in full-screen mode
            .stationary            // Doesn't move when user switches spaces
        ]
        
        static let releaseWhenClosed = false    // Keep window in memory when closed (for proper ARC management)
    }
    
    // MARK: - Circle Display Settings
    // Default values for how the circle looks and behaves
    
    struct Circle {
        static let defaultSize: CGFloat = 184.0              // Default circle diameter in pixels (20% of slider range 30-800)
        static let defaultThickness: CGFloat = 6.0           // Default line thickness in pixels (30% of slider range 1-20)
        static let minimumValidScreenSize: CGFloat = 0       // Minimum screen dimension to be considered valid
    }
    
    // MARK: - Color Definitions
    
    struct Colors {
        static let defaultColor = NSColor.systemGreen.withAlphaComponent(0.5)
    }
    
    // MARK: - Menu Bar Settings
    // Menu bar configuration
    
    struct MenuBar {
        static let statusItemLength = NSStatusItem.squareLength    // Standard square size for menu bar icon
        static let iconName = "circle"                            // SF Symbol name for the menu bar icon
        static let iconAccessibilityDescription = "Mouse Circle"   // Screen reader description
    }
}

// MARK: - Animation Types
// Available animation styles

enum AnimationType: String, CaseIterable {
    case singleRipple = "Ripple"           // One expanding ring on click
    case pulseOnClick = "Pulse"            // Circle briefly grows and shrinks on click
    
    // Helper to get user-friendly display name
    var displayName: String {
        return self.rawValue
    }
}

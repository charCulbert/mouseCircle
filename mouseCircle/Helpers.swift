import Foundation
import AppKit

// MARK: - Helper Functions
// Utility functions

struct WindowHelpers {
    
    // MARK: - Window Validation
    // Check if a window is valid and safe to use
    
    /**
     * Determines if a window is valid and can be safely used
     * A valid window must:
     * 1. Have an associated screen (not disconnected)
     * 2. Be visible to the user
     * 3. Have a screen with valid dimensions
     */
    static func isValidWindow(_ window: NSWindow) -> Bool {
        // Check if window has a screen (nil means screen was disconnected)
        guard let screen = window.screen else { 
            return false 
        }
        
        // Check if window is visible and screen has valid dimensions
        let hasValidScreen = screen.frame.width > AppConstants.Circle.minimumValidScreenSize && 
                           screen.frame.height > AppConstants.Circle.minimumValidScreenSize
        
        return window.isVisible && hasValidScreen
    }
    
    /**
     * Get all windows that are currently valid and safe to use
     * Filters out any windows that have been disconnected or are otherwise invalid
     */
    static func getValidWindows(from windows: [NSWindow]) -> [NSWindow] {
        return windows.filter { window in
            return isValidWindow(window)
        }
    }
    
    // MARK: - Window Configuration
    // Set up window properties for overlay display
    
    /**
     * Configure a window to be a transparent overlay that appears above other windows
     * This makes the window:
     * - Transparent background
     * - Click-through (doesn't intercept mouse clicks)
     * - Always on top
     * - Appears on all desktop spaces
     */
    static func configureAsOverlay(_ window: NSWindow) {
        // Set window level to appear above pop-up menus
        window.level = AppConstants.Window.overlayLevel
        
        // Configure window behavior for all spaces and full-screen
        window.collectionBehavior = AppConstants.Window.collectionBehavior
        
        // Make window transparent and non-interactive
        window.backgroundColor = NSColor.clear       // Transparent background
        window.isOpaque = false                     // Allows transparency
        window.ignoresMouseEvents = true            // Click-through to apps below
        window.hasShadow = false                    // No window shadow
        window.acceptsMouseMovedEvents = false      // Don't track mouse movement over window
        
        // Proper memory management for ARC
        window.isReleasedWhenClosed = AppConstants.Window.releaseWhenClosed
    }
}

// MARK: - Coordinate Helpers
// Coordinate conversion functions

struct CoordinateHelpers {
    
    /**
     * Convert screen coordinates to window-local coordinates
     * macOS uses different coordinate systems:
     * - Screen coordinates: Origin at bottom-left of primary screen
     * - Window coordinates: Origin at bottom-left of the window
     */
    static func convertScreenToWindow(screenPoint: NSPoint, window: NSWindow) -> CGPoint {
        return CGPoint(
            x: screenPoint.x - window.frame.origin.x,
            y: screenPoint.y - window.frame.origin.y
        )
    }
    
    /**
     * Get the current mouse position in screen coordinates
     * This is a global position that works across all displays
     */
    static func getCurrentMouseLocation() -> NSPoint {
        return NSEvent.mouseLocation
    }
}

// MARK: - Screen Helpers
// Screen and display functions

struct ScreenHelpers {
    
    /**
     * Get all currently available screens with valid dimensions
     * Filters out any screens that might be in the process of disconnecting
     */
    static func getAvailableScreens() -> [NSScreen] {
        return NSScreen.screens.filter { screen in
            return screen.frame.width > AppConstants.Circle.minimumValidScreenSize && 
                   screen.frame.height > AppConstants.Circle.minimumValidScreenSize
        }
    }
    
    /**
     * Check if the screen configuration has changed by counting screens
     * Returns true if the number of screens is different from expected
     */
    static func hasScreenCountChanged(expectedCount: Int) -> Bool {
        let currentCount = NSScreen.screens.count
        return currentCount != expectedCount
    }
}

// MARK: - Threading Helpers
// Main thread execution helpers

struct ThreadingHelpers {
    
    /**
     * Execute code on the main thread safely
     * If already on main thread, executes immediately
     * If on background thread, dispatches to main thread
     */
    static func executeOnMainThread(_ closure: @escaping () -> Void) {
        if Thread.isMainThread {
            closure()
        } else {
            DispatchQueue.main.async {
                closure()
            }
        }
    }
    
    /**
     * Execute code on main thread after a delay
     * Useful for debouncing rapid events or allowing cleanup to complete
     */
    static func executeOnMainThreadAfterDelay(_ delay: TimeInterval, _ closure: @escaping () -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            closure()
        }
    }
    
    /**
     * Execute code with automatic memory management
     * This prevents memory buildup during frequent operations like mouse tracking
     */
    static func executeWithAutorelease<T>(_ closure: () -> T) -> T {
        return autoreleasepool {
            return closure()
        }
    }
}

// MARK: - Animation Helpers
// Animation utilities

struct AnimationHelpers {
    
    /**
     * Calculate the scale factor for animation at a given time
     * Used for smooth scaling animations like ripples and pulses
     */
    static func calculateAnimationScale(
        progress: Double,           // Animation progress from 0.0 to 1.0
        maxScale: CGFloat,         // Maximum scale to reach
        animationType: AnimationType
    ) -> CGFloat {
        switch animationType {
        case .singleRipple:
            // Linear growth for ripple effect
            return 1.0 + (maxScale - 1.0) * CGFloat(progress)
            
        case .pulseOnClick:
            // Ease-in-out for pulse effect (smooth acceleration and deceleration)
            let easedProgress = easeInOut(progress)
            return 1.0 + (maxScale - 1.0) * CGFloat(easedProgress)
        }
    }
    
    /**
     * Ease-in-out function for smooth animation curves
     * Makes animations feel more natural by accelerating at start and decelerating at end
     */
    private static func easeInOut(_ t: Double) -> Double {
        return t < 0.5 ? 2 * t * t : -1 + (4 - 2 * t) * t
    }
}
import AppKit

/**
 * WindowManager: Handles creating and managing overlay windows across all displays
 * 
 * This class is responsible for:
 * 1. Creating transparent overlay windows on each connected display
 * 2. Managing window lifecycle when displays are connected/disconnected  
 * 3. Updating circle positions as the mouse moves
 * 4. Coordinating animations across all windows
 * 
 * Think of this as the "display controller" that manages multiple "screens"
 * Similar to having multiple monitors in a multi-monitor setup
 */
class WindowManager {
    // MARK: - Properties
    
    /// All overlay windows currently being managed (one per display)
    private var circleWindows: [NSWindow] = []
    
    /// Reference back to main app coordinator (weak to prevent memory cycles)
    private weak var appDelegate: AppDelegate?
    
    /// Window delegates that handle individual window events (one per window)
    private var windowDelegates: [WindowDelegate] = []
    
    /// Flag to prevent multiple simultaneous window recreation operations
    private var isRecreating = false
    
    // MARK: - Initialization
    
    /**
     * Initialize the window manager with a reference to the main app coordinator
     * @param appDelegate: The main app coordinator that manages overall app state
     */
    init(appDelegate: AppDelegate) {
        self.appDelegate = appDelegate
    }
    
    // MARK: - Window Creation
    
    /**
     * Create overlay windows on all available displays
     * This creates one transparent window per display to show the circle overlay
     */
    func setupWindows() {
        // Get all displays that are currently connected and working
        let availableScreens = ScreenHelpers.getAvailableScreens()
        
        // Create one overlay window for each display
        for screen in availableScreens {
            ThreadingHelpers.executeWithAutorelease {
                // Create a borderless window that covers the entire screen
                let window = NSWindow(
                    contentRect: screen.frame,           // Cover entire screen
                    styleMask: [.borderless],           // No title bar or borders
                    backing: .buffered,                 // Use buffered drawing for performance
                    defer: false                        // Create window immediately
                )
                
                // Configure window as transparent overlay
                WindowHelpers.configureAsOverlay(window)
                
                // Create the circle view that will draw our mouse circle
                let circleView = CircleView()
                window.contentView = circleView
                
                // Apply current configuration immediately to new view
                if let config = appDelegate?.configuration {
                    circleView.update(with: config)
                }
                
                // Set up delegate to handle window events (like screen disconnection)
                let windowDelegate = WindowDelegate(windowManager: self)
                window.delegate = windowDelegate
                windowDelegates.append(windowDelegate)
                
                // Show the window and add to our tracking array
                window.orderFront(nil)
                circleWindows.append(window)
                
                // Position circle at current mouse location
                let mouseLocation = CoordinateHelpers.getCurrentMouseLocation()
                let windowLocation = CoordinateHelpers.convertScreenToWindow(
                    screenPoint: mouseLocation, 
                    window: window
                )
                circleView.updatePosition(windowLocation)
            }
        }
        
        // Apply current configuration to all newly created windows
        updateAllViews()
    }
    
    /**
     * Completely recreate all windows (used when display configuration changes)
     * This safely closes all existing windows and creates new ones for current displays
     */
    func recreateWindows() {
        // Prevent multiple recreation operations from running simultaneously
        guard !isRecreating else { return }
        isRecreating = true
        
        ThreadingHelpers.executeOnMainThread { [weak self] in
            guard let self = self else { return }
            defer { self.isRecreating = false }
            
            // Close all existing windows safely
            self.closeAllWindows()
            
            // Wait briefly for cleanup to complete, then recreate windows
            ThreadingHelpers.executeOnMainThreadAfterDelay(AppConstants.Timing.windowRecreationDelay) {
                self.setupWindows()
                self.updateAllViews()
            }
        }
    }
    
    /**
     * Remove windows that are no longer valid (e.g., screen was disconnected)
     * This safely cleans up windows whose displays have been disconnected
     */
    private func removeInvalidWindows() {
        ThreadingHelpers.executeWithAutorelease {
            // Find windows that are no longer valid
            let invalidWindows = circleWindows.filter { window in
                return !WindowHelpers.isValidWindow(window)
            }
            
            // Safely close each invalid window
            for window in invalidWindows {
                closeWindowSafely(window)
            }
            
            // Remove invalid windows from our tracking arrays
            circleWindows.removeAll { window in
                return !WindowHelpers.isValidWindow(window)
            }
        }
    }
    
    /**
     * Safely close all managed windows
     * This properly cleans up all windows and their associated delegates
     */
    private func closeAllWindows() {
        ThreadingHelpers.executeWithAutorelease {
            let windowsToClose = circleWindows
            circleWindows.removeAll()
            windowDelegates.removeAll()
            
            // Close each window safely
            for window in windowsToClose {
                closeWindowSafely(window)
            }
        }
    }
    
    /**
     * Safely close a single window with proper cleanup
     * This prevents crashes by cleaning up delegates and references properly
     */
    private func closeWindowSafely(_ window: NSWindow) {
        // Critical: nil the delegate first to prevent crashes during cleanup
        window.delegate = nil
        window.contentView = nil
        
        // Hide window if it's currently visible
        if window.isVisible {
            window.orderOut(nil)
        }
        
        // Close the window
        window.close()
    }
    
    // MARK: - Cleanup
    
    /**
     * Clean up all resources when app is shutting down
     * This ensures proper memory cleanup and prevents crashes on quit
     */
    func cleanup() {
        closeAllWindows()
        appDelegate = nil
    }
    
    // MARK: - Window Delegate Callbacks
    // These methods are called by WindowDelegate when window events occur
    
    /**
     * Handle when a window loses its screen (display disconnected)
     * This safely removes the window from our tracking and closes it
     * @param window: The window that lost its screen
     */
    func handleWindowScreenDisconnected(_ window: NSWindow) {
        ThreadingHelpers.executeOnMainThread { [weak self] in
            guard let self = self else { return }
            
            // Find and remove the window from our tracking arrays
            if let index = self.circleWindows.firstIndex(of: window) {
                self.circleWindows.remove(at: index)
                if index < self.windowDelegates.count {
                    self.windowDelegates.remove(at: index)
                }
            }
            
            // Safely close the disconnected window
            self.closeWindowSafely(window)
        }
    }
    
    /**
     * Handle when a window is about to close
     * This removes the window from our tracking arrays
     * @param window: The window that is closing
     */
    func handleWindowWillClose(_ window: NSWindow) {
        // Find and remove the window from our tracking arrays
        if let index = circleWindows.firstIndex(of: window) {
            circleWindows.remove(at: index)
            if index < windowDelegates.count {
                windowDelegates.remove(at: index)
            }
        }
    }
    
    // MARK: - View Updates
    
    /**
     * Update the appearance of all circle views with current configuration
     * This applies color, size, opacity changes to all visible circles
     */
    func updateAllViews() {
        // Get current configuration from app coordinator
        guard let config = appDelegate?.configuration else { return }
        
        // Only update windows that are currently valid and visible
        let validWindows = WindowHelpers.getValidWindows(from: circleWindows)
        
        // Apply configuration to each circle view
        for window in validWindows {
            if let circleView = window.contentView as? CircleView {
                circleView.update(with: config)
            }
        }
    }
    
    /**
     * Update circle position on all displays when mouse moves
     * @param screenLocation: Mouse position in global screen coordinates
     */
    func updateMousePosition(_ screenLocation: NSPoint) {
        ThreadingHelpers.executeWithAutorelease {
            // Only update valid windows to avoid crashes
            let validWindows = WindowHelpers.getValidWindows(from: circleWindows)
            
            // Update circle position in each window
            for window in validWindows {
                if let circleView = window.contentView as? CircleView {
                    // Convert global screen coordinates to window-local coordinates
                    let windowLocation = CoordinateHelpers.convertScreenToWindow(
                        screenPoint: screenLocation,
                        window: window
                    )
                    circleView.updatePosition(windowLocation)
                }
            }
        }
    }
    
    /**
     * Start animation on all circle views
     * @param isDown: true when mouse button pressed, false when released
     */
    func startAnimation(isDown: Bool) {
        // Only animate valid windows
        let validWindows = WindowHelpers.getValidWindows(from: circleWindows)
        
        // Start animation on each circle view
        for window in validWindows {
            if let circleView = window.contentView as? CircleView {
                circleView.startAnimation(isDown: isDown)
            }
        }
    }
    
    // Note: Window configuration is now handled by WindowHelpers.configureAsOverlay()
    // This keeps all window setup logic in one clear place
}

import SwiftUI
import AppKit

/**
 * AppDelegate: Main application coordinator and entry point
 * 
 * This class manages the entire application:
 * 1. Sets up the menu bar interface
 * 2. Manages mouse tracking across the system
 * 3. Coordinates with WindowManager to display the circle
 * 4. Handles display configuration changes (monitors plugged/unplugged)
 * 5. Manages application lifecycle
 * 
 */
class AppDelegate: NSObject, NSApplicationDelegate {
    // MARK: - Properties
    
    /// The menu bar icon
    var statusItem: NSStatusItem?
    
    /// Manages the dropdown menu interface
    private var menuManager: MenuManager?
    
    /// Manages overlay windows
    var windowManager: WindowManager?
    
    /// System-wide mouse tracking observers
    private var mouseLocationObserver: Any?    // Tracks mouse movement and clicks from other apps
    private var localMouseObserver: Any?       // Tracks mouse events within our app
    
    /// Mouse state tracking
    private var isClicked = false             // Whether mouse button is currently down
    private var clickTimer: Timer?            // Timer for click animations
    private var isMenuOpen = false            // Whether our menu is currently open
    
    /// Screen change management
    private var isRecreatingWindows = false  // Prevents launching multiple simultaneous window recreation operations
    
    /// Current circle configuration (size, color, opacity, etc.)
    /// When this changes, automatically update all circle views
    var configuration = CircleConfiguration() {
        didSet { 
            windowManager?.updateAllViews() 
        }
    }

    // MARK: - Public Interface
    
    /**
     * Reset mouse down state (for menu interactions)
     */
    func resetMouseState() {
        isMenuOpen = true
        isClicked = false
        // Don't start animations during menu operations
    }
    
    /**
     * Called when menu closes
     */
    func menuDidClose() {
        isMenuOpen = false
        isClicked = false
        // Don't start animations when menu closes - only actual mouse interactions should trigger animations
    }
    
    /**
     * Check if this mouse event is a slider interaction we should ignore
     */
    private func isSliderInteraction(_ event: NSEvent) -> Bool {
        // If it's our menu and the menu is open, it's likely a slider
        if isMenuOpen {
            return true
        }
        
        // If it's the color picker opacity slider specifically
        if let window = event.window, window == NSColorPanel.shared {
            // Only block opacity slider, not clicks on color areas
            let location = event.locationInWindow
            // Color picker opacity slider is typically at the bottom
            return location.y < 50  // Rough estimate of slider area
        }
        
        return false
    }
    
    // MARK: - Application Lifecycle
    
    /**
     * Called when the app finishes launching
     * Initialize all the main components
     */
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Create the main component managers
        windowManager = WindowManager(appDelegate: self)
        menuManager = MenuManager(appDelegate: self)
        
        // Set up the user interface and functionality
        setupMenuBar()                    // Create menu bar icon and dropdown
        windowManager?.setupWindows()     // Create overlay windows on all displays
        
        // Apply initial configuration to all windows
        windowManager?.updateAllViews()
        
        setupMouseTracking()             // Start monitoring mouse movements
        setupScreenChangeNotifications() // Listen for display changes
    }

    // MARK: - Menu Bar Setup
    
    /**
     * Create the menu bar icon and dropdown menu
     * This creates the small icon that appears in the top-right menu bar
     */
    private func setupMenuBar() {
        // Create a menu bar item with standard square size
        statusItem = NSStatusBar.system.statusItem(withLength: AppConstants.MenuBar.statusItemLength)
        
        // Set the icon image
        if let button = statusItem?.button {
            button.image = NSImage(
                systemSymbolName: AppConstants.MenuBar.iconName,
                accessibilityDescription: AppConstants.MenuBar.iconAccessibilityDescription
            )
        }
        
        // Attach the dropdown menu to the menu bar item
        statusItem?.menu = menuManager?.createMenu()
    }

    // MARK: - Mouse Tracking
    
    /**
     * Set up system-wide mouse tracking
     * This monitors mouse movements and clicks across all applications
     */
    func setupMouseTracking() {
        // Don't set up tracking if it's already active
        guard mouseLocationObserver == nil else { return }
        
        // Monitor mouse events from other apps
        // Catches mouse movement when app doesn't have focus
        mouseLocationObserver = NSEvent.addGlobalMonitorForEvents(
            matching: [.mouseMoved, .leftMouseDown, .leftMouseUp, .leftMouseDragged]
        ) { [weak self] event in
            self?.handleMouseEvent(event)
        }
        
        // Monitor mouse events within the app
        localMouseObserver = NSEvent.addLocalMonitorForEvents(
            matching: [.mouseMoved, .leftMouseDown, .leftMouseUp, .leftMouseDragged]
        ) { [weak self] event in
            // Don't track clicks on menu bar item
            if let statusItem = self?.statusItem, 
               let button = statusItem.button,
               let window = event.window,
               window == button.window,
               event.type != .mouseMoved && event.type != .leftMouseDragged {
                return event
            }
            
            self?.handleMouseEvent(event)
            return event  // Pass the event through to the system
        }
        
        // Position circle at current mouse location
        ThreadingHelpers.executeOnMainThread { [weak self] in
            let screenLocation = CoordinateHelpers.getCurrentMouseLocation()
            self?.windowManager?.updateMousePosition(screenLocation)
        }
    }
    
    /**
     * Process mouse events from the system
     * This is called whenever the mouse moves or clicks anywhere on screen
     * @param event: The mouse event from the system
     */
    private func handleMouseEvent(_ event: NSEvent) {
        ThreadingHelpers.executeWithAutorelease {
            guard let windowManager = self.windowManager else { return }
            
            let screenLocation = CoordinateHelpers.getCurrentMouseLocation()
            
            // Handle mouse events
            switch event.type {
            case .mouseMoved, .leftMouseDragged:
                // Update circle position
                windowManager.updateMousePosition(screenLocation)
                
            case .leftMouseDown:
                // Handle clicks unless it's a slider
                if !self.isSliderInteraction(event) {
                    self.handleMouseDown()
                }
                
            case .leftMouseUp:
                // Handle releases unless it's a slider
                if !self.isSliderInteraction(event) {
                    self.handleMouseUp()
                }
                
            default:
                // Ignore other events
                break
            }
        }
    }
    
    /**
     * Handle mouse button press
     * Start the click animation
     */
    private func handleMouseDown() {
        isClicked = true
        clickTimer?.invalidate()  // Cancel any existing click timer
        windowManager?.startAnimation(isDown: true)
    }
    
    /**
     * Handle mouse button release  
     * End the click animation
     **/
    
    private func handleMouseUp() {
        isClicked = false
        windowManager?.startAnimation(isDown: false)
    }
    
    // MARK: - Display Management
    
    /**
     * Set up notifications for display configuration changes
     * This listens for when monitors are plugged in, unplugged, or reconfigured
     */
    private func setupScreenChangeNotifications() {
        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,  // System notification
            object: nil,                                                   // Listen to all objects
            queue: .main                                                   // Handle on main thread
        ) { [weak self] _ in
            self?.screenConfigurationChanged()
        }
    }
    
    /**
     * Handle when display configuration changes (monitors added/removed/reconfigured)
     * This safely recreates all overlay windows for the new display setup
     */
    private func screenConfigurationChanged() {
        // Prevent multiple screen change operations
        guard !isRecreatingWindows else { return }
        isRecreatingWindows = true
        
        // Stop mouse tracking during window recreation
        removeMouseTracking()
        
        // Wait for screen changes to stabilize
        ThreadingHelpers.executeOnMainThreadAfterDelay(AppConstants.Timing.screenChangeDebounceDelay) { [weak self] in
            guard let self = self else { return }
            guard self.isRecreatingWindows else { return }
            
            // Recreate overlay windows
            self.windowManager?.recreateWindows()
            
            // Re-enable mouse tracking
            ThreadingHelpers.executeOnMainThreadAfterDelay(AppConstants.Timing.mouseTrackingReenableDelay) { [weak self] in
                guard let self = self else { return }
                self.setupMouseTracking()
                self.isRecreatingWindows = false
            }
        }
    }
    
    /**
     * Stop monitoring mouse events
     * This is called during screen changes to prevent crashes
     */
    private func removeMouseTracking() {
        // Remove global mouse event monitoring
        if let observer = mouseLocationObserver {
            NSEvent.removeMonitor(observer)
            mouseLocationObserver = nil
        }
        
        // Remove local mouse event monitoring
        if let observer = localMouseObserver {
            NSEvent.removeMonitor(observer)
            localMouseObserver = nil
        }
    }
    
    /**
     * Called when the application is about to quit
     * Clean up all resources
     */
    func applicationWillTerminate(_ notification: Notification) {
        // Stop mouse tracking
        removeMouseTracking()
        
        // Clean up window manager and close all windows
        windowManager?.cleanup()
        windowManager = nil
        
        // Clean up menu manager
        menuManager = nil
        
        // Remove all notification observers
        NotificationCenter.default.removeObserver(self)
    }
}

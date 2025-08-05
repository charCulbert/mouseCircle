import AppKit

/**
 * WindowDelegate: Handles events for individual overlay windows
 * 
 * This class monitors each overlay window for important events:
 * 1. When the window's display gets disconnected (monitor unplugged)
 * 2. When the window is about to close
 * 
 * Think of this as an "event handler" for each window, similar to:
 * - Event listeners in JavaScript
 * - Signal handlers in Qt/C++
 * - Callback functions in other frameworks
 * 
 * Each window gets its own instance of this delegate
 */
class WindowDelegate: NSObject, NSWindowDelegate {
    // MARK: - Properties
    
    /// Reference back to the window manager (weak to prevent memory cycles)
    weak var windowManager: WindowManager?
    
    // MARK: - Initialization
    
    /**
     * Create a new window delegate
     * @param windowManager: The manager that handles all windows
     */
    init(windowManager: WindowManager) {
        self.windowManager = windowManager
        super.init()
    }
    
    // MARK: - Window Event Handlers
    
    /**
     * Called when a window changes screens (moves between displays)
     * This is particularly important when displays are disconnected
     * @param notification: System notification containing the window that changed
     */
    func windowDidChangeScreen(_ notification: Notification) {
        // Extract the window from the notification
        guard let window = notification.object as? NSWindow else { return }
        
        // Check if the window lost its screen (display was disconnected)
        if window.screen == nil {
            // Notify the window manager to handle the disconnected window
            windowManager?.handleWindowScreenDisconnected(window)
        }
    }
    
    /**
     * Called just before a window closes
     * This ensures proper cleanup to prevent crashes
     * @param notification: System notification containing the closing window
     */
    func windowWillClose(_ notification: Notification) {
        // Extract the window from the notification
        guard let window = notification.object as? NSWindow else { return }
        
        // Critical: Remove the delegate reference to prevent crashes
        // This breaks the connection between window and delegate before cleanup
        window.delegate = nil
        
        // Notify the window manager to clean up its tracking
        windowManager?.handleWindowWillClose(window)
    }
}
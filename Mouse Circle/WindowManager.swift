import AppKit

/// A transparent, click-through window that covers one display.
final class OverlayWindow: NSWindow {
    init(screen: NSScreen) {
        super.init(contentRect: screen.frame, styleMask: .borderless, backing: .buffered, defer: false)
        level = AppConstants.Window.overlayLevel
        collectionBehavior = AppConstants.Window.collectionBehavior
        backgroundColor = .clear
        isOpaque = false
        hasShadow = false
        ignoresMouseEvents = true
        isReleasedWhenClosed = false
        // The default sharing type keeps the overlay visible in screenshots and screen recordings.
        contentView = CircleView(frame: contentRect(forFrameRect: screen.frame))
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    /// AppKit normally nudges windows to stay clear of the menu bar; we want to cover the whole display.
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
        frameRect
    }

    var circleView: CircleView? { contentView as? CircleView }
}

/// Owns one overlay window per display and fans out position, click and configuration
/// changes to all of them.
final class WindowManager {
    private(set) var windows: [OverlayWindow] = []
    private var configuration: CircleConfiguration

    /// Hide or show the circle on every display without tearing the windows down.
    var isVisible = true {
        didSet {
            guard isVisible != oldValue else { return }
            for window in windows {
                isVisible ? window.orderFrontRegardless() : window.orderOut(nil)
            }
        }
    }

    init(configuration: CircleConfiguration) {
        self.configuration = configuration
    }

    /// Tear down and recreate a window for each connected display.
    /// Called at launch and whenever displays are added, removed or rearranged.
    func rebuildWindows() {
        closeAllWindows()
        for screen in NSScreen.screens {
            let window = OverlayWindow(screen: screen)
            window.circleView?.apply(configuration)
            if isVisible {
                window.orderFrontRegardless()
            }
            windows.append(window)
        }
        moveCircle(to: NSEvent.mouseLocation)
    }

    func closeAllWindows() {
        for window in windows {
            window.orderOut(nil)
            window.close()
        }
        windows.removeAll()
    }

    func apply(_ configuration: CircleConfiguration) {
        self.configuration = configuration
        for window in windows {
            window.circleView?.apply(configuration)
        }
    }

    /// `screenPoint` is in global screen coordinates, as returned by `NSEvent.mouseLocation`.
    func moveCircle(to screenPoint: NSPoint) {
        forEachCircle(at: screenPoint) { view, point in view.move(to: point) }
    }

    func mousePressed(at screenPoint: NSPoint, button: MouseButton) {
        forEachCircle(at: screenPoint) { view, point in view.mousePressed(at: point, button: button) }
    }

    func mouseReleased(at screenPoint: NSPoint, button: MouseButton) {
        forEachCircle(at: screenPoint) { view, point in view.mouseReleased(at: point, button: button) }
    }

    /// Every display gets the update, with the point converted into that window's coordinates.
    /// A circle that straddles two displays is therefore drawn correctly on both.
    private func forEachCircle(at screenPoint: NSPoint, _ body: (CircleView, CGPoint) -> Void) {
        for window in windows {
            guard let view = window.circleView else { continue }
            body(view, window.convertPoint(fromScreen: screenPoint))
        }
    }
}

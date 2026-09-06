import AppKit

/// Wires everything together: the menu bar item, system-wide mouse tracking,
/// display-change handling and the persisted configuration.
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var menuManager: MenuManager?
    private var windowManager: WindowManager?

    private var eventMonitors: [Any] = []
    private var isMouseDown = false

    private let hotKeyCenter = HotKeyCenter()
    /// When the shortcut went down, or nil while it is up.
    private var shortcutPressedAt: Date?
    /// Set while the shortcut recorder is open so the current shortcut can be re-typed.
    var isShortcutSuspended = false {
        didSet { registerShortcut() }
    }
    /// Polls the mouse position while our own menu is open, when no events reach us.
    private var menuPollingTimer: Timer?

    /// The single source of truth for how the circle looks. Changes are pushed to
    /// every display and saved immediately.
    var configuration = CircleConfiguration.load() {
        didSet {
            guard configuration != oldValue else { return }
            windowManager?.apply(configuration)
            if configuration.shortcut != oldValue.shortcut {
                registerShortcut()
            }
            configuration.save()
        }
    }

    var isCircleVisible: Bool {
        get { windowManager?.isVisible ?? true }
        set {
            windowManager?.isVisible = newValue
            updateStatusIcon()
        }
    }

    // MARK: Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        let windowManager = WindowManager(configuration: configuration)
        self.windowManager = windowManager
        windowManager.rebuildWindows()

        let menuManager = MenuManager(appDelegate: self)
        self.menuManager = menuManager

        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.menu = menuManager.menu
        self.statusItem = statusItem
        updateStatusIcon()

        installMouseMonitors()

        hotKeyCenter.onPress = { [unowned self] in shortcutPressed() }
        hotKeyCenter.onRelease = { [unowned self] in shortcutReleased() }
        registerShortcut()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenParametersDidChange),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    func applicationWillTerminate(_ notification: Notification) {
        removeMouseMonitors()
        stopMenuPolling()
        windowManager?.closeAllWindows()
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: Menu bar

    private func updateStatusIcon() {
        let name = isCircleVisible ? AppConstants.MenuBar.iconName : AppConstants.MenuBar.hiddenIconName
        statusItem?.button?.image = NSImage(
            systemSymbolName: name,
            accessibilityDescription: AppConstants.MenuBar.accessibilityDescription
        )
        statusItem?.button?.toolTip = isCircleVisible ? "Mouse Circle" : "Mouse Circle (hidden)"
    }

    /// Called by MenuManager. While the dropdown is open the event monitors go quiet,
    /// so the circle is kept in sync by polling instead.
    func menuDidOpen() {
        stopMenuPolling()
        let timer = Timer(
            timeInterval: AppConstants.Timing.menuPollingInterval,
            target: self,
            selector: #selector(pollMouseLocation),
            userInfo: nil,
            repeats: true
        )
        // Menu tracking runs the run loop in event-tracking mode; `.common` covers it.
        RunLoop.main.add(timer, forMode: .common)
        menuPollingTimer = timer
    }

    func menuDidClose() {
        stopMenuPolling()
    }

    private func stopMenuPolling() {
        menuPollingTimer?.invalidate()
        menuPollingTimer = nil
    }

    @objc private func pollMouseLocation() {
        windowManager?.moveCircle(to: NSEvent.mouseLocation)
    }

    // MARK: Mouse tracking

    private static let movementEvents: NSEvent.EventTypeMask = [
        .mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged
    ]
    private static let clickEvents: NSEvent.EventTypeMask = [
        .leftMouseDown, .leftMouseUp, .rightMouseDown, .rightMouseUp
    ]

    /// Mouse events are delivered to whichever app is frontmost, so we need both monitors:
    /// the global one covers every other app, the local one covers our own windows
    /// (the dropdown and the colour panel). Clicks on our own windows aren't animated.
    private func installMouseMonitors() {
        guard eventMonitors.isEmpty else { return }

        if let global = NSEvent.addGlobalMonitorForEvents(
            matching: Self.movementEvents.union(Self.clickEvents),
            handler: { [weak self] event in self?.handle(event) }
        ) {
            eventMonitors.append(global)
        }

        if let local = NSEvent.addLocalMonitorForEvents(
            matching: Self.movementEvents,
            handler: { [weak self] event in
                self?.handle(event)
                return event
            }
        ) {
            eventMonitors.append(local)
        }
    }

    private func removeMouseMonitors() {
        eventMonitors.forEach(NSEvent.removeMonitor)
        eventMonitors.removeAll()
    }

    private func handle(_ event: NSEvent) {
        guard let windowManager else { return }
        let location = NSEvent.mouseLocation

        switch event.type {
        case .mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged:
            windowManager.moveCircle(to: location)
            // If a mouse-up was swallowed (e.g. by a menu) don't leave the ring stuck highlighted.
            if isMouseDown && NSEvent.pressedMouseButtons == 0 {
                isMouseDown = false
                windowManager.mouseReleased(at: location)
            }

        case .leftMouseDown, .rightMouseDown:
            guard !isMouseDown else { return }
            isMouseDown = true
            windowManager.mousePressed(at: location)

        case .leftMouseUp, .rightMouseUp:
            guard isMouseDown else { return }
            isMouseDown = false
            windowManager.mouseReleased(at: location)

        default:
            break
        }
    }

    // MARK: Keyboard shortcut

    private func registerShortcut() {
        hotKeyCenter.register(isShortcutSuspended ? nil : configuration.shortcut)
    }

    /// The circle flips as soon as the key goes down. A tap leaves it that way; a hold
    /// flips it back on release, so holding gives a momentary hide (or show).
    /// Key repeat can deliver several presses for one hold, so only the first one counts.
    private func shortcutPressed() {
        guard shortcutPressedAt == nil else { return }
        shortcutPressedAt = Date()
        isCircleVisible.toggle()
    }

    private func shortcutReleased() {
        guard let pressedAt = shortcutPressedAt else { return }
        shortcutPressedAt = nil
        if Date().timeIntervalSince(pressedAt) >= AppConstants.Timing.shortcutHoldThreshold {
            isCircleVisible.toggle()
        }
    }

    // MARK: Displays

    /// Fires repeatedly while displays settle, so the rebuild is debounced.
    @objc private func screenParametersDidChange() {
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(rebuildOverlayWindows), object: nil)
        perform(#selector(rebuildOverlayWindows), with: nil, afterDelay: AppConstants.Timing.screenChangeDebounce)
    }

    @objc private func rebuildOverlayWindows() {
        windowManager?.rebuildWindows()
    }
}

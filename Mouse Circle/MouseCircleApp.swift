import AppKit

/// Plain AppKit entry point. The app has no main window, only a status item and overlays.
@main
enum MouseCircleApp {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }
}

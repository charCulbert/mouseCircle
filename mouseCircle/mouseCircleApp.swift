import SwiftUI
import AppKit

@main
struct MouseCircleApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var circleWindow: NSWindow?
    var mouseLocationObserver: Any?
    var isClicked = false
    var clickTimer: Timer?
    var circleSize: CGFloat = 100 {
        didSet { updateCircleView() }
    }
    var rippleIntensity: CGFloat = 0.5 {
        didSet { updateCircleView() }
    }
    var circleThickness: CGFloat = 4 {
        didSet { updateCircleView() }
    }
    var animationType: AnimationType = .singleRipple {
        didSet { updateCircleView() }
    }
    var circleColor: NSColor = .green {
        didSet { updateCircleView() }
    }
    var circleOpacity: CGFloat = 0.6 {
        didSet { updateCircleView() }
    }

    enum AnimationType: String, CaseIterable {
        case singleRipple = "Single Ripple"
        case pulseOnClick = "Pulse On Click"
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenuBar()
        setupCircleWindow()
        setupMouseTracking()
    }

    func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "circle", accessibilityDescription: "Mouse Circle")
        }
        setupMenu()
    }

    func setupMenu() {
          let menu = NSMenu()

          let sizeMenuItem = createSliderMenuItem(title: "Circle Size", minValue: 30, maxValue: 600, currentValue: Double(circleSize), action: #selector(sizeSliderChanged(_:)))
          let intensityMenuItem = createSliderMenuItem(title: "Animation Intensity", minValue: 0.1, maxValue: 1.0, currentValue: Double(rippleIntensity), action: #selector(intensitySliderChanged(_:)))
          let thicknessMenuItem = createSliderMenuItem(title: "Circle Thickness", minValue: 1, maxValue: 10, currentValue: Double(circleThickness), action: #selector(thicknessSliderChanged(_:)))
          let opacityMenuItem = createSliderMenuItem(title: "Circle Opacity", minValue: 0.1, maxValue: 1.0, currentValue: Double(circleOpacity), action: #selector(opacitySliderChanged(_:)))


          menu.addItem(sizeMenuItem)
          menu.addItem(intensityMenuItem)
          menu.addItem(thicknessMenuItem)
          menu.addItem(opacityMenuItem)
          menu.addItem(NSMenuItem.separator())

          let animationSubmenu = NSMenu()
          for type in AnimationType.allCases {
              let item = NSMenuItem(title: type.rawValue, action: #selector(animationTypeChanged(_:)), keyEquivalent: "")
              item.target = self
              item.representedObject = type
              item.state = (type == animationType) ? .on : .off
              animationSubmenu.addItem(item)
          }
          let animationMenuItem = NSMenuItem(title: "Animation Type", action: nil, keyEquivalent: "")
          animationMenuItem.submenu = animationSubmenu
          menu.addItem(animationMenuItem)

          let colorMenuItem = NSMenuItem(title: "Circle Color", action: nil, keyEquivalent: "")
          colorMenuItem.submenu = createColorSubmenu()
          menu.addItem(colorMenuItem)

          menu.addItem(NSMenuItem.separator())
          menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

          statusItem?.menu = menu
      }

      func createColorSubmenu() -> NSMenu {
          let colorSubmenu = NSMenu()
          let colors: [(String, NSColor)] = [
              ("Red", .red),
              ("Green", .green),
              ("Blue", .blue),
              ("Yellow", .yellow),
              ("White", .white),
              ("Black", .black)
          ]

          for (name, color) in colors {
              let item = NSMenuItem(title: name, action: #selector(colorSelected(_:)), keyEquivalent: "")
              item.target = self
              item.representedObject = color
              colorSubmenu.addItem(item)
          }

          return colorSubmenu
      }

      @objc func colorSelected(_ sender: NSMenuItem) {
          if let color = sender.representedObject as? NSColor {
              circleColor = color
              updateCircleView()
          }
      }

    func createSliderMenuItem(title: String, minValue: Double, maxValue: Double, currentValue: Double, action: Selector) -> NSMenuItem {
        let menuItem = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        let sliderView = NSView(frame: NSRect(x: 0, y: 0, width: 200, height: 50))

        let label = NSTextField(frame: NSRect(x: 18, y: 25, width: 164, height: 20))
        label.stringValue = title
        label.isBezeled = false
        label.drawsBackground = false
        label.isEditable = false
        label.isSelectable = false
        sliderView.addSubview(label)

        let slider = NSSlider(frame: NSRect(x: 18, y: 5, width: 164, height: 20))
        slider.minValue = minValue
        slider.maxValue = maxValue
        slider.doubleValue = currentValue
        slider.target = self
        slider.action = action
        sliderView.addSubview(slider)

        menuItem.view = sliderView
        return menuItem
    }



    @objc func presetColorSelected(_ sender: NSButton) {
        circleColor = NSColor(cgColor: sender.layer!.backgroundColor!) ?? .green
        updateCircleView()
    }



    @objc func sizeSliderChanged(_ sender: NSSlider) {
        circleSize = CGFloat(sender.doubleValue)
    }

    @objc func intensitySliderChanged(_ sender: NSSlider) {
        rippleIntensity = CGFloat(sender.doubleValue)
    }

    @objc func thicknessSliderChanged(_ sender: NSSlider) {
        circleThickness = CGFloat(sender.doubleValue)
    }
    
    @objc func opacitySliderChanged(_ sender: NSSlider) {
        circleOpacity = CGFloat(sender.doubleValue)
    }


    @objc func animationTypeChanged(_ sender: NSMenuItem) {
        guard let newType = sender.representedObject as? AnimationType else { return }
        animationType = newType
        setupMenu() // Refresh menu to update checkmarks
    }

    func updateCircleView() {
        if let circleView = circleWindow?.contentView as? CircleView {
            circleView.circleSize = circleSize
            circleView.rippleIntensity = rippleIntensity
            circleView.circleThickness = circleThickness
            circleView.animationType = animationType
            circleView.circleColor = circleColor
            circleView.circleOpacity = circleOpacity
        }
    }

    func setupCircleWindow() {
        let screen = NSScreen.main!
        circleWindow = NSWindow(contentRect: screen.frame,
                                styleMask: [.borderless],
                                backing: .buffered,
                                defer: false)
        circleWindow?.level = .statusBar
        circleWindow?.backgroundColor = .clear
        circleWindow?.isOpaque = false
        circleWindow?.ignoresMouseEvents = true
        circleWindow?.contentView = CircleView()
        circleWindow?.makeKeyAndOrderFront(nil)
    }

    func setupMouseTracking() {
        mouseLocationObserver = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved, .leftMouseDown, .leftMouseUp, .leftMouseDragged]) { [weak self] event in
            guard let self = self, let circleView = self.circleWindow?.contentView as? CircleView else { return }

            switch event.type {
            case .mouseMoved, .leftMouseDragged:
                circleView.updatePosition(event.locationInWindow)
            case .leftMouseDown:
                self.handleMouseDown(circleView)
            case .leftMouseUp:
                self.handleMouseUp(circleView)
            default:
                break
            }
        }
    }

    func handleMouseDown(_ circleView: CircleView) {
        isClicked = true
        clickTimer?.invalidate()
        circleView.startAnimation(isDown: true)
    }

    func handleMouseUp(_ circleView: CircleView) {
        isClicked = false
        circleView.startAnimation(isDown: false)
    }
}

class CircleView: NSView {
    var circleColor: NSColor = .green {
        didSet { needsDisplay = true }
    }
    var circleOpacity: CGFloat = 0.6 {
        didSet { needsDisplay = true }
    }
    var circlePosition = NSPoint.zero
    var circleSize: CGFloat = 100 {
        didSet { needsDisplay = true }
    }
    var rippleIntensity: CGFloat = 0.5 {
        didSet { needsDisplay = true }
    }
    var circleThickness: CGFloat = 4 {
        didSet { needsDisplay = true }
    }
    var animationProgress: CGFloat = 0
    var animationType: AppDelegate.AnimationType = .singleRipple
    var isMouseDown = false
    var animationStartTime: Date?

    func updatePosition(_ point: NSPoint) {
        circlePosition = point
        needsDisplay = true
    }

    func startAnimation(isDown: Bool) {
        animationProgress = 0
        isMouseDown = isDown
        animationStartTime = Date()
        animate()
    }

    func animate() {
        guard let startTime = animationStartTime else { return }
        let elapsedTime = Date().timeIntervalSince(startTime)

        switch animationType {
        case .singleRipple:
            if !isMouseDown {
                animationProgress = min(CGFloat(elapsedTime / 0.3), 1)
            }
        case .pulseOnClick:
            animationProgress = min(CGFloat(elapsedTime / 0.15), 1)
        }

        needsDisplay = true

        if (animationType == .pulseOnClick && animationProgress < 1) ||
           (animationType == .singleRipple && !isMouseDown && animationProgress < 1) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.016) { [weak self] in
                self?.animate()
            }
        }
    }

    override func draw(_ dirtyRect: NSRect) {
            let baseCirclePath = NSBezierPath(ovalIn: NSRect(x: circlePosition.x - circleSize/2,
                                                             y: circlePosition.y - circleSize/2,
                                                             width: circleSize,
                                                             height: circleSize))

            switch animationType {
            case .singleRipple:
                if isMouseDown {
                    circleColor.withAlphaComponent(circleOpacity * 2).setStroke()
                } else {
                    circleColor.withAlphaComponent(circleOpacity).setStroke()
                }
                baseCirclePath.lineWidth = circleThickness
                baseCirclePath.stroke()

                if animationProgress > 0 && !isMouseDown {
                    let rippleSize = circleSize * (1 + animationProgress * rippleIntensity)
                    let ripplePath = NSBezierPath(ovalIn: NSRect(x: circlePosition.x - rippleSize/2,
                                                                 y: circlePosition.y - rippleSize/2,
                                                                 width: rippleSize,
                                                                 height: rippleSize))
                    circleColor.withAlphaComponent(circleOpacity * (1 - animationProgress)).setStroke()
                    ripplePath.lineWidth = circleThickness
                    ripplePath.stroke()
                }
            case .pulseOnClick:
                let pulseAmount = 0.4 * rippleIntensity + 0.1
                let pulseSize: CGFloat
                if isMouseDown {
                    pulseSize = circleSize * (1 - pulseAmount * animationProgress)
                } else {
                    pulseSize = circleSize * ((1 - pulseAmount) + pulseAmount * animationProgress)
                }
                let pulsePath = NSBezierPath(ovalIn: NSRect(x: circlePosition.x - pulseSize/2,
                                                            y: circlePosition.y - pulseSize/2,
                                                            width: pulseSize,
                                                            height: pulseSize))
                circleColor.withAlphaComponent(circleOpacity).setStroke()
                pulsePath.lineWidth = circleThickness
                pulsePath.stroke()
            }
        }
    }

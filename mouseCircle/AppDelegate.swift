//
//  AppDelegate.swift
//  mouseCircle
//
//  Created by Charlie Culbert on 1/5/25.
//

import SwiftUI
import AppKit

// MARK: - AppDelegate
class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var circleWindow: NSWindow?
    var mouseLocationObserver: Any?
    var isClicked = false
    var clickTimer: Timer?
    var configuration = CircleConfiguration() {
            didSet { updateCircleView() }
        }


    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenuBar()
        setupCircleWindow()
        setupMouseTracking()
    }

    // MARK: - Menu Bar Setup
    func setupMenuBar() {
        // Create status bar icon
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "circle", accessibilityDescription: "Mouse Circle")
        }
        
        // Initialize main menu
        let menu = NSMenu()
        
        // Add slider menu items
        let sliderItems = [
            ("Circle Size", 30.0, 600.0, Double(configuration.size), #selector(sizeSliderChanged(_:))),
            ("Animation Intensity", 0.1, 1.0, Double(configuration.intensity), #selector(intensitySliderChanged(_:))),
            ("Circle Thickness", 1.0, 10.0, Double(configuration.thickness), #selector(thicknessSliderChanged(_:))),
            ("Circle Opacity", 0.1, 1.0, Double(configuration.opacity), #selector(opacitySliderChanged(_:)))
        ]
        
        // Add all slider items to menu
        for (title, min, max, current, action) in sliderItems {
            menu.addItem(createSliderMenuItem(
                title: title,
                minValue: min,
                maxValue: max,
                currentValue: current,
                action: action
            ))
        }
        
        menu.addItem(NSMenuItem.separator())
        
        // Add animation type submenu
        let animationMenuItem = NSMenuItem(title: "Animation Type", action: nil, keyEquivalent: "")
        let animationSubmenu = NSMenu()
        
        for type in CircleConfiguration.AnimationType.allCases {
            let item = NSMenuItem(title: type.rawValue, action: #selector(animationTypeChanged(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = type
            item.state = (type == configuration.type) ? .on : .off  // Compare with current configuration type
            animationSubmenu.addItem(item)
        }
        
        animationMenuItem.submenu = animationSubmenu
        menu.addItem(animationMenuItem)
        
        // Add color submenu
        let colorMenuItem = NSMenuItem(title: "Circle Color", action: nil, keyEquivalent: "")
        colorMenuItem.submenu = createColorSubmenu()
        menu.addItem(colorMenuItem)
        
        // Add quit item
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
            configuration.color = color
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
        configuration.color = NSColor(cgColor: sender.layer!.backgroundColor!) ?? .green
    }



    @objc func sizeSliderChanged(_ sender: NSSlider) {
        configuration.size = CGFloat(sender.doubleValue)
    }

    @objc func intensitySliderChanged(_ sender: NSSlider) {
        configuration.intensity = CGFloat(sender.doubleValue)
    }

    @objc func thicknessSliderChanged(_ sender: NSSlider) {
        configuration.thickness = CGFloat(sender.doubleValue)
    }
    
    @objc func opacitySliderChanged(_ sender: NSSlider) {
        configuration.opacity = CGFloat(sender.doubleValue)
    }


    @objc func animationTypeChanged(_ sender: NSMenuItem) {
        guard let newType = sender.representedObject as? CircleConfiguration.AnimationType else { return }
        
        // Update the current animation type
        configuration.type = newType
        
        // Only update checkmarks in animation submenu
        if let menu = sender.menu {
            for item in menu.items {
                item.state = (item.representedObject as? CircleConfiguration.AnimationType == configuration.type) ? .on : .off
            }
        }
    }

    func updateCircleView() {
        if let circleView = circleWindow?.contentView as? CircleView {
            circleView.circleSize = configuration.size
            circleView.rippleIntensity = configuration.intensity
            circleView.circleThickness = configuration.thickness
            circleView.animationType = configuration.type
            circleView.circleColor = configuration.color
            circleView.circleOpacity = configuration.opacity
        }
    }

    // MARK: - Window Setup
    func setupCircleWindow() {
        // Create window that spans the main screen
        let screen = NSScreen.main!
        circleWindow = NSWindow(
            contentRect: screen.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        
        // Configure window properties
        configureWindowBehavior()
        
        // Set up circle view
        circleWindow?.contentView = CircleView()
        circleWindow?.makeKeyAndOrderFront(nil)
    }

    private func configureWindowBehavior() {
        guard let window = circleWindow else { return }
        // Set window to appear above other windows
        window.level = NSWindow.Level(rawValue: NSWindow.Level.popUpMenu.rawValue + 2)
        // Allow window to appear on all spaces and in full screen
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        // Make window transparent and click-through
        window.backgroundColor = .clear
        window.isOpaque = false
        window.ignoresMouseEvents = true
    }

    func setupMouseTracking() {
        mouseLocationObserver = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved, .leftMouseDown, .leftMouseUp, .leftMouseDragged]) { [weak self] event in
            guard let self = self, let circleView = self.circleWindow?.contentView as? CircleView else { return }

            switch event.type {
                   case .mouseMoved, .leftMouseDragged:
                       let screenLocation = NSEvent.mouseLocation
                       circleView.updatePosition(screenLocation)
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

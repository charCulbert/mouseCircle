//
//  CircleView.swift
//  mouseCircle
//
//  Created by Charlie Culbert on 1/5/25.
//
import SwiftUI
import AppKit

// MARK: - CircleView
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
    var animationType: CircleConfiguration.AnimationType = .singleRipple
    var isMouseDown = false
    var animationStartTime: Date?

    func updatePosition(_ point: NSPoint) {
        circlePosition = point
        needsDisplay = true
    }
    
    func update(with config: CircleConfiguration) {
        self.circleSize = config.size
        self.rippleIntensity = config.intensity
        self.circleThickness = config.thickness
        self.animationType = config.type
        self.circleColor = config.color
        self.circleOpacity = config.opacity
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

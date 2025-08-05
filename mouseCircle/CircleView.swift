import SwiftUI
import AppKit

/**
 * CircleView: Custom view that draws and animates the mouse circle
 * 
 * This class handles:
 * 1. Drawing the circle at the mouse position
 * 2. Animating click effects (ripples, pulses)
 * 3. Updating appearance when settings change
 *
 */
class CircleView: NSView {
    // MARK: - Visual Properties
    
    /// Color of the circle
    var circleColor: NSColor = AppConstants.Colors.defaultColor {
        didSet { needsDisplay = true }  // Trigger redraw when color changes
    }
    
    // MARK: - Initialization
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    /// Current position of the circle center in window coordinates
    var circlePosition = NSPoint(x: 100, y: 100)
    
    /// Size of the circle in pixels (diameter)
    var circleSize: CGFloat = AppConstants.Circle.defaultSize {
        didSet { needsDisplay = true }
    }
    
    /// How intense animation effects should be (scale multiplier)
    var rippleIntensity: CGFloat = AppConstants.Animation.defaultIntensity {
        didSet { 
            needsDisplay = true 
        }
    }
    
    /// Thickness of the circle outline in pixels
    var circleThickness: CGFloat = AppConstants.Circle.defaultThickness {
        didSet { needsDisplay = true }
    }
    
    // MARK: - Animation State
    
    /// Current progress of animation (0.0 = start, 1.0 = complete)
    var animationProgress: CGFloat = 0
    
    /// What type of animation to show when clicking
    var animationType: AnimationType = .singleRipple
    
    /// Whether the mouse button is currently pressed
    var isMouseDown = false
    
    /// When the current animation started (used for timing)
    private var animationStartTime: Date?
    
    // MARK: - Cleanup
    
    /**
     * Clean up when view is deallocated
     */
    deinit {
        animationStartTime = nil
    }

    // MARK: - Public Interface
    
    /**
     * Update the circle position when mouse moves
     * @param point: New position in window coordinates
     */
    func updatePosition(_ point: NSPoint) {
        // Check if view is still attached to a window
        guard window != nil else { return }
        
        circlePosition = point
        
        // Schedule a redraw on the main thread
        ThreadingHelpers.executeOnMainThread { [weak self] in
            self?.needsDisplay = true
        }
    }
    
    /**
     * Update all circle properties from configuration
     * @param config: New configuration to apply
     */
    func update(with config: CircleConfiguration) {
        // Check if view is still attached to a window
        guard window != nil else { return }
        
        
        // Apply all configuration values
        self.circleSize = config.size
        self.rippleIntensity = config.intensity
        self.circleThickness = config.thickness
        self.animationType = config.type
        self.circleColor = config.color
        
        // Schedule a redraw
        ThreadingHelpers.executeOnMainThread { [weak self] in
            self?.needsDisplay = true
        }
    }

    /**
     * Start a click animation
     * @param isDown: true when mouse pressed, false when released
     */
    func startAnimation(isDown: Bool) {
        // Check if view is still attached to a window
        guard window != nil else { 
            return 
        }
        
        // Reset animation state
        animationProgress = 0
        isMouseDown = isDown
        animationStartTime = Date()
        
        
        // Start the animation loop
        animate()
    }

    // MARK: - Animation Logic
    
    /**
     * Run one frame of the animation loop
     * This is called repeatedly to create animation
     */
    private func animate() {
        // Check if animation is still valid
        guard let startTime = animationStartTime, window != nil else { 
            return 
        }
        
        // Calculate elapsed time
        let elapsedTime = Date().timeIntervalSince(startTime)
        let oldProgress = animationProgress
        
        // Update animation progress
        switch animationType {
        case .singleRipple:
            // Only animate the ripple effect after mouse button is released
            if !isMouseDown {
                animationProgress = min(CGFloat(elapsedTime / AppConstants.Animation.rippleDuration), 1.0)
            }
            
        case .pulseOnClick:
            // Animate the pulse while mouse is pressed
            animationProgress = min(CGFloat(elapsedTime / AppConstants.Animation.pulseDuration), 1.0)
        }
        
        
        // Redraw the view with new animation progress
        ThreadingHelpers.executeOnMainThread { [weak self] in
            self?.needsDisplay = true
        }
        
        // Check if animation should continue
        let shouldContinue = (animationType == .pulseOnClick && animationProgress < 1) ||
                           (animationType == .singleRipple && !isMouseDown && animationProgress < 1)
        
        
        if shouldContinue {
            // Schedule next frame
            ThreadingHelpers.executeOnMainThreadAfterDelay(AppConstants.Timing.animationFrameRate) { [weak self] in
                guard let self = self, self.window != nil else { return }
                self.animate()
            }
        } else {
        }
    }

    // MARK: - Drawing
    
    /**
     * Draw the circle and any active animations
     * This is called by macOS whenever the view needs to be redrawn
     * @param dirtyRect: The area that needs to be redrawn (the app ignores this and draws everything)
     */
    override func draw(_ dirtyRect: NSRect) {
        
        // Draw animation effects
        switch animationType {
        case .singleRipple:
            drawRippleEffect()
        case .pulseOnClick:
            drawPulseEffect()
        }
    }
    
    /**
     * Draw the ripple effect animation
     * Shows a base circle with an expanding ring when clicked
     */
    private func drawRippleEffect() {
        // Create the main circle path
        let baseCirclePath = createCirclePath(size: circleSize)
        
        // Set color - full opacity when mouse is down
        if isMouseDown {
            circleColor.withAlphaComponent(1.0).setStroke()
        } else {
            circleColor.setStroke()
        }
        
        // Draw the main circle
        baseCirclePath.lineWidth = circleThickness
        baseCirclePath.stroke()
        
        // Draw expanding ripple ring after mouse release
        if animationProgress > 0 && !isMouseDown {
            // Calculate ripple scale
            let maxScale = AppConstants.Animation.rippleMaxScale
            let effectiveScale = maxScale * rippleIntensity
            let rippleSize = circleSize * (1.0 + animationProgress * effectiveScale)
            let ripplePath = createCirclePath(size: rippleSize)
            
            
            // Fade out the ripple as it expands
            let fadeAmount = 1.0 - animationProgress
            circleColor.withAlphaComponent(circleColor.alphaComponent * fadeAmount).setStroke()
            ripplePath.lineWidth = circleThickness
            ripplePath.stroke()
        }
    }
    
    /**
     * Draw the pulse effect animation
     * Shows a circle that shrinks when pressed, grows when released
     */
    private func drawPulseEffect() {
        // Calculate pulse size
        let pulseAmount = 0.4 * rippleIntensity + 0.1
        let pulseSize: CGFloat
        
        if isMouseDown {
            // Shrink when mouse is pressed
            pulseSize = circleSize * (1.0 - pulseAmount * animationProgress)
            circleColor.withAlphaComponent(1.0).setStroke()
        } else {
            // Grow back when mouse is released
            pulseSize = circleSize * ((1.0 - pulseAmount) + pulseAmount * animationProgress)
            circleColor.setStroke()
        }
        
        // Create and draw the pulsing circle
        let pulsePath = createCirclePath(size: pulseSize)
        circleColor.setStroke()
        pulsePath.lineWidth = circleThickness
        pulsePath.stroke()
    }
    
    /**
     * Create a circular path centered at the circle position
     * @param size: Diameter of the circle
     * @return: NSBezierPath representing the circle
     */
    private func createCirclePath(size: CGFloat) -> NSBezierPath {
        return NSBezierPath(ovalIn: NSRect(
            x: circlePosition.x - size / 2,    // Center horizontally
            y: circlePosition.y - size / 2,    // Center vertically
            width: size,
            height: size
        ))
    }
}

import AppKit
import QuartzCore

/// Draws the circle with Core Animation layers so moving it costs nothing more than
/// updating a layer position, and click effects are animated by the compositor rather
/// than by redrawing a screen-sized view every frame.
final class CircleView: NSView {
    private let ringLayer = CAShapeLayer()
    private let rippleLayer = CAShapeLayer()
    private var configuration = CircleConfiguration()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layerContentsRedrawPolicy = .never

        for shape in [rippleLayer, ringLayer] {
            shape.fillColor = nil
            shape.anchorPoint = CGPoint(x: 0.5, y: 0.5)
            layer?.addSublayer(shape)
        }
        rippleLayer.opacity = 0
        apply(configuration)
    }

    required init?(coder: NSCoder) {
        fatalError("CircleView is created in code only")
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        updateContentsScale()
    }

    override func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()
        updateContentsScale()
    }

    /// Shape layers rasterise at their own scale, so match the display or the ring looks blurry on Retina.
    private func updateContentsScale() {
        let scale = window?.backingScaleFactor ?? 2
        ringLayer.contentsScale = scale
        rippleLayer.contentsScale = scale
    }

    // MARK: Public interface

    /// Apply size, thickness, colour and animation settings.
    func apply(_ configuration: CircleConfiguration) {
        self.configuration = configuration

        let thickness = configuration.thickness
        let extent = configuration.size + thickness
        let bounds = CGRect(x: 0, y: 0, width: extent, height: extent)
        let path = CGPath(ellipseIn: bounds.insetBy(dx: thickness / 2, dy: thickness / 2), transform: nil)

        withoutAnimation {
            for shape in [ringLayer, rippleLayer] {
                shape.bounds = bounds
                shape.path = path
                shape.lineWidth = thickness
                shape.strokeColor = configuration.color.cgColor
            }
            ringLayer.transform = CATransform3DIdentity
        }
    }

    /// Move the circle's centre to `point` (view coordinates).
    func move(to point: CGPoint) {
        withoutAnimation { ringLayer.position = point }
    }

    /// Mouse button went down at `point`: highlight the ring, and start the pulse if selected.
    func mousePressed(at point: CGPoint) {
        move(to: point)
        animated(duration: AppConstants.Animation.pulseDuration) {
            ringLayer.strokeColor = configuration.color.withAlphaComponent(1).cgColor
            if configuration.animation == .pulse {
                let shrink = 1 - pulseAmount
                ringLayer.transform = CATransform3DMakeScale(shrink, shrink, 1)
            }
        }
    }

    /// Mouse button released at `point`: restore the ring and fire the ripple if selected.
    func mouseReleased(at point: CGPoint) {
        move(to: point)
        animated(duration: AppConstants.Animation.pulseDuration) {
            ringLayer.strokeColor = configuration.color.cgColor
            ringLayer.transform = CATransform3DIdentity
        }
        if configuration.animation == .ripple {
            playRipple(at: point)
        }
    }

    // MARK: Animations

    /// How much the pulse shrinks the ring: 10% at zero intensity up to 50% at full.
    private var pulseAmount: CGFloat {
        0.4 * configuration.intensity + 0.1
    }

    /// An expanding, fading copy of the ring that stays anchored at the click location.
    private func playRipple(at point: CGPoint) {
        withoutAnimation { rippleLayer.position = point }

        let targetScale = 1 + AppConstants.Animation.rippleMaxScale * configuration.intensity

        let grow = CABasicAnimation(keyPath: "transform.scale")
        grow.fromValue = 1
        grow.toValue = targetScale

        let fade = CABasicAnimation(keyPath: "opacity")
        fade.fromValue = 1
        fade.toValue = 0

        let group = CAAnimationGroup()
        group.animations = [grow, fade]
        group.duration = AppConstants.Animation.rippleDuration
        group.timingFunction = CAMediaTimingFunction(name: .easeOut)

        // The layer's model opacity stays at 0, so it vanishes as soon as the animation ends.
        rippleLayer.removeAnimation(forKey: "ripple")
        rippleLayer.add(group, forKey: "ripple")
    }

    private func withoutAnimation(_ changes: () -> Void) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        changes()
        CATransaction.commit()
    }

    private func animated(duration: TimeInterval, _ changes: () -> Void) {
        CATransaction.begin()
        CATransaction.setAnimationDuration(duration)
        CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: .easeInEaseOut))
        changes()
        CATransaction.commit()
    }
}

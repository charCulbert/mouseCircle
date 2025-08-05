import AppKit

/**
 * CircleConfiguration: Data model that holds all circle appearance and behavior settings
 **/
struct CircleConfiguration {
    // MARK: - Circle Appearance Properties
    
    /// Size of the circle in pixels (diameter)
    var size: CGFloat = AppConstants.Circle.defaultSize
    
    /// Color of the circle (uses system colors for consistency)
    var color: NSColor = AppConstants.Colors.defaultColor
    
    /// Thickness of the circle outline in pixels
    var thickness: CGFloat = AppConstants.Circle.defaultThickness
    
    // MARK: - Animation Properties
    
    /// Type of animation to show when clicking (uses enum from Constants.swift)
    var type: AnimationType = .singleRipple
    
    /// How intense the animation effect should be (scale multiplier)
    var intensity: CGFloat = AppConstants.Animation.defaultIntensity
    
}

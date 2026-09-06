import AppKit

/// Everything the user can tweak. Persisted to UserDefaults as JSON.
struct CircleConfiguration: Equatable {
    /// Circle diameter in points.
    var size: Double = AppConstants.Circle.defaultSize
    /// Outline thickness in points.
    var thickness: Double = AppConstants.Circle.defaultThickness
    /// Click animation strength, 0...1.
    var intensity: Double = AppConstants.Animation.defaultIntensity
    var animation: AnimationType = .ripple

    /// Global shortcut for hiding and showing the circle. nil means none.
    var shortcut: HotKey? = .default
    var shortcutMode: ShortcutMode = .toggle

    /// sRGB red, green, blue, alpha. NSColor isn't Codable, so the colour is stored this way.
    private var rgba: [Double] = CircleConfiguration.components(of: AppConstants.Circle.defaultColor)

    var color: NSColor {
        get {
            guard rgba.count == 4 else { return AppConstants.Circle.defaultColor }
            return NSColor(srgbRed: rgba[0], green: rgba[1], blue: rgba[2], alpha: rgba[3])
        }
        set { rgba = CircleConfiguration.components(of: newValue) }
    }

    init() {}

    private static func components(of color: NSColor) -> [Double] {
        let srgb = color.usingColorSpace(.sRGB) ?? color
        return [srgb.redComponent, srgb.greenComponent, srgb.blueComponent, srgb.alphaComponent]
    }

    // MARK: Persistence

    static func load(from defaults: UserDefaults = .standard) -> CircleConfiguration {
        guard let data = defaults.data(forKey: AppConstants.Storage.configurationKey),
              let configuration = try? JSONDecoder().decode(CircleConfiguration.self, from: data)
        else { return CircleConfiguration() }
        return configuration
    }

    func save(to defaults: UserDefaults = .standard) {
        guard let data = try? JSONEncoder().encode(self) else { return }
        defaults.set(data, forKey: AppConstants.Storage.configurationKey)
    }
}

/// Hand-written so settings added in later versions fall back to their defaults instead of
/// throwing away everything the user had saved.
extension CircleConfiguration: Codable {
    private enum CodingKeys: String, CodingKey {
        case size, thickness, intensity, animation, shortcut, shortcutMode, rgba
    }

    init(from decoder: Decoder) throws {
        self.init()
        let container = try decoder.container(keyedBy: CodingKeys.self)
        size = try container.decodeIfPresent(Double.self, forKey: .size) ?? size
        thickness = try container.decodeIfPresent(Double.self, forKey: .thickness) ?? thickness
        intensity = try container.decodeIfPresent(Double.self, forKey: .intensity) ?? intensity
        animation = try container.decodeIfPresent(AnimationType.self, forKey: .animation) ?? animation
        shortcutMode = try container.decodeIfPresent(ShortcutMode.self, forKey: .shortcutMode) ?? shortcutMode
        rgba = try container.decodeIfPresent([Double].self, forKey: .rgba) ?? rgba
        // A saved null means "no shortcut"; a missing key means the default.
        if container.contains(.shortcut) {
            shortcut = try container.decode(HotKey?.self, forKey: .shortcut)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(size, forKey: .size)
        try container.encode(thickness, forKey: .thickness)
        try container.encode(intensity, forKey: .intensity)
        try container.encode(animation, forKey: .animation)
        try container.encode(shortcut, forKey: .shortcut)   // encodes null when nil
        try container.encode(shortcutMode, forKey: .shortcutMode)
        try container.encode(rgba, forKey: .rgba)
    }
}

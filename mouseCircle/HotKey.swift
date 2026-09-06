import AppKit
import Carbon

/// A global keyboard shortcut: a key plus modifiers. Stored in the configuration.
struct HotKey: Codable, Equatable {
    var keyCode: UInt16
    /// Raw `NSEvent.ModifierFlags`, restricted to ⌘ ⌥ ⌃ ⇧.
    var modifierFlagsRaw: UInt
    /// The key's character ignoring modifiers, e.g. "m" or "\u{F704}" for F1. Used for display
    /// and as the menu item's key equivalent.
    var keyEquivalent: String

    static let relevantModifiers: NSEvent.ModifierFlags = [.command, .option, .control, .shift]

    /// ⌃⌥⌘M out of the box. Unlikely to clash with anything, and M is for mouse.
    static let `default` = HotKey(
        keyCode: UInt16(kVK_ANSI_M),
        modifierFlags: [.control, .option, .command],
        keyEquivalent: "m"
    )

    init(keyCode: UInt16, modifierFlags: NSEvent.ModifierFlags, keyEquivalent: String) {
        self.keyCode = keyCode
        self.modifierFlagsRaw = modifierFlags.intersection(HotKey.relevantModifiers).rawValue
        self.keyEquivalent = keyEquivalent
    }

    init(event: NSEvent) {
        self.init(
            keyCode: event.keyCode,
            modifierFlags: event.modifierFlags,
            keyEquivalent: (event.charactersIgnoringModifiers ?? "").lowercased()
        )
    }

    var modifierFlags: NSEvent.ModifierFlags {
        NSEvent.ModifierFlags(rawValue: modifierFlagsRaw)
    }

    /// Modifier mask in the form Carbon's `RegisterEventHotKey` expects.
    var carbonModifiers: UInt32 {
        var result: UInt32 = 0
        if modifierFlags.contains(.command) { result |= UInt32(cmdKey) }
        if modifierFlags.contains(.option) { result |= UInt32(optionKey) }
        if modifierFlags.contains(.control) { result |= UInt32(controlKey) }
        if modifierFlags.contains(.shift) { result |= UInt32(shiftKey) }
        return result
    }

    /// Human readable, e.g. "⌃⌥⌘M" or "⇧F5".
    var displayString: String {
        var text = ""
        if modifierFlags.contains(.control) { text += "⌃" }
        if modifierFlags.contains(.option) { text += "⌥" }
        if modifierFlags.contains(.shift) { text += "⇧" }
        if modifierFlags.contains(.command) { text += "⌘" }
        return text + keyName
    }

    var isFunctionKey: Bool {
        guard let scalar = keyEquivalent.unicodeScalars.first else { return false }
        return (0xF704...0xF717).contains(scalar.value)
    }

    private var keyName: String {
        switch Int(keyCode) {
        case kVK_Space: return "Space"
        case kVK_Return: return "↩"
        case kVK_Tab: return "⇥"
        case kVK_Delete: return "⌫"
        case kVK_ForwardDelete: return "⌦"
        case kVK_Escape: return "⎋"
        default: break
        }
        if let scalar = keyEquivalent.unicodeScalars.first {
            switch scalar.value {
            case 0xF704...0xF717: return "F\(scalar.value - 0xF703)"
            case 0xF700: return "↑"
            case 0xF701: return "↓"
            case 0xF702: return "←"
            case 0xF703: return "→"
            case 0xF729: return "↖"
            case 0xF72B: return "↘"
            case 0xF72C: return "⇞"
            case 0xF72D: return "⇟"
            default: break
            }
        }
        return keyEquivalent.uppercased()
    }
}

/// Registers one system-wide hot key using Carbon, which works from a sandboxed app
/// without any accessibility or input monitoring permission.
final class HotKeyCenter {
    var onPress: (() -> Void)?
    var onRelease: (() -> Void)?

    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?
    private let hotKeyID = EventHotKeyID(signature: HotKeyCenter.signature, id: 1)

    private static let signature: OSType = "MCRC".utf8.reduce(0) { ($0 << 8) | OSType($1) }

    deinit {
        unregister()
        if let handlerRef {
            RemoveEventHandler(handlerRef)
        }
    }

    /// Replace the current hot key. Pass nil to have none. Returns false if the system refused it.
    @discardableResult
    func register(_ hotKey: HotKey?) -> Bool {
        unregister()
        guard let hotKey else { return true }
        installHandlerIfNeeded()
        let status = RegisterEventHotKey(
            UInt32(hotKey.keyCode),
            hotKey.carbonModifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
        return status == noErr
    }

    func unregister() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
    }

    private func installHandlerIfNeeded() {
        guard handlerRef == nil else { return }
        let eventTypes = [
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed)),
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyReleased))
        ]
        // The callback is a plain C function pointer, so `self` travels through userData.
        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, userData -> OSStatus in
                guard let event, let userData else { return OSStatus(eventNotHandledErr) }
                let center = Unmanaged<HotKeyCenter>.fromOpaque(userData).takeUnretainedValue()
                return center.handle(event)
            },
            eventTypes.count,
            eventTypes,
            Unmanaged.passUnretained(self).toOpaque(),
            &handlerRef
        )
    }

    private func handle(_ event: EventRef) -> OSStatus {
        var receivedID = EventHotKeyID()
        GetEventParameter(
            event,
            EventParamName(kEventParamDirectObject),
            EventParamType(typeEventHotKeyID),
            nil,
            MemoryLayout<EventHotKeyID>.size,
            nil,
            &receivedID
        )
        guard receivedID.signature == hotKeyID.signature, receivedID.id == hotKeyID.id else {
            return OSStatus(eventNotHandledErr)
        }
        switch Int(GetEventKind(event)) {
        case kEventHotKeyPressed: onPress?()
        case kEventHotKeyReleased: onRelease?()
        default: return OSStatus(eventNotHandledErr)
        }
        return noErr
    }
}

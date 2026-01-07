import Cocoa
import Carbon

enum ClickType {
    case left
    case right
    case other
}

// Global handler for Carbon hotkey events
private var hotkeyHandlerRef: AutoreleasingUnsafeMutablePointer<EventHandlerRef?>?
private weak var sharedEventMonitor: EventMonitor?

class EventMonitor {
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var localMonitor: Any?
    private var globalKeyMonitor: Any?
    private var hotkeyRef: EventHotKeyRef?
    private var hotkeyID: EventHotKeyID?

    private let onMouseMove: (NSPoint) -> Void
    private let onMouseClick: (NSPoint, ClickType) -> Void
    private let onKeyPress: (String) -> Void
    private let onHotkey: () -> Void

    private let settings = AppSettings.shared

    init(
        onMouseMove: @escaping (NSPoint) -> Void,
        onMouseClick: @escaping (NSPoint, ClickType) -> Void,
        onKeyPress: @escaping (String) -> Void,
        onHotkey: @escaping () -> Void
    ) {
        self.onMouseMove = onMouseMove
        self.onMouseClick = onMouseClick
        self.onKeyPress = onKeyPress
        self.onHotkey = onHotkey
    }

    func start() {
        startMouseMonitoring()
        startKeyboardMonitoring()
    }

    func stop() {
        stopMouseMonitoring()
        stopKeyboardMonitoring()
    }

    // MARK: - Mouse Monitoring

    private func startMouseMonitoring() {
        // Include tap disabled events so we can re-enable if needed
        var eventMask: CGEventMask = 0
        eventMask |= (1 << CGEventType.mouseMoved.rawValue)
        eventMask |= (1 << CGEventType.leftMouseDown.rawValue)
        eventMask |= (1 << CGEventType.rightMouseDown.rawValue)
        eventMask |= (1 << CGEventType.otherMouseDown.rawValue)
        eventMask |= (1 << CGEventType.leftMouseDragged.rawValue)
        eventMask |= (1 << CGEventType.rightMouseDragged.rawValue)
        eventMask |= (1 << CGEventType.otherMouseDragged.rawValue)
        eventMask |= (1 << CGEventType.tapDisabledByTimeout.rawValue)
        eventMask |= (1 << CGEventType.tapDisabledByUserInput.rawValue)

        let callback: CGEventTapCallBack = { proxy, type, event, refcon in
            guard let refcon = refcon else { return Unmanaged.passUnretained(event) }
            let monitor = Unmanaged<EventMonitor>.fromOpaque(refcon).takeUnretainedValue()

            // Handle tap being disabled by macOS
            if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                monitor.reEnableEventTap()
                return Unmanaged.passUnretained(event)
            }

            monitor.handleMouseEvent(type: type, event: event)
            return Unmanaged.passUnretained(event)
        }

        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        eventTap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: eventMask,
            callback: callback,
            userInfo: selfPtr
        )

        guard let eventTap = eventTap else {
            #if DEBUG
            print("[MouseLight] Failed to create event tap - Accessibility permission likely not granted")
            #endif
            return
        }

        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: true)
    }

    private func reEnableEventTap() {
        guard let eventTap = eventTap else { return }
        CGEvent.tapEnable(tap: eventTap, enable: true)
        #if DEBUG
        print("[MouseLight] Event tap re-enabled after timeout")
        #endif
    }

    private func stopMouseMonitoring() {
        if let eventTap = eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
        }
        if let runLoopSource = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
    }

    private func handleMouseEvent(type: CGEventType, event: CGEvent) {
        let location = event.location

        // Convert CGEvent coords to AppKit screen coords
        // CGEvent origin is at TOP-LEFT of PRIMARY screen, Y increases down
        // AppKit origin is at BOTTOM-LEFT of primary screen, Y increases up
        // We must use the PRIMARY screen (screens[0]), not NSScreen.main
        guard let primaryScreen = NSScreen.screens.first else { return }
        let screenPoint = NSPoint(x: location.x, y: primaryScreen.frame.maxY - location.y)

        switch type {
        case .mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged:
            #if DEBUG
            // Log occasionally to verify events are being received
            if Int.random(in: 0..<100) == 0 {
                print("[MouseLight] Mouse at: \(screenPoint)")
            }
            #endif
            DispatchQueue.main.async {
                self.onMouseMove(screenPoint)
            }
        case .leftMouseDown:
            DispatchQueue.main.async {
                self.onMouseClick(screenPoint, .left)
            }
        case .rightMouseDown:
            DispatchQueue.main.async {
                self.onMouseClick(screenPoint, .right)
            }
        case .otherMouseDown:
            DispatchQueue.main.async {
                self.onMouseClick(screenPoint, .other)
            }
        default:
            break
        }
    }

    // MARK: - Keyboard Monitoring

    private func startKeyboardMonitoring() {
        // Register Carbon hotkey for reliable system-wide hotkey detection
        registerCarbonHotkey()

        // NSEvent monitors for keystroke display (not for hotkey)
        globalKeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleKeyEventForDisplay(event)
        }

        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleKeyEventForDisplay(event)
            return event
        }
    }

    private func stopKeyboardMonitoring() {
        unregisterCarbonHotkey()

        if let monitor = globalKeyMonitor {
            NSEvent.removeMonitor(monitor)
        }
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
        }
        globalKeyMonitor = nil
        localMonitor = nil
    }

    // MARK: - Carbon Hotkey Registration

    private func registerCarbonHotkey() {
        sharedEventMonitor = self

        // Install event handler for hotkey events
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))

        let handler: EventHandlerUPP = { _, event, _ -> OSStatus in
            guard let monitor = sharedEventMonitor else { return noErr }
            DispatchQueue.main.async {
                monitor.onHotkey()
            }
            return noErr
        }

        InstallEventHandler(GetApplicationEventTarget(), handler, 1, &eventType, nil, nil)

        // Register the hotkey
        let keyCode = UInt32(settings.spotlightHotkeyKeyCode)
        let modifiers = carbonModifiers(from: settings.spotlightHotkeyModifiers)

        hotkeyID = EventHotKeyID(signature: OSType(0x4D4C4854), id: 1) // 'MLHT' signature
        var hotKeyRef: EventHotKeyRef?

        let status = RegisterEventHotKey(keyCode, modifiers, hotkeyID!, GetApplicationEventTarget(), 0, &hotKeyRef)

        if status == noErr {
            hotkeyRef = hotKeyRef
        }
    }

    private func unregisterCarbonHotkey() {
        if let ref = hotkeyRef {
            UnregisterEventHotKey(ref)
            hotkeyRef = nil
        }
        sharedEventMonitor = nil
    }

    private func carbonModifiers(from nsModifiers: Int) -> UInt32 {
        var carbonMods: UInt32 = 0
        let flags = NSEvent.ModifierFlags(rawValue: UInt(nsModifiers))

        if flags.contains(.command) { carbonMods |= UInt32(cmdKey) }
        if flags.contains(.shift) { carbonMods |= UInt32(shiftKey) }
        if flags.contains(.option) { carbonMods |= UInt32(optionKey) }
        if flags.contains(.control) { carbonMods |= UInt32(controlKey) }

        return carbonMods
    }

    /// Re-register hotkey when settings change
    func updateHotkey() {
        unregisterCarbonHotkey()
        registerCarbonHotkey()
    }

    private func handleKeyEventForDisplay(_ event: NSEvent) {
        // Skip if this is the hotkey (Carbon handles it)
        if isSpotlightHotkey(event) {
            return
        }

        // Build keystroke string for display
        let keystroke = formatKeystroke(event)
        if !keystroke.isEmpty {
            DispatchQueue.main.async {
                self.onKeyPress(keystroke)
            }
        }
    }

    private func isSpotlightHotkey(_ event: NSEvent) -> Bool {
        let storedModifiers = settings.spotlightHotkeyModifiers
        let storedKeyCode = settings.spotlightHotkeyKeyCode

        let requiredModifiers = NSEvent.ModifierFlags(rawValue: UInt(storedModifiers))
        let relevantFlags: NSEvent.ModifierFlags = [.command, .shift, .option, .control]
        let eventFlags = event.modifierFlags.intersection(relevantFlags)
        let hasCorrectModifiers = eventFlags == requiredModifiers.intersection(relevantFlags)

        return hasCorrectModifiers && Int(event.keyCode) == storedKeyCode
    }

    private func formatKeystroke(_ event: NSEvent) -> String {
        // Check filter setting
        let filter = settings.keystrokeFilter
        let hasModifiers = event.modifierFlags.intersection([.command, .control, .option]).isEmpty == false

        // If filter is modifiers_only, skip keystrokes without modifiers
        if filter == "modifiers_only" && !hasModifiers {
            return ""
        }

        var parts: [String] = []

        // Add modifier symbols
        if event.modifierFlags.contains(.control) {
            parts.append("\u{2303}") // Control symbol
        }
        if event.modifierFlags.contains(.option) {
            parts.append("\u{2325}") // Option symbol
        }
        if event.modifierFlags.contains(.shift) {
            parts.append("\u{21E7}") // Shift symbol
        }
        if event.modifierFlags.contains(.command) {
            parts.append("\u{2318}") // Command symbol
        }

        // Add the key character
        if let chars = event.charactersIgnoringModifiers?.uppercased(), !chars.isEmpty {
            let keyString = specialKeyName(for: event.keyCode) ?? chars
            parts.append(keyString)
        }

        // Don't show just modifier keys
        if parts.count <= 1 && event.charactersIgnoringModifiers?.isEmpty ?? true {
            return ""
        }

        return parts.joined()
    }

    private func specialKeyName(for keyCode: UInt16) -> String? {
        switch keyCode {
        case 36: return "\u{21A9}" // Return
        case 48: return "\u{21E5}" // Tab
        case 49: return "Space"
        case 51: return "\u{232B}" // Delete
        case 53: return "Esc"
        case 123: return "\u{2190}" // Left arrow
        case 124: return "\u{2192}" // Right arrow
        case 125: return "\u{2193}" // Down arrow
        case 126: return "\u{2191}" // Up arrow
        case 117: return "\u{2326}" // Forward Delete
        case 115: return "Home"
        case 119: return "End"
        case 116: return "PgUp"
        case 121: return "PgDn"
        default: return nil
        }
    }
}

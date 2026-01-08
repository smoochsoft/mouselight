import Cocoa
import Carbon

enum ClickType {
    case left
    case right
    case other
}

// Global handler for Carbon hotkey events
private weak var sharedEventMonitor: EventMonitor?
private var sharedEventHandlerRef: EventHandlerRef?
private var lastCarbonHotkeyTime: CFAbsoluteTime = 0  // Debounce at source

class EventMonitor {
    // Mouse monitoring - use NSEvent global monitors (more reliable for inactive apps)
    private var globalMouseClickMonitor: Any?
    private var globalMouseMoveMonitor: Any?
    private var localMouseMonitor: Any?

    // Keyboard monitoring
    private var localMonitor: Any?
    private var globalKeyMonitor: Any?
    private var hotkeyRef: EventHotKeyRef?
    private var hotkeyID: EventHotKeyID?

    private let onMouseMove: (NSPoint) -> Void
    private let onMouseClick: (NSPoint, ClickType) -> Void
    private let onHotkey: () -> Void
    private let onEscape: (() -> Void)?

    private let settings = AppSettings.shared

    init(
        onMouseMove: @escaping (NSPoint) -> Void,
        onMouseClick: @escaping (NSPoint, ClickType) -> Void,
        onHotkey: @escaping () -> Void,
        onEscape: (() -> Void)? = nil
    ) {
        self.onMouseMove = onMouseMove
        self.onMouseClick = onMouseClick
        self.onHotkey = onHotkey
        self.onEscape = onEscape
    }

    func start() {
        startMouseMonitoring()
        startKeyboardMonitoring()
    }

    func stop() {
        stopMouseMonitoring()
        stopKeyboardMonitoring()
    }

    /// Called by Carbon hotkey handler
    func handleHotkeyEvent() {
        #if DEBUG
        print("[MouseLight] handleHotkeyEvent called")
        #endif
        onHotkey()
    }

    // MARK: - Mouse Monitoring

    private func startMouseMonitoring() {
        // Use NSEvent global monitors instead of CGEventTap
        // Global monitors are more reliable for inactive/background apps
        // CGEventTap stops receiving events when app loses focus

        // Monitor mouse clicks globally (in other apps)
        globalMouseClickMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]
        ) { [weak self] event in
            self?.handleMouseClickEvent(event)
        }

        // Monitor mouse movement globally
        globalMouseMoveMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged]
        ) { [weak self] event in
            self?.onMouseMove(event.locationInWindow)
        }

        // Also monitor locally (when clicking in our own windows)
        localMouseMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]
        ) { [weak self] event in
            self?.handleMouseClickEvent(event)
            return event
        }

        #if DEBUG
        print("[MouseLight] Mouse monitoring started using NSEvent global monitors")
        #endif
    }

    private func stopMouseMonitoring() {
        if let monitor = globalMouseClickMonitor {
            NSEvent.removeMonitor(monitor)
        }
        if let monitor = globalMouseMoveMonitor {
            NSEvent.removeMonitor(monitor)
        }
        if let monitor = localMouseMonitor {
            NSEvent.removeMonitor(monitor)
        }
        globalMouseClickMonitor = nil
        globalMouseMoveMonitor = nil
        localMouseMonitor = nil
    }

    private func handleMouseClickEvent(_ event: NSEvent) {
        let screenPoint = NSEvent.mouseLocation

        let clickType: ClickType
        switch event.type {
        case .leftMouseDown:
            clickType = .left
        case .rightMouseDown:
            clickType = .right
        case .otherMouseDown:
            clickType = .other
        default:
            return
        }

        onMouseClick(screenPoint, clickType)
    }

    // MARK: - Keyboard Monitoring

    private func startKeyboardMonitoring() {
        // Register Carbon hotkey for reliable system-wide hotkey detection
        registerCarbonHotkey()

        // Monitor for Escape key to deactivate spotlight
        globalKeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleEscapeKey(event)
        }

        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleEscapeKey(event)
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

    private func handleEscapeKey(_ event: NSEvent) {
        if event.keyCode == 53 {  // Escape key
            onEscape?()
        }
    }

    // MARK: - Carbon Hotkey Registration

    private func registerCarbonHotkey() {
        sharedEventMonitor = self

        // Install event handler for hotkey events (only once)
        if sharedEventHandlerRef == nil {
            var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))

            let handler: EventHandlerUPP = { _, event, _ -> OSStatus in
                // Debounce at source - before async dispatch
                // This prevents the race condition where both events get queued
                // before either executes
                let now = CFAbsoluteTimeGetCurrent()
                if (now - lastCarbonHotkeyTime) < 0.3 {
                    #if DEBUG
                    print("[MouseLight] Carbon hotkey debounced at source")
                    #endif
                    return noErr
                }
                lastCarbonHotkeyTime = now

                guard let monitor = sharedEventMonitor else { return noErr }
                DispatchQueue.main.async {
                    monitor.handleHotkeyEvent()
                }
                return noErr
            }

            var handlerRef: EventHandlerRef?
            InstallEventHandler(GetApplicationEventTarget(), handler, 1, &eventType, nil, &handlerRef)
            sharedEventHandlerRef = handlerRef
        }

        // Register the hotkey
        let keyCode = UInt32(settings.spotlightHotkeyKeyCode)
        let modifiers = carbonModifiers(from: settings.spotlightHotkeyModifiers)

        let hotkeyIDValue = EventHotKeyID(signature: OSType(0x4D4C4854), id: 1) // 'MLHT' signature
        hotkeyID = hotkeyIDValue
        var hotKeyRef: EventHotKeyRef?

        let status = RegisterEventHotKey(keyCode, modifiers, hotkeyIDValue, GetApplicationEventTarget(), 0, &hotKeyRef)

        if status == noErr {
            hotkeyRef = hotKeyRef
        }
    }

    private func unregisterCarbonHotkey() {
        if let ref = hotkeyRef {
            UnregisterEventHotKey(ref)
            hotkeyRef = nil
        }
        hotkeyID = nil
        sharedEventMonitor = nil
    }

    /// Clean up the shared event handler (call when app terminates)
    static func cleanupEventHandler() {
        if let handlerRef = sharedEventHandlerRef {
            RemoveEventHandler(handlerRef)
            sharedEventHandlerRef = nil
        }
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
}

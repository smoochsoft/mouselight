import Cocoa
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var spotlightActive = false

    // Overlay windows
    private var spotlightWindow: SpotlightOverlayWindow?
    private var clickIndicatorWindow: ClickIndicatorWindow?

    // Windows
    private var permissionsWindow: NSWindow?
    private var preferencesWindow: NSWindow?
    private var aboutWindow: NSWindow?
    private var helperWindow: NSWindow?  // Keeps rendering context active

    // Event monitoring
    private var eventMonitor: EventMonitor?
    private var mousePollingTimer: Timer?  // Fallback for when event tap fails

    // Settings
    private let settings = AppSettings.shared

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Set activation policy to accessory - allows overlay windows to render
        // without showing in Dock (LSUIElement handles Dock hiding)
        NSApp.setActivationPolicy(.accessory)

        // Skip onboarding if permission is already granted
        if PermissionsManager.shared.hasAccessibilityPermission {
            settings.hasCompletedOnboarding = true
        }

        // Check if onboarding is needed
        if !settings.hasCompletedOnboarding {
            showPermissionsWindow()
        } else {
            setupApp()
        }
    }

    private func setupApp() {
        setupStatusItem()
        setupOverlayWindows()
        checkPermissionsAndStart()

        // Observe hotkey changes to update Carbon registration
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(hotkeyDidChange),
            name: .hotkeyDidChange,
            object: nil
        )
    }

    @objc private func hotkeyDidChange() {
        eventMonitor?.updateHotkey()
    }

    // MARK: - Permissions Window

    private func showPermissionsWindow() {
        let permissionsView = PermissionsWindowView(onComplete: { [weak self] in
            self?.permissionsWindow?.close()
            self?.setupApp()
        })

        permissionsWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 420),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        permissionsWindow?.title = "MouseLight Security & Privacy"
        permissionsWindow?.contentView = NSHostingView(rootView: permissionsView)
        permissionsWindow?.center()
        permissionsWindow?.makeKeyAndOrderFront(nil)

        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: - Status Bar Setup

    private func setupStatusItem() {
        guard settings.showInMenuBar else { return }

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            button.image = NSImage(named: "MenuBarIcon")
            button.image?.isTemplate = true
        }

        setupMenu()
    }

    private func setupMenu() {
        let menu = NSMenu()

        let toggleItem = NSMenuItem(title: "Toggle Spotlight", action: #selector(toggleSpotlightFromMenu), keyEquivalent: "")
        menu.addItem(toggleItem)

        menu.addItem(NSMenuItem.separator())

        let spotlightItem = NSMenuItem(title: "Spotlight Effect", action: #selector(toggleSpotlightEnabled), keyEquivalent: "")
        spotlightItem.state = settings.spotlightEnabled ? .on : .off
        menu.addItem(spotlightItem)

        let clicksItem = NSMenuItem(title: "Click Indicators", action: #selector(toggleClicksEnabled), keyEquivalent: "")
        clicksItem.state = settings.clicksEnabled ? .on : .off
        menu.addItem(clicksItem)

        menu.addItem(NSMenuItem.separator())

        menu.addItem(NSMenuItem(title: "About MouseLight...", action: #selector(openAbout), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Preferences...", action: #selector(openPreferences), keyEquivalent: ","))

        menu.addItem(NSMenuItem.separator())

        menu.addItem(NSMenuItem(title: "Quit MouseLight", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        statusItem?.menu = menu
    }

    // MARK: - Overlay Windows

    private func setupOverlayWindows() {
        // Create a tiny off-screen helper window to keep rendering context active
        // This fixes overlay windows not rendering for menu bar apps
        setupHelperWindow()

        spotlightWindow = SpotlightOverlayWindow()
        clickIndicatorWindow = ClickIndicatorWindow()

        // Setup auto-deactivate callback
        spotlightWindow?.onAutoDeactivate = { [weak self] in
            self?.deactivateSpotlight()
        }
    }

    private func setupHelperWindow() {
        // Create a 1x1 pixel window off-screen to maintain rendering context
        helperWindow = NSWindow(
            contentRect: NSRect(x: -10000, y: -10000, width: 1, height: 1),
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        helperWindow?.level = .normal
        helperWindow?.isOpaque = false
        helperWindow?.backgroundColor = .clear
        helperWindow?.ignoresMouseEvents = true
        helperWindow?.collectionBehavior = [.canJoinAllSpaces, .stationary]
        helperWindow?.orderFrontRegardless()
    }

    // MARK: - Permissions & Event Monitoring

    private func checkPermissionsAndStart() {
        // Always try to start event monitoring - it will fail gracefully if no permission
        // The onboarding flow already handles permission requests, so we don't show
        // another alert here. AXIsProcessTrusted() can briefly return false on launch
        // even when permission is granted.
        startEventMonitoring()
    }

    private func startEventMonitoring() {
        eventMonitor = EventMonitor(
            onMouseMove: { [weak self] location in
                self?.spotlightWindow?.updateCursorPosition(location)
            },
            onMouseClick: { [weak self] location, clickType in
                self?.handleClick(at: location, clickType: clickType)
            },
            onHotkey: { [weak self] in
                self?.toggleSpotlight()
            },
            onEscape: { [weak self] in
                // Escape key deactivates spotlight
                if self?.spotlightActive == true {
                    self?.deactivateSpotlight()
                }
            }
        )
        eventMonitor?.start()
    }

    // MARK: - Click Handling

    private func handleClick(at location: NSPoint, clickType: ClickType) {
        guard settings.clicksEnabled else { return }

        // Check if clicks should work standalone or only with spotlight
        if settings.clicksStandalone || spotlightActive {
            clickIndicatorWindow?.showClick(at: location, clickType: clickType)
        }
    }

    // MARK: - Spotlight Actions

    /// Menu toggle - no protection window, direct toggle
    @objc private func toggleSpotlightFromMenu() {
        guard settings.spotlightEnabled else { return }
        if spotlightActive {
            deactivateSpotlight()
        } else {
            activateSpotlight()
        }
    }

    @objc private func toggleSpotlight() {
        guard settings.spotlightEnabled else { return }

        #if DEBUG
        print("[MouseLight] toggleSpotlight: spotlightActive=\(spotlightActive)")
        #endif

        // Note: Debounce for Carbon double-fire is now handled at the source
        // in EventMonitor before events are dispatched to main queue

        if spotlightActive {
            deactivateSpotlight()
        } else {
            activateSpotlight()
        }
    }

    private func activateSpotlight() {
        spotlightActive = true

        // Activate app to ensure overlay windows render properly
        // (same as when Preferences window is open)
        NSApp.activate(ignoringOtherApps: true)

        spotlightWindow?.show()
        updateStatusIcon(active: true)
        startMousePolling()
    }

    private func deactivateSpotlight() {
        #if DEBUG
        print("[MouseLight] deactivateSpotlight() called")
        #endif
        spotlightActive = false
        spotlightWindow?.hide()
        updateStatusIcon(active: false)
        stopMousePolling()
    }

    // MARK: - Mouse Polling Fallback

    /// Fallback polling mechanism for mouse position when CGEventTap isn't working
    private func startMousePolling() {
        stopMousePolling()
        // Use Timer() + manual add to avoid double-scheduling
        mousePollingTimer = Timer(timeInterval: 1.0/60.0, repeats: true) { [weak self] _ in
            guard let self = self, self.spotlightActive else { return }
            self.updateSpotlightFromCurrentMousePosition()
        }
        // Add to common mode so it fires during UI tracking (scrolling, etc.)
        if let timer = mousePollingTimer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }

    private func stopMousePolling() {
        mousePollingTimer?.invalidate()
        mousePollingTimer = nil
    }

    private func updateSpotlightFromCurrentMousePosition() {
        // Get current mouse position using NSEvent (doesn't require accessibility)
        let mouseLocation = NSEvent.mouseLocation
        spotlightWindow?.updateCursorPosition(mouseLocation)
    }

    // MARK: - Menu Actions

    @objc private func toggleSpotlightEnabled() {
        settings.spotlightEnabled.toggle()
        if !settings.spotlightEnabled && spotlightActive {
            deactivateSpotlight()
        }
        setupMenu()
    }

    @objc private func toggleClicksEnabled() {
        settings.clicksEnabled.toggle()
        setupMenu()
    }

    @objc private func openAbout() {
        NSApp.activate(ignoringOtherApps: true)

        if let window = aboutWindow, window.isVisible {
            window.makeKeyAndOrderFront(nil)
            window.orderFrontRegardless()
            return
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 550),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "About MouseLight"
        window.contentView = NSHostingView(rootView: AboutView())
        window.isReleasedWhenClosed = false
        window.center()
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
        aboutWindow = window
    }

    @objc private func openPreferences() {
        // Activate app first to ensure window comes to front
        NSApp.activate(ignoringOtherApps: true)

        // If preferences window exists and is visible, just bring it to front
        if let window = preferencesWindow, window.isVisible {
            window.makeKeyAndOrderFront(nil)
            window.orderFrontRegardless()
            return
        }

        // Create preferences window
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 420),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "MouseLight"
        window.contentView = NSHostingView(rootView: PreferencesView())
        window.isReleasedWhenClosed = false  // Prevent crash from dangling pointer
        window.center()
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
        preferencesWindow = window
    }

    private func updateStatusIcon(active: Bool) {
        if let button = statusItem?.button {
            let imageName = active ? "MenuBarIconActive" : "MenuBarIcon"
            button.image = NSImage(named: imageName)
            button.image?.isTemplate = true
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        NotificationCenter.default.removeObserver(self)
        eventMonitor?.stop()
        EventMonitor.cleanupEventHandler()
        stopMousePolling()
    }
}

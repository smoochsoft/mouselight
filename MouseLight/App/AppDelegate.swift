import Cocoa
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var spotlightActive = false

    // Overlay windows
    private var spotlightWindow: SpotlightOverlayWindow?
    private var clickIndicatorWindow: ClickIndicatorWindow?
    private var keystrokeWindow: KeystrokeOverlayWindow?

    // Windows
    private var permissionsWindow: NSWindow?
    private var preferencesWindow: NSWindow?

    // Event monitoring
    private var eventMonitor: EventMonitor?
    private var mousePollingTimer: Timer?  // Fallback for when event tap fails

    // Settings
    private let settings = AppSettings.shared

    func applicationDidFinishLaunching(_ notification: Notification) {
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

        let toggleItem = NSMenuItem(title: "Toggle Spotlight", action: #selector(toggleSpotlight), keyEquivalent: "")
        menu.addItem(toggleItem)

        menu.addItem(NSMenuItem.separator())

        let spotlightItem = NSMenuItem(title: "Spotlight Effect", action: #selector(toggleSpotlightEnabled), keyEquivalent: "")
        spotlightItem.state = settings.spotlightEnabled ? .on : .off
        menu.addItem(spotlightItem)

        let clicksItem = NSMenuItem(title: "Click Indicators", action: #selector(toggleClicksEnabled), keyEquivalent: "")
        clicksItem.state = settings.clicksEnabled ? .on : .off
        menu.addItem(clicksItem)

        let keystrokesItem = NSMenuItem(title: "Keystroke Display", action: #selector(toggleKeystrokesEnabled), keyEquivalent: "")
        keystrokesItem.state = settings.keystrokesEnabled ? .on : .off
        menu.addItem(keystrokesItem)

        menu.addItem(NSMenuItem.separator())

        menu.addItem(NSMenuItem(title: "Preferences...", action: #selector(openPreferences), keyEquivalent: ","))

        menu.addItem(NSMenuItem.separator())

        menu.addItem(NSMenuItem(title: "Quit MouseLight", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        statusItem?.menu = menu
    }

    // MARK: - Overlay Windows

    private func setupOverlayWindows() {
        spotlightWindow = SpotlightOverlayWindow()
        clickIndicatorWindow = ClickIndicatorWindow()
        keystrokeWindow = KeystrokeOverlayWindow()

        // Setup auto-deactivate callback
        spotlightWindow?.onAutoDeactivate = { [weak self] in
            self?.deactivateSpotlight()
        }
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
            onKeyPress: { [weak self] keystroke in
                self?.handleKeystroke(keystroke)
            },
            onHotkey: { [weak self] in
                self?.toggleSpotlight()
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

    // MARK: - Keystroke Handling

    private func handleKeystroke(_ keystroke: String) {
        guard settings.keystrokesEnabled else { return }

        // Check if keystrokes should work standalone or only with spotlight
        if settings.keystrokesStandalone || spotlightActive {
            keystrokeWindow?.showKeystroke(keystroke)
        }
    }

    // MARK: - Spotlight Actions

    @objc private func toggleSpotlight() {
        guard settings.spotlightEnabled else { return }

        if spotlightActive {
            deactivateSpotlight()
        } else {
            activateSpotlight()
        }
    }

    private func activateSpotlight() {
        spotlightActive = true
        spotlightWindow?.show()
        updateStatusIcon(active: true)
        startMousePolling()  // Fallback polling in case event tap isn't working
    }

    private func deactivateSpotlight() {
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

    @objc private func toggleKeystrokesEnabled() {
        settings.keystrokesEnabled.toggle()
        setupMenu()
    }

    @objc private func openPreferences() {
        // If preferences window exists, just bring it to front
        if let window = preferencesWindow, window.isVisible {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        // Create preferences window
        preferencesWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 420),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        preferencesWindow?.title = "MouseLight"
        preferencesWindow?.contentView = NSHostingView(rootView: PreferencesView())
        preferencesWindow?.center()
        preferencesWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
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

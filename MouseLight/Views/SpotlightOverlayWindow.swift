import Cocoa

/// Manages spotlight overlay across all screens
class SpotlightOverlayWindow: NSObject {
    private var screenWindows: [NSWindow] = []
    private var spotlightViews: [SpotlightView] = []
    private var zoomAnimationTimer: Timer?
    private var autoDeactivateTimer: Timer?
    private let settings = AppSettings.shared

    // Callback for auto-deactivate
    var onAutoDeactivate: (() -> Void)?

    // Track current cursor position for all views
    private var currentCursorPosition: NSPoint = .zero

    override init() {
        super.init()
        createWindowsForAllScreens()

        // Observe screen changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenConfigurationChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    private func createWindowsForAllScreens() {
        // Remove existing windows
        screenWindows.forEach { $0.orderOut(nil) }
        screenWindows.removeAll()
        spotlightViews.removeAll()

        // Create a window for each screen
        for screen in NSScreen.screens {
            let window = createOverlayWindow(for: screen)
            let view = SpotlightView(frame: NSRect(origin: .zero, size: screen.frame.size))
            view.screenFrame = screen.frame  // Pass screen frame for coordinate conversion
            window.contentView = view

            screenWindows.append(window)
            spotlightViews.append(view)
        }
    }

    private func createOverlayWindow(for screen: NSScreen) -> NSWindow {
        let window = NSWindow(
            contentRect: screen.frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )

        // Use a level above normal windows but below the menu bar/status items
        window.level = NSWindow.Level(rawValue: 1)
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        window.ignoresMouseEvents = true
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = false
        window.alphaValue = 0

        return window
    }

    @objc private func screenConfigurationChanged() {
        createWindowsForAllScreens()
        // Restore cursor position to all views
        updateCursorPosition(currentCursorPosition)
    }

    func updateCursorPosition(_ screenPosition: NSPoint) {
        currentCursorPosition = screenPosition

        // Update all views with the cursor position (in screen coordinates)
        for view in spotlightViews {
            view.cursorPosition = screenPosition
            view.needsDisplay = true
        }
    }

    func show() {
        // Show all windows
        for window in screenWindows {
            window.orderFrontRegardless()
        }

        // Start tracking cursor position immediately
        if let location = CGEvent(source: nil)?.location {
            let screenPoint = convertToScreenCoordinates(location)
            updateCursorPosition(screenPoint)
        }

        if settings.animateZoom {
            showWithZoom()
        } else {
            showWithFade()
        }

        // Start auto-deactivate timer if enabled
        startAutoDeactivateTimer()
    }

    func hide() {
        // Cancel any pending timers
        autoDeactivateTimer?.invalidate()
        autoDeactivateTimer = nil
        zoomAnimationTimer?.invalidate()
        zoomAnimationTimer = nil

        if settings.animateZoom {
            hideWithZoom()
        } else {
            hideWithFade()
        }
    }

    // MARK: - Simple Fade Animation

    private func showWithFade() {
        for view in spotlightViews {
            view.zoomScale = 1.0
            view.needsDisplay = true
        }

        NSAnimationContext.runAnimationGroup { context in
            context.duration = settings.spotlightAnimationDuration
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            for window in screenWindows {
                window.animator().alphaValue = 1
            }
        }
    }

    private func hideWithFade() {
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = settings.spotlightAnimationDuration
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            for window in self.screenWindows {
                window.animator().alphaValue = 0
            }
        }, completionHandler: { [weak self] in
            self?.screenWindows.forEach { $0.orderOut(nil) }
        })
    }

    // MARK: - Zoom Animation

    private func showWithZoom() {
        // Start small and zoom out to full size
        for view in spotlightViews {
            view.zoomScale = 0.3
            view.needsDisplay = true
        }
        for window in screenWindows {
            window.alphaValue = 1
        }

        let duration = settings.spotlightAnimationDuration
        let startTime = CACurrentMediaTime()
        let startScale: CGFloat = 0.3
        let endScale: CGFloat = 1.0

        zoomAnimationTimer?.invalidate()
        zoomAnimationTimer = Timer(timeInterval: 1.0/60.0, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }

            let elapsed = CACurrentMediaTime() - startTime
            var progress = elapsed / duration

            if progress >= 1.0 {
                progress = 1.0
                timer.invalidate()
                self.zoomAnimationTimer = nil
            }

            // Ease out cubic
            let easedProgress = 1 - pow(1 - progress, 3)
            let newScale = startScale + (endScale - startScale) * easedProgress

            for view in self.spotlightViews {
                view.zoomScale = newScale
                view.needsDisplay = true
            }
        }

        if let timer = zoomAnimationTimer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }

    private func hideWithZoom() {
        let duration = settings.spotlightAnimationDuration
        let startTime = CACurrentMediaTime()
        let startScale = spotlightViews.first?.zoomScale ?? 1.0
        let endScale: CGFloat = 0.3

        zoomAnimationTimer?.invalidate()
        zoomAnimationTimer = Timer(timeInterval: 1.0/60.0, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }

            let elapsed = CACurrentMediaTime() - startTime
            var progress = elapsed / duration

            if progress >= 1.0 {
                progress = 1.0
                timer.invalidate()
                self.zoomAnimationTimer = nil
                self.screenWindows.forEach { $0.orderOut(nil) }
                return
            }

            // Ease in cubic
            let easedProgress = pow(progress, 3)
            let newScale = startScale + (endScale - startScale) * easedProgress
            let newAlpha = CGFloat(1 - progress)

            for view in self.spotlightViews {
                view.zoomScale = newScale
                view.needsDisplay = true
            }
            for window in self.screenWindows {
                window.alphaValue = newAlpha
            }
        }

        if let timer = zoomAnimationTimer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }

    // MARK: - Auto-Deactivate Timer

    private func startAutoDeactivateTimer() {
        autoDeactivateTimer?.invalidate()
        autoDeactivateTimer = nil

        guard settings.autoDeactivate else { return }

        let seconds = settings.autoDeactivateSeconds
        autoDeactivateTimer = Timer.scheduledTimer(withTimeInterval: seconds, repeats: false) { [weak self] _ in
            DispatchQueue.main.async {
                self?.onAutoDeactivate?()
            }
        }
    }

    // Reset timer when user moves mouse (optional - to keep spotlight active while in use)
    func resetAutoDeactivateTimer() {
        if settings.autoDeactivate {
            startAutoDeactivateTimer()
        }
    }

    private func convertToScreenCoordinates(_ cgPoint: CGPoint) -> NSPoint {
        // CGEvent origin is at TOP-LEFT of PRIMARY screen, Y increases down
        // AppKit origin is at BOTTOM-LEFT of primary screen, Y increases up
        // We must use the PRIMARY screen (screens[0]), not NSScreen.main
        guard let primaryScreen = NSScreen.screens.first else {
            return NSPoint(x: cgPoint.x, y: cgPoint.y)
        }
        return NSPoint(x: cgPoint.x, y: primaryScreen.frame.maxY - cgPoint.y)
    }
}

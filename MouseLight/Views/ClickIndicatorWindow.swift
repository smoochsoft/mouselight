import Cocoa

class ClickIndicatorWindow: NSWindow {
    private var clickViews: [ClickIndicatorView] = []

    init() {
        let screenFrame = NSScreen.screens.reduce(NSRect.zero) { result, screen in
            result.union(screen.frame)
        }

        super.init(
            contentRect: screenFrame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )

        // Use a level above normal windows but below the menu bar/status items
        self.level = NSWindow.Level(rawValue: 1)
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        self.ignoresMouseEvents = true
        self.backgroundColor = .clear
        self.isOpaque = false
        self.hasShadow = false

        let containerView = NSView(frame: screenFrame)
        containerView.wantsLayer = true
        self.contentView = containerView

        self.orderFrontRegardless()
    }

    func showClick(at position: NSPoint, clickType: ClickType) {
        let settings = AppSettings.shared

        // Determine color based on click type
        let color: NSColor
        switch clickType {
        case .left:
            color = settings.leftClickColor
        case .right:
            color = settings.rightClickColor
        case .other:
            color = settings.otherClickColor
        }

        let radius = CGFloat(settings.clickRadius)

        let clickView = ClickIndicatorView(
            frame: NSRect(
                x: position.x - radius,
                y: position.y - radius,
                width: radius * 2,
                height: radius * 2
            ),
            color: color
        )

        contentView?.addSubview(clickView)
        clickViews.append(clickView)

        // Play click sound if enabled
        if settings.clickSoundEnabled {
            playClickSound(volume: Float(settings.clickSoundVolume / 100.0))
        }

        // Animate the click indicator
        clickView.animate { [weak self, weak clickView] in
            clickView?.removeFromSuperview()
            if let view = clickView {
                self?.clickViews.removeAll { $0 === view }
            }
        }
    }

    private func playClickSound(volume: Float) {
        // Use NSSound for system sounds with volume control
        if let sound = NSSound(named: "Pop") {
            sound.volume = volume
            sound.play()
        }
    }
}

class ClickIndicatorView: NSView {
    private let color: NSColor
    private var scale: CGFloat = 0.3
    private var opacity: CGFloat = 0.8

    init(frame: NSRect, color: NSColor) {
        self.color = color
        super.init(frame: frame)
        self.wantsLayer = true
        self.layer?.backgroundColor = NSColor.clear.cgColor
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        guard NSGraphicsContext.current != nil else { return }

        let center = NSPoint(x: bounds.midX, y: bounds.midY)
        let maxRadius = min(bounds.width, bounds.height) / 2

        // Draw expanding circle
        let currentRadius = maxRadius * scale
        let circlePath = NSBezierPath(
            ovalIn: NSRect(
                x: center.x - currentRadius,
                y: center.y - currentRadius,
                width: currentRadius * 2,
                height: currentRadius * 2
            )
        )

        // Fill with semi-transparent color
        color.withAlphaComponent(opacity * 0.3).setFill()
        circlePath.fill()

        // Stroke with solid color
        color.withAlphaComponent(opacity).setStroke()
        circlePath.lineWidth = 3
        circlePath.stroke()
    }

    func animate(completion: @escaping () -> Void) {
        let duration = AppSettings.shared.clickAnimationDuration

        // Use CADisplayLink-style animation with timer
        let startTime = CACurrentMediaTime()
        let timer = Timer.scheduledTimer(withTimeInterval: 1.0/60.0, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }

            let elapsed = CACurrentMediaTime() - startTime
            let progress = min(elapsed / duration, 1.0)

            // Ease out curve
            let easedProgress = 1 - pow(1 - progress, 3)

            self.scale = 0.3 + (easedProgress * 0.7)
            self.opacity = 0.8 * (1 - progress)
            self.needsDisplay = true

            if progress >= 1.0 {
                timer.invalidate()
                completion()
            }
        }

        RunLoop.main.add(timer, forMode: .common)
    }
}

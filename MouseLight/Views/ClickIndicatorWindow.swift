import Cocoa
import QuartzCore

/// Manages click indicator visualization using a small window that moves to click position
/// Uses CVDisplayLink for animation timing - works regardless of app focus state
class ClickIndicatorWindow: NSObject {
    private var indicatorWindows: [ClickWindow] = []
    private let settings = AppSettings.shared

    func showClick(at position: NSPoint, clickType: ClickType) {

        let window = ClickWindow(at: position, color: settings.clickColor, radius: CGFloat(settings.clickRadius))
        indicatorWindows.append(window)
        window.show(duration: settings.clickAnimationDuration) { [weak self, weak window] in
            if let window = window {
                self?.indicatorWindows.removeAll { $0 === window }
            }
        }
    }
}

// MARK: - Individual Click Window

/// A small window that appears at a click position and animates using CVDisplayLink
private class ClickWindow: NSWindow {
    private let circleLayer = CAShapeLayer()
    private var displayLink: CVDisplayLink?
    private var startTime: CFAbsoluteTime = 0
    private var animDuration: Double = 0.3
    private var onComplete: (() -> Void)?
    private var isAnimating = false

    init(at screenPosition: NSPoint, color: NSColor, radius: CGFloat) {
        let strokeWidth: CGFloat = 4
        let padding = strokeWidth / 2 + 2
        let diameter = radius * 2
        let windowSize = diameter + padding * 2

        let frame = NSRect(
            x: screenPosition.x - windowSize / 2,
            y: screenPosition.y - windowSize / 2,
            width: windowSize,
            height: windowSize
        )

        super.init(
            contentRect: frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )

        // Use screen saver level - renders regardless of app focus
        self.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.screenSaverWindow)))
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        self.ignoresMouseEvents = true
        self.backgroundColor = .clear
        self.isOpaque = false
        self.hasShadow = false

        // Create layer-backed content view
        let contentView = NSView(frame: NSRect(x: 0, y: 0, width: windowSize, height: windowSize))
        contentView.wantsLayer = true
        contentView.layer?.backgroundColor = NSColor.clear.cgColor
        self.contentView = contentView

        // Setup circle layer
        let circleRect = CGRect(x: padding, y: padding, width: diameter, height: diameter)
        let circlePath = CGPath(ellipseIn: circleRect, transform: nil)
        circleLayer.path = circlePath
        circleLayer.fillColor = color.withAlphaComponent(0.5).cgColor
        circleLayer.strokeColor = color.cgColor
        circleLayer.lineWidth = strokeWidth
        circleLayer.frame = CGRect(x: 0, y: 0, width: windowSize, height: windowSize)
        circleLayer.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        circleLayer.position = CGPoint(x: windowSize / 2, y: windowSize / 2)

        contentView.layer?.addSublayer(circleLayer)
    }

    deinit {
        stopDisplayLink()
    }

    func show(duration: Double, completion: @escaping () -> Void) {
        self.animDuration = duration
        self.onComplete = completion
        self.startTime = CFAbsoluteTimeGetCurrent()
        self.isAnimating = true

        // Start with small scale
        circleLayer.transform = CATransform3DMakeScale(0.5, 0.5, 1)
        circleLayer.opacity = 1.0

        self.orderFrontRegardless()

        // Start CVDisplayLink for hardware-synced animation
        startDisplayLink()
    }

    private func startDisplayLink() {
        var link: CVDisplayLink?
        CVDisplayLinkCreateWithActiveCGDisplays(&link)
        guard let displayLink = link else { return }

        self.displayLink = displayLink

        // Set the callback - CVDisplayLink calls this at VSync rate
        let callback: CVDisplayLinkOutputCallback = { displayLink, inNow, inOutputTime, flagsIn, flagsOut, displayLinkContext -> CVReturn in
            guard let context = displayLinkContext else { return kCVReturnSuccess }
            let window = Unmanaged<ClickWindow>.fromOpaque(context).takeUnretainedValue()

            // Dispatch to main run loop and wake it up
            // This is more reliable than DispatchQueue.main.async for menu bar apps
            CFRunLoopPerformBlock(CFRunLoopGetMain(), CFRunLoopMode.commonModes.rawValue) {
                window.updateAnimation()
            }
            CFRunLoopWakeUp(CFRunLoopGetMain())

            return kCVReturnSuccess
        }

        let pointer = Unmanaged.passUnretained(self).toOpaque()
        CVDisplayLinkSetOutputCallback(displayLink, callback, pointer)
        CVDisplayLinkStart(displayLink)
    }

    private func stopDisplayLink() {
        if let displayLink = displayLink {
            CVDisplayLinkStop(displayLink)
            self.displayLink = nil
        }
    }

    private func updateAnimation() {
        guard isAnimating else { return }

        let elapsed = CFAbsoluteTimeGetCurrent() - startTime
        let progress = min(elapsed / animDuration, 1.0)

        // Scale: 0.5 -> 1.0 with ease out
        let easedProgress = 1 - pow(1 - progress, 3)
        let scale = 0.5 + 0.5 * easedProgress

        // Opacity: 1.0 -> 0.0
        let opacity = Float(1.0 - progress)

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        circleLayer.transform = CATransform3DMakeScale(scale, scale, 1)
        circleLayer.opacity = opacity
        CATransaction.commit()

        if progress >= 1.0 {
            isAnimating = false
            stopDisplayLink()
            self.orderOut(nil)
            onComplete?()
        }
    }
}

import Cocoa

class SpotlightView: NSView {
    /// Cursor position in screen coordinates (not view coordinates)
    var cursorPosition: NSPoint = .zero
    var zoomScale: CGFloat = 1.0 // For zoom animation

    /// The screen frame this view represents (for coordinate conversion)
    var screenFrame: NSRect = .zero

    /// Click indicators to draw
    private var clickIndicators: [ClickIndicatorData] = []
    private var clickAnimationTimer: Timer?

    struct ClickIndicatorData {
        let id = UUID()
        let screenPosition: NSPoint
        let color: NSColor
        let radius: CGFloat
        let startTime: CFAbsoluteTime
        let duration: Double
    }

    private let settings = AppSettings.shared

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        self.wantsLayer = true
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        self.wantsLayer = true
    }

    // MARK: - Click Indicators

    func addClickIndicator(at screenPosition: NSPoint) {
        let indicator = ClickIndicatorData(
            screenPosition: screenPosition,
            color: settings.clickColor,
            radius: CGFloat(settings.clickRadius),
            startTime: CFAbsoluteTimeGetCurrent(),
            duration: settings.clickAnimationDuration
        )
        clickIndicators.append(indicator)
        startClickAnimationTimer()

        #if DEBUG
        print("[MouseLight] SpotlightView.addClickIndicator - total: \(clickIndicators.count)")
        #endif

        // Force immediate redraw (don't wait for timer's first tick)
        needsDisplay = true

        // Schedule removal
        DispatchQueue.main.asyncAfter(deadline: .now() + indicator.duration + 0.1) { [weak self] in
            self?.clickIndicators.removeAll { $0.id == indicator.id }
            if self?.clickIndicators.isEmpty == true {
                self?.stopClickAnimationTimer()
            }
        }
    }

    func clearClickIndicators() {
        clickIndicators.removeAll()
        stopClickAnimationTimer()
    }

    private func startClickAnimationTimer() {
        guard clickAnimationTimer == nil else { return }
        // Use Timer() + RunLoop.main.add with .common mode
        // This ensures the timer fires even when the app has no active windows
        // (same pattern as spotlight zoom animation)
        clickAnimationTimer = Timer(timeInterval: 1.0/60.0, repeats: true) { [weak self] _ in
            self?.needsDisplay = true
        }
        if let timer = clickAnimationTimer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }

    private func stopClickAnimationTimer() {
        clickAnimationTimer?.invalidate()
        clickAnimationTimer = nil
    }

    /// Convert screen coordinates to view coordinates
    private var viewCursorPosition: NSPoint {
        // Convert from screen coordinates to this view's local coordinates
        // Screen coordinates have origin at bottom-left of primary screen
        // View coordinates have origin at bottom-left of this view (which matches screen origin)
        return NSPoint(
            x: cursorPosition.x - screenFrame.origin.x,
            y: cursorPosition.y - screenFrame.origin.y
        )
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        guard let context = NSGraphicsContext.current?.cgContext else { return }

        let baseRadius = CGFloat(settings.spotlightRadius)
        let radius = baseRadius * zoomScale
        let dimOpacity = CGFloat(settings.spotlightDimOpacity)
        let blurPercent = CGFloat(settings.spotlightBlur) / 100.0
        let shape = settings.spotlightShape

        // Calculate blur zone (percentage of radius for soft edge)
        let blurWidth = radius * blurPercent
        let innerRadius = max(0, radius - blurWidth)

        // Use view-local cursor position
        let center = viewCursorPosition

        context.saveGState()

        if blurPercent > 0 {
            // Draw with gradient blur edge
            drawWithBlurredEdge(
                context: context,
                center: center,
                innerRadius: innerRadius,
                outerRadius: radius,
                dimOpacity: dimOpacity,
                shape: shape
            )
        } else {
            // Draw with hard edge (original behavior)
            drawWithHardEdge(
                context: context,
                center: center,
                radius: radius,
                dimOpacity: dimOpacity,
                shape: shape
            )
        }

        context.restoreGState()

        // Draw click indicators on top of spotlight
        drawClickIndicators(context: context)
    }

    private func drawClickIndicators(context: CGContext) {
        guard !clickIndicators.isEmpty else { return }

        #if DEBUG
        print("[MouseLight] drawClickIndicators called with \(clickIndicators.count) indicators, screenFrame: \(screenFrame)")
        #endif

        let now = CFAbsoluteTimeGetCurrent()

        for indicator in clickIndicators {
            let elapsed = now - indicator.startTime
            let progress = min(elapsed / indicator.duration, 1.0)

            // Skip if animation complete
            if progress >= 1.0 { continue }

            // Scale: 0.5 -> 1.0 with ease out
            let easedProgress = 1 - pow(1 - progress, 3)
            let scale = 0.5 + 0.5 * easedProgress

            // Opacity: 1.0 -> 0.0
            let opacity = CGFloat(1.0 - progress)

            // Convert screen position to view coordinates
            let viewX = indicator.screenPosition.x - screenFrame.origin.x
            let viewY = indicator.screenPosition.y - screenFrame.origin.y

            #if DEBUG
            print("[MouseLight] Drawing click at view coords: (\(viewX), \(viewY)), opacity: \(opacity)")
            #endif

            let scaledRadius = indicator.radius * CGFloat(scale)
            let rect = CGRect(
                x: viewX - scaledRadius,
                y: viewY - scaledRadius,
                width: scaledRadius * 2,
                height: scaledRadius * 2
            )

            // Fill
            context.setFillColor(indicator.color.withAlphaComponent(0.5 * opacity).cgColor)
            context.fillEllipse(in: rect)

            // Stroke
            context.setStrokeColor(indicator.color.withAlphaComponent(opacity).cgColor)
            context.setLineWidth(4)
            context.strokeEllipse(in: rect)
        }
    }

    private func drawWithHardEdge(context: CGContext, center: NSPoint, radius: CGFloat, dimOpacity: CGFloat, shape: SpotlightShape) {
        // Fill entire view with semi-transparent black
        context.setFillColor(NSColor.black.withAlphaComponent(dimOpacity).cgColor)

        // Create path with the spotlight hole using even-odd fill
        let path = CGMutablePath()
        path.addRect(bounds)
        addShapePath(to: path, center: center, radius: radius, shape: shape)

        context.addPath(path)
        context.fillPath(using: .evenOdd)

        // Add subtle glow
        let glowPath = createGlowPath(center: center, radius: radius + 2, shape: shape)
        NSColor.white.withAlphaComponent(0.1).setStroke()
        glowPath.lineWidth = 4
        glowPath.stroke()
    }

    private func addShapePath(to path: CGMutablePath, center: NSPoint, radius: CGFloat, shape: SpotlightShape) {
        switch shape {
        case .circle:
            let rect = NSRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
            path.addEllipse(in: rect)

        case .square:
            let rect = NSRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
            path.addRoundedRect(in: rect, cornerWidth: radius * 0.1, cornerHeight: radius * 0.1)

        case .triangle:
            let trianglePath = CGMutablePath()
            trianglePath.move(to: CGPoint(x: center.x, y: center.y + radius))
            trianglePath.addLine(to: CGPoint(x: center.x - radius * 0.866, y: center.y - radius * 0.5))
            trianglePath.addLine(to: CGPoint(x: center.x + radius * 0.866, y: center.y - radius * 0.5))
            trianglePath.closeSubpath()
            path.addPath(trianglePath)

        case .star:
            let starPath = createStarPath(center: center, outerRadius: radius, innerRadius: radius * 0.4, points: 5)
            path.addPath(starPath)

        case .trapezoid:
            let trapezoidPath = CGMutablePath()
            let topWidth = radius * 1.2
            let bottomWidth = radius * 1.8
            let height = radius * 1.4
            trapezoidPath.move(to: CGPoint(x: center.x - topWidth / 2, y: center.y + height / 2))
            trapezoidPath.addLine(to: CGPoint(x: center.x + topWidth / 2, y: center.y + height / 2))
            trapezoidPath.addLine(to: CGPoint(x: center.x + bottomWidth / 2, y: center.y - height / 2))
            trapezoidPath.addLine(to: CGPoint(x: center.x - bottomWidth / 2, y: center.y - height / 2))
            trapezoidPath.closeSubpath()
            path.addPath(trapezoidPath)

        case .cloud:
            // Cloud is wider than tall, so use radius for width and scale height proportionally
            let cloudWidth = radius * 2.2
            let cloudHeight = radius * 1.5
            let cloudRect = CGRect(
                x: center.x - cloudWidth / 2,
                y: center.y - cloudHeight / 2,
                width: cloudWidth,
                height: cloudHeight
            )
            let cloudShape = CloudShape()
            path.addPath(cloudShape.cgPath(in: cloudRect))
        }
    }

    private func createStarPath(center: NSPoint, outerRadius: CGFloat, innerRadius: CGFloat, points: Int) -> CGPath {
        let path = CGMutablePath()
        let angleIncrement = CGFloat.pi / CGFloat(points)

        for i in 0..<(points * 2) {
            let radius = i % 2 == 0 ? outerRadius : innerRadius
            let angle = CGFloat(i) * angleIncrement - CGFloat.pi / 2
            let point = CGPoint(
                x: center.x + radius * cos(angle),
                y: center.y + radius * sin(angle)
            )
            if i == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        path.closeSubpath()
        return path
    }

    private func createGlowPath(center: NSPoint, radius: CGFloat, shape: SpotlightShape) -> NSBezierPath {
        switch shape {
        case .circle:
            let rect = NSRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
            return NSBezierPath(ovalIn: rect)

        case .square:
            let rect = NSRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
            return NSBezierPath(roundedRect: rect, xRadius: radius * 0.1, yRadius: radius * 0.1)

        case .triangle:
            let path = NSBezierPath()
            path.move(to: NSPoint(x: center.x, y: center.y + radius))
            path.line(to: NSPoint(x: center.x - radius * 0.866, y: center.y - radius * 0.5))
            path.line(to: NSPoint(x: center.x + radius * 0.866, y: center.y - radius * 0.5))
            path.close()
            return path

        case .star:
            let path = NSBezierPath()
            let outerRadius = radius
            let innerRadius = radius * 0.4
            let points = 5
            let angleIncrement = CGFloat.pi / CGFloat(points)

            for i in 0..<(points * 2) {
                let r = i % 2 == 0 ? outerRadius : innerRadius
                let angle = CGFloat(i) * angleIncrement - CGFloat.pi / 2
                let point = NSPoint(x: center.x + r * cos(angle), y: center.y + r * sin(angle))
                if i == 0 {
                    path.move(to: point)
                } else {
                    path.line(to: point)
                }
            }
            path.close()
            return path

        case .trapezoid:
            let path = NSBezierPath()
            let topWidth = radius * 1.2
            let bottomWidth = radius * 1.8
            let height = radius * 1.4
            path.move(to: NSPoint(x: center.x - topWidth / 2, y: center.y + height / 2))
            path.line(to: NSPoint(x: center.x + topWidth / 2, y: center.y + height / 2))
            path.line(to: NSPoint(x: center.x + bottomWidth / 2, y: center.y - height / 2))
            path.line(to: NSPoint(x: center.x - bottomWidth / 2, y: center.y - height / 2))
            path.close()
            return path

        case .cloud:
            let cloudWidth = radius * 2.2
            let cloudHeight = radius * 1.5
            let cloudRect = CGRect(
                x: center.x - cloudWidth / 2,
                y: center.y - cloudHeight / 2,
                width: cloudWidth,
                height: cloudHeight
            )
            let cloudShape = CloudShape()
            return NSBezierPath.fromCGPath(cloudShape.cgPath(in: cloudRect))
        }
    }

    private func drawWithBlurredEdge(context: CGContext, center: NSPoint, innerRadius: CGFloat, outerRadius: CGFloat, dimOpacity: CGFloat, shape: SpotlightShape) {
        // Step 1: Fill background with dim color, but leave a hole at OUTER radius
        // This avoids using blend modes which don't work with screen sharing
        let backgroundPath = CGMutablePath()
        backgroundPath.addRect(bounds)
        addShapePath(to: backgroundPath, center: center, radius: outerRadius, shape: shape)

        context.setFillColor(NSColor.black.withAlphaComponent(dimOpacity).cgColor)
        context.addPath(backgroundPath)
        context.fillPath(using: .evenOdd)

        // Step 2: Draw the gradient/blur edge from inner to outer radius
        if shape == .circle {
            drawCircleBlurredEdge(context: context, center: center, innerRadius: innerRadius, outerRadius: outerRadius, dimOpacity: dimOpacity)
        } else {
            drawShapeBlurredEdge(context: context, center: center, innerRadius: innerRadius, outerRadius: outerRadius, dimOpacity: dimOpacity, shape: shape)
        }

        // Add subtle outer glow for visibility
        let glowPath = createGlowPath(center: center, radius: outerRadius + 2, shape: shape)
        NSColor.white.withAlphaComponent(0.08).setStroke()
        glowPath.lineWidth = 3
        glowPath.stroke()
    }

    private func drawCircleBlurredEdge(context: CGContext, center: NSPoint, innerRadius: CGFloat, outerRadius: CGFloat, dimOpacity: CGFloat) {
        // Draw a gradient ring from inner to outer radius
        // Background already has a hole at outer radius, so we just need to fill the ring area

        // Gradient from clear (at inner radius) to dim color (at outer radius)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let dimColor = NSColor.black.withAlphaComponent(dimOpacity).cgColor
        let clearColor = NSColor.clear.cgColor

        let colors: [CGColor] = [clearColor, dimColor]
        let locations: [CGFloat] = [0.0, 1.0]

        guard let gradient = CGGradient(colorsSpace: colorSpace, colors: colors as CFArray, locations: locations) else {
            return
        }

        // Draw radial gradient from inner to outer radius
        context.drawRadialGradient(
            gradient,
            startCenter: center,
            startRadius: innerRadius,
            endCenter: center,
            endRadius: outerRadius,
            options: []
        )
    }

    private func drawShapeBlurredEdge(context: CGContext, center: NSPoint, innerRadius: CGFloat, outerRadius: CGFloat, dimOpacity: CGFloat, shape: SpotlightShape) {
        // Draw layered rings from inner to outer radius with increasing opacity
        // Background already has a hole at outer radius, so we just fill the ring area

        let blurSteps = 12
        let radiusStep = (outerRadius - innerRadius) / CGFloat(blurSteps)

        // Draw from inner (transparent) to outer (dim)
        for i in 1...blurSteps {
            let currentRadius = innerRadius + radiusStep * CGFloat(i)
            let previousRadius = innerRadius + radiusStep * CGFloat(i - 1)

            // Alpha increases from 0 to dimOpacity as we go outward
            let alpha = dimOpacity * CGFloat(i) / CGFloat(blurSteps)

            // Create a ring by using even-odd fill with outer and inner shapes
            let ringPath = CGMutablePath()
            addShapePath(to: ringPath, center: center, radius: currentRadius, shape: shape)
            addShapePath(to: ringPath, center: center, radius: previousRadius, shape: shape)

            context.setFillColor(NSColor.black.withAlphaComponent(alpha).cgColor)
            context.addPath(ringPath)
            context.fillPath(using: .evenOdd)
        }
    }

    override var isFlipped: Bool {
        return false
    }
}

// MARK: - NSBezierPath Extension for CGPath Conversion (macOS 13 compatible)

extension NSBezierPath {
    static func fromCGPath(_ cgPath: CGPath) -> NSBezierPath {
        let path = NSBezierPath()
        cgPath.applyWithBlock { elementPointer in
            let element = elementPointer.pointee
            switch element.type {
            case .moveToPoint:
                path.move(to: element.points[0])
            case .addLineToPoint:
                path.line(to: element.points[0])
            case .addQuadCurveToPoint:
                let qp0 = path.currentPoint
                let qp1 = element.points[0]
                let qp2 = element.points[1]
                // Convert quadratic to cubic bezier
                let cp1 = NSPoint(x: qp0.x + (2.0/3.0) * (qp1.x - qp0.x),
                                  y: qp0.y + (2.0/3.0) * (qp1.y - qp0.y))
                let cp2 = NSPoint(x: qp2.x + (2.0/3.0) * (qp1.x - qp2.x),
                                  y: qp2.y + (2.0/3.0) * (qp1.y - qp2.y))
                path.curve(to: qp2, controlPoint1: cp1, controlPoint2: cp2)
            case .addCurveToPoint:
                path.curve(to: element.points[2], controlPoint1: element.points[0], controlPoint2: element.points[1])
            case .closeSubpath:
                path.close()
            @unknown default:
                break
            }
        }
        return path
    }
}

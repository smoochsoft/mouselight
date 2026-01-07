import Cocoa

class SpotlightView: NSView {
    /// Cursor position in screen coordinates (not view coordinates)
    var cursorPosition: NSPoint = .zero
    var zoomScale: CGFloat = 1.0 // For zoom animation

    /// The screen frame this view represents (for coordinate conversion)
    var screenFrame: NSRect = .zero

    private let settings = AppSettings.shared

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        self.wantsLayer = true
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        self.wantsLayer = true
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
                dimOpacity: dimOpacity
            )
        } else {
            // Draw with hard edge (original behavior)
            drawWithHardEdge(
                context: context,
                center: center,
                radius: radius,
                dimOpacity: dimOpacity
            )
        }

        context.restoreGState()
    }

    private func drawWithHardEdge(context: CGContext, center: NSPoint, radius: CGFloat, dimOpacity: CGFloat) {
        let spotlightRect = NSRect(
            x: center.x - radius,
            y: center.y - radius,
            width: radius * 2,
            height: radius * 2
        )

        // Fill entire view with semi-transparent black
        context.setFillColor(NSColor.black.withAlphaComponent(dimOpacity).cgColor)

        // Create path with the spotlight hole using even-odd fill
        let path = CGMutablePath()
        path.addRect(bounds)
        path.addEllipse(in: spotlightRect)

        context.addPath(path)
        context.fillPath(using: .evenOdd)

        // Add subtle glow
        let glowPath = NSBezierPath(ovalIn: spotlightRect.insetBy(dx: -2, dy: -2))
        NSColor.white.withAlphaComponent(0.1).setStroke()
        glowPath.lineWidth = 4
        glowPath.stroke()
    }

    private func drawWithBlurredEdge(context: CGContext, center: NSPoint, innerRadius: CGFloat, outerRadius: CGFloat, dimOpacity: CGFloat) {
        // First, fill the entire background with dim color
        context.setFillColor(NSColor.black.withAlphaComponent(dimOpacity).cgColor)
        context.fill(bounds)

        // Create radial gradient for the spotlight with soft edge
        let colorSpace = CGColorSpaceCreateDeviceRGB()

        // For destinationOut blend mode:
        // - Alpha=1.0 (opaque) REMOVES destination completely (creates clear hole)
        // - Alpha=0.0 (transparent) LEAVES destination as-is (keeps dim)
        // Gradient: fully opaque center -> fade to transparent at edge
        let colors: [CGColor] = [
            NSColor.black.cgColor,  // alpha=1.0 at center - cuts complete hole
            NSColor.black.cgColor,  // alpha=1.0 at inner radius - still clear
            NSColor.clear.cgColor,  // alpha=0.0 at outer edge - soft transition
            NSColor.clear.cgColor   // alpha=0.0 at very edge
        ]

        // innerRadius is where the clear area ends, outerRadius is where dim starts
        let innerStop = innerRadius / outerRadius
        let locations: [CGFloat] = [0.0, innerStop, 1.0, 1.0]

        guard let gradient = CGGradient(colorsSpace: colorSpace, colors: colors as CFArray, locations: locations) else { return }

        // Use destination-out blend mode to cut the spotlight hole
        context.setBlendMode(.destinationOut)
        context.drawRadialGradient(
            gradient,
            startCenter: center,
            startRadius: 0,
            endCenter: center,
            endRadius: outerRadius,
            options: []
        )

        // Reset blend mode
        context.setBlendMode(.normal)

        // Add subtle outer glow for visibility
        let glowRect = NSRect(
            x: center.x - outerRadius - 2,
            y: center.y - outerRadius - 2,
            width: (outerRadius + 2) * 2,
            height: (outerRadius + 2) * 2
        )
        let glowPath = NSBezierPath(ovalIn: glowRect)
        NSColor.white.withAlphaComponent(0.08).setStroke()
        glowPath.lineWidth = 3
        glowPath.stroke()
    }

    override var isFlipped: Bool {
        return false
    }
}

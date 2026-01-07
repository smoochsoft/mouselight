import Cocoa
import SwiftUI

class KeystrokeOverlayWindow: NSWindow {
    private var keystrokeView: NSHostingView<KeystrokeView>!
    private var viewModel = KeystrokeViewModel()
    private let settings = AppSettings.shared

    init() {
        let displayIndex = AppSettings.shared.keystrokeDisplayIndex
        let screens = NSScreen.screens
        let screen = (displayIndex >= 0 && displayIndex < screens.count) ? screens[displayIndex] : (NSScreen.main ?? screens.first!)

        let windowWidth: CGFloat = 800
        let windowHeight: CGFloat = 150
        let yPosition: CGFloat = 80

        let windowFrame = NSRect(
            x: screen.frame.origin.x + (screen.frame.width - windowWidth) / 2,
            y: screen.frame.origin.y + yPosition,
            width: windowWidth,
            height: windowHeight
        )

        super.init(
            contentRect: windowFrame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )

        self.level = .floating
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        self.ignoresMouseEvents = true
        self.backgroundColor = .clear
        self.isOpaque = false
        self.hasShadow = false

        keystrokeView = NSHostingView(rootView: KeystrokeView(viewModel: viewModel))
        keystrokeView.frame = NSRect(x: 0, y: 0, width: windowWidth, height: windowHeight)
        self.contentView = keystrokeView

        self.orderFrontRegardless()
    }

    private func getTargetScreen() -> NSScreen {
        let displayIndex = settings.keystrokeDisplayIndex
        let screens = NSScreen.screens

        // Return the selected screen if valid, otherwise primary
        if displayIndex >= 0 && displayIndex < screens.count {
            return screens[displayIndex]
        }
        return NSScreen.main ?? screens.first ?? NSScreen()
    }

    func updateDisplayPosition() {
        let screen = getTargetScreen()
        let windowWidth: CGFloat = 800
        let yPosition: CGFloat = 80

        let newOrigin = NSPoint(
            x: screen.frame.origin.x + (screen.frame.width - windowWidth) / 2,
            y: screen.frame.origin.y + yPosition
        )

        self.setFrameOrigin(newOrigin)
    }

    func showKeystroke(_ keystroke: String) {
        viewModel.showKeystroke(keystroke)
    }
}

class KeystrokeViewModel: ObservableObject {
    @Published var currentKeystroke: String = ""
    @Published var opacity: Double = 0

    private var hideTimer: Timer?
    private let settings = AppSettings.shared

    func showKeystroke(_ keystroke: String) {
        hideTimer?.invalidate()

        withAnimation(.easeOut(duration: 0.15)) {
            currentKeystroke = keystroke
            opacity = 1
        }

        hideTimer = Timer.scheduledTimer(withTimeInterval: settings.keystrokeDisplayDuration, repeats: false) { [weak self] _ in
            withAnimation(.easeOut(duration: 0.3)) {
                self?.opacity = 0
            }
        }
    }
}

struct KeystrokeView: View {
    @ObservedObject var viewModel: KeystrokeViewModel
    @ObservedObject private var settings = AppSettings.shared

    var body: some View {
        HStack {
            Spacer()

            if !viewModel.currentKeystroke.isEmpty {
                Text(viewModel.currentKeystroke)
                    .font(.system(size: CGFloat(settings.keystrokeFontSize), weight: .medium, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.black.opacity(0.75))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
            }

            Spacer()
        }
        .opacity(viewModel.opacity)
    }
}

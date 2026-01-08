import SwiftUI

struct AboutView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                HStack {
                    if let appIcon = NSImage(named: "AppIcon") {
                        Image(nsImage: appIcon)
                            .resizable()
                            .frame(width: 64, height: 64)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("MouseLight")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        Text("Version \(appVersion)")
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .padding(.bottom, 10)

                Divider()

                // Description
                Text("MouseLight is a presentation utility for macOS that helps highlight your cursor and clicks during screen recordings, demos, and presentations.")
                    .font(.body)

                Divider()

                // Features
                VStack(alignment: .leading, spacing: 16) {
                    FeatureSection(
                        icon: "light.max",
                        title: "Spotlight Effect",
                        description: "Dims the entire screen except for a customizable area around your cursor. Perfect for drawing attention to specific parts of the screen.",
                        details: [
                            "Toggle with customizable hotkey (default: Cmd+Shift+M)",
                            "Multiple shapes: Circle, Square, Triangle, Star, Trapezoid, Cloud",
                            "Adjustable size, blur, and dim opacity",
                            "Optional auto-deactivate timer",
                            "Press Escape to quickly deactivate"
                        ]
                    )

                    FeatureSection(
                        icon: "cursorarrow.click",
                        title: "Click Indicators",
                        description: "Shows animated visual feedback when you click the mouse. Helps viewers see exactly where you're clicking.",
                        details: [
                            "Can work standalone or only with spotlight",
                            "Supports left, right, and middle clicks",
                            "Customizable color, size, and animation duration",
                            "Expanding circle animation effect"
                        ]
                    )

                    FeatureSection(
                        icon: "gearshape",
                        title: "General",
                        description: "Additional settings for controlling the app.",
                        details: [
                            "Launch at login option",
                            "Menu bar icon for quick access",
                            "Requires Accessibility permission for global input monitoring"
                        ]
                    )
                }

                Divider()

                // Tips
                VStack(alignment: .leading, spacing: 8) {
                    Text("Tips")
                        .font(.headline)

                    BulletPoint("Use the menu bar icon to quickly toggle features on/off")
                    BulletPoint("Press your hotkey to activate spotlight, then Escape to deactivate")
                    BulletPoint("Click indicators can work standalone or only with spotlight active")
                }

                Spacer()
            }
            .padding(24)
        }
        .frame(width: 500, height: 550)
    }

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}

struct FeatureSection: View {
    let icon: String
    let title: String
    let description: String
    let details: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(.accentColor)
                    .frame(width: 24)
                Text(title)
                    .font(.headline)
            }

            Text(description)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .padding(.leading, 32)

            VStack(alignment: .leading, spacing: 4) {
                ForEach(details, id: \.self) { detail in
                    BulletPoint(detail)
                        .padding(.leading, 32)
                }
            }
        }
    }
}

struct BulletPoint: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•")
                .foregroundColor(.secondary)
            Text(text)
                .font(.subheadline)
                .foregroundColor(.primary)
        }
    }
}

#Preview {
    AboutView()
}

import SwiftUI

struct PermissionsWindowView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var hasAccessibility = PermissionsManager.shared.hasAccessibilityPermission
    @State private var timer: Timer?

    var onComplete: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 8) {
                Text("MouseLight Security & Privacy")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("Please grant MouseLight the following permissions:")
                    .font(.body)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 24)
            .padding(.bottom, 20)

            Divider()

            // Permissions List
            VStack(spacing: 16) {
                PermissionRow(
                    icon: "accessibility",
                    iconColor: .blue,
                    title: "Accessibility",
                    description: "Accessibility is used to gain access to certain system events which are needed for input",
                    isGranted: hasAccessibility,
                    isRequired: true,
                    onSettings: {
                        PermissionsManager.shared.openAccessibilityPreferences()
                    }
                )

                PermissionRow(
                    icon: "keyboard",
                    iconColor: .gray,
                    title: "Input Monitoring",
                    description: "Input Monitoring is used to monitor mouse events.",
                    isGranted: hasAccessibility, // Uses same permission
                    isRequired: false,
                    onSettings: {
                        PermissionsManager.shared.openAccessibilityPreferences()
                    }
                )
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 24)

            Spacer()

            // Footer
            VStack(spacing: 16) {
                Text("You can change these permissions anytime in the System Preferences. Missing permissions limit the functionality of MouseLight and might make it unusable.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                HStack {
                    Spacer()
                    Button("Quit") {
                        NSApplication.shared.terminate(nil)
                    }
                    .keyboardShortcut(.cancelAction)

                    if hasAccessibility {
                        Button("Continue") {
                            AppSettings.shared.hasCompletedOnboarding = true
                            onComplete()
                            dismiss()
                        }
                        .keyboardShortcut(.defaultAction)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 20)
            }
        }
        .frame(width: 500, height: 420)
        .onAppear {
            startPermissionCheck()
        }
        .onDisappear {
            timer?.invalidate()
        }
    }

    private func startPermissionCheck() {
        // Check permissions periodically
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            hasAccessibility = PermissionsManager.shared.hasAccessibilityPermission
        }
    }
}

struct PermissionRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let description: String
    let isGranted: Bool
    let isRequired: Bool
    let onSettings: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            // Icon
            Image(systemName: iconSystemName)
                .font(.system(size: 32))
                .foregroundColor(iconColor)
                .frame(width: 50, height: 50)
                .background(iconColor.opacity(0.15))
                .cornerRadius(10)

            // Text
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)

                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            // Status
            VStack(alignment: .trailing, spacing: 4) {
                Button("Settings...") {
                    onSettings()
                }

                if isGranted {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.title2)
                } else {
                    VStack(spacing: 2) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.red)
                            .font(.title2)
                        if isRequired {
                            Text("Required")
                                .font(.caption2)
                                .foregroundColor(.red)
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(Color.secondary.opacity(0.05))
        .cornerRadius(12)
    }

    private var iconSystemName: String {
        switch icon {
        case "accessibility":
            return "accessibility"
        case "keyboard":
            return "keyboard"
        default:
            return "gearshape"
        }
    }
}

#Preview {
    PermissionsWindowView(onComplete: {})
}

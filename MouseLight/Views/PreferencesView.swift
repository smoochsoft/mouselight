import SwiftUI
import ServiceManagement

enum PreferencesTab: String, CaseIterable {
    case spotlight = "Spotlight"
    case clicks = "Clicks"
    case keystrokes = "Keystrokes"
    case general = "General"

    var icon: String {
        switch self {
        case .spotlight: return "light.max"
        case .clicks: return "cursorarrow.click"
        case .keystrokes: return "keyboard"
        case .general: return "gearshape"
        }
    }
}

struct PreferencesView: View {
    @State private var selectedTab: PreferencesTab = .spotlight

    var body: some View {
        HStack(spacing: 0) {
            // Sidebar
            VStack(spacing: 4) {
                ForEach(PreferencesTab.allCases, id: \.self) { tab in
                    SidebarButton(
                        title: tab.rawValue,
                        icon: tab.icon,
                        isSelected: selectedTab == tab
                    ) {
                        selectedTab = tab
                    }
                }
                Spacer()
            }
            .padding(12)
            .frame(width: 160)
            .background(Color(NSColor.windowBackgroundColor).opacity(0.5))

            Divider()

            // Content
            Group {
                switch selectedTab {
                case .spotlight:
                    MouseLightTab()
                case .clicks:
                    MouseClicksTab()
                case .keystrokes:
                    KeystrokesTab()
                case .general:
                    MiscellaneousTab()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 600, height: 420)
    }
}

struct SidebarButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .frame(width: 20)
                Text(title)
                    .font(.system(size: 13))
                    .lineLimit(1)
                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
            )
            .foregroundColor(isSelected ? .accentColor : .primary)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - MouseLight (Spotlight) Tab

struct MouseLightTab: View {
    @ObservedObject private var settings = AppSettings.shared

    var body: some View {
        Form {
            Section {
                HotkeyRecorderView(
                    title: "Toggle Hotkey",
                    modifiers: $settings.spotlightHotkeyModifiers,
                    keyCode: $settings.spotlightHotkeyKeyCode
                )

                HStack {
                    Toggle("Deactivate after", isOn: $settings.autoDeactivate)
                    Spacer()
                    TextField("", value: $settings.autoDeactivateSeconds, formatter: NumberFormatter())
                        .frame(width: 50)
                        .disabled(!settings.autoDeactivate)
                    Text("seconds")
                        .foregroundColor(.secondary)
                }
            } header: {
                Text("Activation")
            }

            Section {
                HStack {
                    Text("Circle Radius")
                    Slider(value: $settings.spotlightRadius, in: 50...300, step: 10)
                    Text("\(Int(settings.spotlightRadius))")
                        .frame(width: 40)
                        .foregroundColor(.secondary)
                    Text("px")
                        .foregroundColor(.secondary)
                }

                HStack {
                    Text("Edge Blur")
                    Slider(value: $settings.spotlightBlur, in: 0...50, step: 5)
                    Text("\(Int(settings.spotlightBlur))")
                        .frame(width: 40)
                        .foregroundColor(.secondary)
                    Text("%")
                        .foregroundColor(.secondary)
                }

                HStack {
                    Text("Dim Opacity")
                    Slider(value: $settings.spotlightDimOpacity, in: 0.3...0.9, step: 0.05)
                    Text("\(Int(settings.spotlightDimOpacity * 100))%")
                        .frame(width: 50)
                        .foregroundColor(.secondary)
                }

                HStack {
                    Toggle("Animate Zoom", isOn: $settings.animateZoom)
                    Spacer()
                    TextField("", value: $settings.spotlightAnimationDuration, formatter: decimalFormatter)
                        .frame(width: 50)
                    Text("sec")
                        .foregroundColor(.secondary)
                }
            } header: {
                Text("Appearance")
            }
        }
        .formStyle(.grouped)
    }

    private var decimalFormatter: NumberFormatter {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.minimumFractionDigits = 1
        f.maximumFractionDigits = 1
        return f
    }
}

// MARK: - Mouse Clicks Tab

struct MouseClicksTab: View {
    @ObservedObject private var settings = AppSettings.shared

    var body: some View {
        Form {
            Section {
                Toggle("Show click indicators", isOn: $settings.clicksEnabled)

                Picker("Mode", selection: $settings.clicksStandalone) {
                    Text("With Spotlight").tag(false)
                    Text("Always On").tag(true)
                }
                .pickerStyle(.segmented)
            } header: {
                Text("Activation")
            }

            Section {
                HStack {
                    Text("Click Radius")
                    Slider(value: $settings.clickRadius, in: 15...60, step: 5)
                    Text("\(Int(settings.clickRadius))")
                        .frame(width: 40)
                        .foregroundColor(.secondary)
                    Text("px")
                        .foregroundColor(.secondary)
                }

                HStack {
                    Text("Colors")
                    Spacer()
                    HStack(spacing: 16) {
                        VStack(spacing: 2) {
                            ColorPicker("", selection: leftClickBinding)
                                .labelsHidden()
                            Text("Left").font(.caption2).foregroundColor(.secondary)
                        }
                        VStack(spacing: 2) {
                            ColorPicker("", selection: rightClickBinding)
                                .labelsHidden()
                            Text("Right").font(.caption2).foregroundColor(.secondary)
                        }
                        VStack(spacing: 2) {
                            ColorPicker("", selection: otherClickBinding)
                                .labelsHidden()
                            Text("Middle").font(.caption2).foregroundColor(.secondary)
                        }
                    }
                }

                HStack {
                    Text("Animation")
                    Spacer()
                    TextField("", value: $settings.clickAnimationDuration, formatter: decimalFormatter)
                        .frame(width: 50)
                    Text("sec")
                        .foregroundColor(.secondary)
                }

                HStack {
                    Toggle("Click Sound", isOn: $settings.clickSoundEnabled)
                    Spacer()
                    Slider(value: $settings.clickSoundVolume, in: 0...100, step: 10)
                        .frame(width: 80)
                        .disabled(!settings.clickSoundEnabled)
                    Text("\(Int(settings.clickSoundVolume))%")
                        .frame(width: 40)
                        .foregroundColor(.secondary)
                }
            } header: {
                Text("Appearance")
            }
        }
        .formStyle(.grouped)
    }

    private var leftClickBinding: Binding<Color> {
        Binding(
            get: { Color(settings.leftClickColor) },
            set: { settings.leftClickColorHex = NSColor($0).hexString }
        )
    }

    private var rightClickBinding: Binding<Color> {
        Binding(
            get: { Color(settings.rightClickColor) },
            set: { settings.rightClickColorHex = NSColor($0).hexString }
        )
    }

    private var otherClickBinding: Binding<Color> {
        Binding(
            get: { Color(settings.otherClickColor) },
            set: { settings.otherClickColorHex = NSColor($0).hexString }
        )
    }

    private var decimalFormatter: NumberFormatter {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.minimumFractionDigits = 1
        f.maximumFractionDigits = 1
        return f
    }
}

// MARK: - Keystrokes Tab

struct KeystrokesTab: View {
    @ObservedObject private var settings = AppSettings.shared

    var body: some View {
        Form {
            Section {
                Toggle("Show keystrokes", isOn: $settings.keystrokesEnabled)

                Picker("Mode", selection: $settings.keystrokesStandalone) {
                    Text("With Spotlight").tag(false)
                    Text("Always On").tag(true)
                }
                .pickerStyle(.segmented)
            } header: {
                Text("Activation")
            }

            Section {
                HStack {
                    Text("Display Duration")
                    Slider(value: $settings.keystrokeDisplayDuration, in: 0.5...5.0, step: 0.5)
                    Text("\(settings.keystrokeDisplayDuration, specifier: "%.1f")")
                        .frame(width: 35)
                        .foregroundColor(.secondary)
                    Text("sec")
                        .foregroundColor(.secondary)
                }

                HStack {
                    Text("Font Size")
                    Slider(value: $settings.keystrokeFontSize, in: 24...150, step: 6)
                    Text("\(Int(settings.keystrokeFontSize))")
                        .frame(width: 40)
                        .foregroundColor(.secondary)
                    Text("pt")
                        .foregroundColor(.secondary)
                }

                Picker("Filter", selection: $settings.keystrokeFilter) {
                    Text("All Keys").tag("all")
                    Text("Shortcuts Only").tag("modifiers_only")
                }
                .pickerStyle(.segmented)
            } header: {
                Text("Appearance")
            }

            Section {
                Picker("Display", selection: $settings.keystrokeDisplayIndex) {
                    ForEach(Array(NSScreen.screens.enumerated()), id: \.offset) { index, screen in
                        Text(screenName(for: screen, index: index)).tag(index)
                    }
                }
            } header: {
                Text("Position")
            }
        }
        .formStyle(.grouped)
    }

    private func screenName(for screen: NSScreen, index: Int) -> String {
        let size = "\(Int(screen.frame.width))×\(Int(screen.frame.height))"
        if screen == NSScreen.main {
            return "\(size) (Main)"
        }
        return size
    }
}

// MARK: - Miscellaneous Tab

struct MiscellaneousTab: View {
    @ObservedObject private var settings = AppSettings.shared
    @State private var hasAccessibility = PermissionsManager.shared.hasAccessibilityPermission
    @State private var permissionTimer: Timer?

    var body: some View {
        Form {
            Section {
                Toggle("Launch at Login", isOn: $settings.launchAtLogin)
                    .onChange(of: settings.launchAtLogin) { newValue in
                        updateLaunchAtLogin(newValue)
                    }
            } header: {
                Text("Startup")
            }

            Section {
                HStack {
                    Text("Accessibility")
                    Spacer()
                    if hasAccessibility {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Granted")
                                .foregroundColor(.secondary)
                        }
                    } else {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            Button("Grant Access") {
                                PermissionsManager.shared.openAccessibilityPreferences()
                            }
                        }
                    }
                }
            } header: {
                Text("Permissions")
            }

            Section {
                HStack {
                    Text("Version")
                    Spacer()
                    Text("1.0.0")
                        .foregroundColor(.secondary)
                }
            } header: {
                Text("About")
            }
        }
        .formStyle(.grouped)
        .onAppear {
            hasAccessibility = PermissionsManager.shared.hasAccessibilityPermission
            // Poll for permission changes
            permissionTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
                hasAccessibility = PermissionsManager.shared.hasAccessibilityPermission
            }
        }
        .onDisappear {
            permissionTimer?.invalidate()
            permissionTimer = nil
        }
    }

    private func updateLaunchAtLogin(_ enabled: Bool) {
        if #available(macOS 13.0, *) {
            do {
                if enabled {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                print("Failed to update launch at login: \(error)")
            }
        }
    }
}

#Preview {
    PreferencesView()
}

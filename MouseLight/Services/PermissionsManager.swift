import Cocoa
import ApplicationServices

class PermissionsManager {
    static let shared = PermissionsManager()

    private init() {}

    // MARK: - Accessibility Permission

    var hasAccessibilityPermission: Bool {
        AXIsProcessTrusted()
    }

    /// Request permission with system prompt (use only during onboarding)
    func requestAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }

    func openAccessibilityPreferences() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }

    // MARK: - Check All Permissions

    /// Check if we have permissions. Does NOT prompt - just returns status.
    func checkPermissions() -> Bool {
        return hasAccessibilityPermission
    }
}

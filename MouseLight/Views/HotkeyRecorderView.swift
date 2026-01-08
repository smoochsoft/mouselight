import SwiftUI
import Carbon

extension Notification.Name {
    static let hotkeyDidChange = Notification.Name("hotkeyDidChange")
    static let keystrokeDisplayDidChange = Notification.Name("keystrokeDisplayDidChange")
}

// Observable class to manage hotkey recording state
class HotkeyRecorder: ObservableObject {
    @Published var isRecording = false
    private var localMonitor: Any?

    var onHotkeyRecorded: ((Int, Int) -> Void)?

    func startRecording() {
        isRecording = true

        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return nil }

            // Capture the key combination - use proper modifier mask
            let relevantModifiers: NSEvent.ModifierFlags = [.command, .control, .option, .shift]
            let newModifiers = Int(event.modifierFlags.intersection(relevantModifiers).rawValue)
            let newKeyCode = Int(event.keyCode)

            // Require at least one modifier key
            let hasModifier = !event.modifierFlags.intersection(relevantModifiers).isEmpty

            if hasModifier {
                DispatchQueue.main.async {
                    self.onHotkeyRecorded?(newModifiers, newKeyCode)
                    self.stopRecording()
                }
            }

            return nil // Consume the event
        }
    }

    func stopRecording() {
        isRecording = false
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
            localMonitor = nil
        }
    }

    deinit {
        stopRecording()
    }
}

struct HotkeyRecorderView: View {
    let title: String
    @Binding var modifiers: Int
    @Binding var keyCode: Int

    @StateObject private var recorder = HotkeyRecorder()

    var body: some View {
        HStack {
            Text(title)

            Spacer()

            Button(action: {
                if recorder.isRecording {
                    recorder.stopRecording()
                } else {
                    recorder.onHotkeyRecorded = { [self] newModifiers, newKeyCode in
                        modifiers = newModifiers
                        keyCode = newKeyCode
                        // Notify that hotkey changed so Carbon registration can update
                        NotificationCenter.default.post(name: .hotkeyDidChange, object: nil)
                    }
                    recorder.startRecording()
                }
            }) {
                HStack {
                    if recorder.isRecording {
                        Text("Press keys...")
                            .foregroundColor(.secondary)
                    } else {
                        Text(hotkeyString)
                    }
                }
                .frame(minWidth: 120)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(recorder.isRecording ? Color.accentColor.opacity(0.2) : Color.secondary.opacity(0.1))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(recorder.isRecording ? Color.accentColor : Color.secondary.opacity(0.3), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)

            if keyCode != 0 {
                Button(action: clearHotkey) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .onDisappear {
            recorder.stopRecording()
        }
    }

    private var hotkeyString: String {
        if keyCode == 0 {
            return "Click to record"
        }
        return formatHotkey(modifiers: modifiers, keyCode: keyCode)
    }

    private func clearHotkey() {
        modifiers = 0
        keyCode = 0
    }

    private func formatHotkey(modifiers: Int, keyCode: Int) -> String {
        var parts: [String] = []
        let flags = NSEvent.ModifierFlags(rawValue: UInt(modifiers))

        if flags.contains(.control) { parts.append("\u{2303}") }
        if flags.contains(.option) { parts.append("\u{2325}") }
        if flags.contains(.shift) { parts.append("\u{21E7}") }
        if flags.contains(.command) { parts.append("\u{2318}") }

        if let keyName = keyCodeToString(keyCode) {
            parts.append(keyName)
        }

        return parts.isEmpty ? "Not Set" : parts.joined()
    }

    private func keyCodeToString(_ keyCode: Int) -> String? {
        let keyMap: [Int: String] = [
            0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X",
            8: "C", 9: "V", 11: "B", 12: "Q", 13: "W", 14: "E", 15: "R",
            16: "Y", 17: "T", 18: "1", 19: "2", 20: "3", 21: "4", 22: "6",
            23: "5", 24: "=", 25: "9", 26: "7", 27: "-", 28: "8", 29: "0",
            30: "]", 31: "O", 32: "U", 33: "[", 34: "I", 35: "P", 37: "L",
            38: "J", 39: "'", 40: "K", 41: ";", 42: "\\", 43: ",", 44: "/",
            45: "N", 46: "M", 47: ".", 50: "`",
            36: "\u{21A9}", 48: "\u{21E5}", 49: "Space", 51: "\u{232B}",
            53: "Esc", 123: "\u{2190}", 124: "\u{2192}", 125: "\u{2193}", 126: "\u{2191}"
        ]
        return keyMap[keyCode]
    }
}

#Preview {
    VStack {
        HotkeyRecorderView(
            title: "Toggle Spotlight",
            modifiers: .constant(0x120000),
            keyCode: .constant(46)
        )
    }
    .padding()
    .frame(width: 350)
}

import SwiftUI
import Carbon
import CoreSettings
import CoreUtils

struct HotkeyRecorder: View {
    @Binding var hotkey: HotkeyConfig
    @State private var isRecording = false
    @State private var recordedKeyCode: UInt32?
    @State private var recordedModifiers: UInt32?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Button(action: {
                    if isRecording {
                        stopRecording()
                    } else {
                        startRecording()
                    }
                }) {
                    HStack {
                        if isRecording {
                            Text(L("hotkey.press_keys"))
                                .foregroundColor(.primary)
                        } else {
                            Text(hotkeyDisplayString)
                                .foregroundColor(.primary)
                        }
                    }
                    .frame(minWidth: 150, minHeight: 30)
                    .background(isRecording ? Color.blue.opacity(0.2) : Color(NSColor.controlBackgroundColor))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(isRecording ? Color.blue : Color.gray.opacity(0.3), lineWidth: 2)
                    )
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .onKeyDown { event in
                    guard isRecording else { return false }
                    handleKeyEvent(event)
                    return true
                }

                if hotkey.keyCode != HotkeyConfig.default.keyCode || hotkey.modifiers != HotkeyConfig.default.modifiers {
                    Button(L("hotkey.reset_default")) {
                        hotkey = HotkeyConfig.default
                    }
                    .buttonStyle(.borderless)
                    .controlSize(.small)
                    .foregroundColor(.secondary)
                }
            }

            Text(L("hotkey.record_description"))
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .focusable()
    }

    private var hotkeyDisplayString: String {
        return hotkeyToString(keyCode: hotkey.keyCode, modifiers: hotkey.modifiers)
    }

    private func startRecording() {
        isRecording = true
        recordedKeyCode = nil
        recordedModifiers = nil
    }

    private func stopRecording() {
        if let keyCode = recordedKeyCode, let modifiers = recordedModifiers {
            hotkey = HotkeyConfig(keyCode: keyCode, modifiers: modifiers)
        }
        isRecording = false
        recordedKeyCode = nil
        recordedModifiers = nil
    }

    private func handleKeyEvent(_ event: NSEvent) {
        let keyCode = event.keyCode
        let modifierFlags = event.modifierFlags

        // Convert NSEvent modifier flags to Carbon modifier flags
        var carbonModifiers: UInt32 = 0

        if modifierFlags.contains(.command) {
            carbonModifiers |= UInt32(cmdKey)
        }
        if modifierFlags.contains(.shift) {
            carbonModifiers |= UInt32(shiftKey)
        }
        if modifierFlags.contains(.option) {
            carbonModifiers |= UInt32(optionKey)
        }
        if modifierFlags.contains(.control) {
            carbonModifiers |= UInt32(controlKey)
        }

        // Only accept combinations with at least one modifier
        guard carbonModifiers != 0 else { return }

        recordedKeyCode = UInt32(keyCode)
        recordedModifiers = carbonModifiers

        // Auto-stop recording after a brief delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            if isRecording {
                stopRecording()
            }
        }
    }
}

// MARK: - Helper Functions

private func hotkeyToString(keyCode: UInt32, modifiers: UInt32) -> String {
    var result = ""

    // Add modifier symbols
    if modifiers & UInt32(controlKey) != 0 {
        result += "⌃"
    }
    if modifiers & UInt32(optionKey) != 0 {
        result += "⌥"
    }
    if modifiers & UInt32(shiftKey) != 0 {
        result += "⇧"
    }
    if modifiers & UInt32(cmdKey) != 0 {
        result += "⌘"
    }

    // Add key name
    result += keyCodeToString(keyCode)

    return result
}

private func keyCodeToString(_ keyCode: UInt32) -> String {
    // Map common key codes to their string representations
    switch keyCode {
    case 0: return "A"
    case 1: return "S"
    case 2: return "D"
    case 3: return "F"
    case 4: return "H"
    case 5: return "G"
    case 6: return "Z"
    case 7: return "X"
    case 8: return "C"
    case 9: return "V"
    case 10: return "§"
    case 11: return "B"
    case 12: return "Q"
    case 13: return "W"
    case 14: return "E"
    case 15: return "R"
    case 16: return "Y"
    case 17: return "T"
    case 18: return "1"
    case 19: return "2"
    case 20: return "3"
    case 21: return "4"
    case 22: return "6"
    case 23: return "5"
    case 24: return "="
    case 25: return "9"
    case 26: return "7"
    case 27: return "-"
    case 28: return "8"
    case 29: return "0"
    case 30: return "]"
    case 31: return "O"
    case 32: return "U"
    case 33: return "["
    case 34: return "I"
    case 35: return "P"
    case 36: return "⏎"
    case 37: return "L"
    case 38: return "J"
    case 39: return "'"
    case 40: return "K"
    case 41: return ";"
    case 42: return "\\"
    case 43: return ","
    case 44: return "/"
    case 45: return "N"
    case 46: return "M"
    case 47: return "."
    case 48: return "⇥"
    case 49: return "Space"
    case 50: return "`"
    case 51: return "⌫"
    case 53: return "⎋"
    case 96: return "F5"
    case 97: return "F6"
    case 98: return "F7"
    case 99: return "F3"
    case 100: return "F8"
    case 101: return "F9"
    case 103: return "F11"
    case 105: return "F13"
    case 107: return "F14"
    case 109: return "F10"
    case 111: return "F12"
    case 113: return "F15"
    case 114: return "Help"
    case 115: return "Home"
    case 116: return "⇞"
    case 117: return "⌦"
    case 118: return "F4"
    case 119: return "End"
    case 120: return "F2"
    case 121: return "⇟"
    case 122: return "F1"
    case 123: return "←"
    case 124: return "→"
    case 125: return "↓"
    case 126: return "↑"
    default:
        return "Key \(keyCode)"
    }
}

// MARK: - Extensions

extension View {
    func onKeyDown(perform action: @escaping (NSEvent) -> Bool) -> some View {
        self.background(KeyEventHandlingView(onKeyDown: action))
    }
}

struct KeyEventHandlingView: NSViewRepresentable {
    let onKeyDown: (NSEvent) -> Bool

    func makeNSView(context: Context) -> NSView {
        let view = KeyHandlingNSView()
        view.onKeyDown = onKeyDown
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

class KeyHandlingNSView: NSView {
    var onKeyDown: ((NSEvent) -> Bool)?

    override var acceptsFirstResponder: Bool { true }

    override func keyDown(with event: NSEvent) {
        if let handler = onKeyDown, handler(event) {
            return
        }
        super.keyDown(with: event)
    }
}
import SwiftUI

@main
struct MenuWhisperApp: App {
    var body: some Scene {
        MenuBarExtra("Menu-Whisper", systemImage: "mic") {
            Text("Menu-Whisper")
            Text("Idle")
            Divider()
            Button("Preferences...") {
                // TODO: Open preferences
            }
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
        }
    }
}
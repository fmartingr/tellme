import SwiftUI
import CoreUtils

@main
struct MenuWhisperApp: App {
    @StateObject private var appController = AppController()

    var body: some Scene {
        MenuBarExtra("Menu-Whisper", systemImage: "mic") {
            MenuBarContentView()
                .environmentObject(appController)
                .onAppear {
                    appController.start()
                }
        }
    }
}

struct MenuBarContentView: View {
    @EnvironmentObject var appController: AppController

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Menu-Whisper")
                .font(.headline)

            Text(appController.currentState.displayName)
                .font(.subheadline)
                .foregroundColor(stateColor)

            if appController.currentState == .listening {
                Text("Press ⌘⇧V or Esc to stop")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Divider()

            Button("Preferences...") {
                // TODO: Open preferences window in Phase 4
            }

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
        }
        .padding(.horizontal, 4)
    }

    private var stateColor: Color {
        switch appController.currentState {
        case .idle:
            return .primary
        case .listening:
            return .blue
        case .processing:
            return .orange
        case .injecting:
            return .green
        case .error:
            return .red
        }
    }
}
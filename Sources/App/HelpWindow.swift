import SwiftUI

class HelpWindowController: NSWindowController {
    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 700, height: 600),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )

        super.init(window: window)

        window.title = "Tell me Help"
        window.center()

        let helpView = HelpView()
        window.contentView = NSHostingView(rootView: helpView)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

struct HelpView: View {
    @State private var selectedSection = 0

    var body: some View {
        HSplitView {
            // Sidebar
            VStack(alignment: .leading, spacing: 0) {
                Text("Help Topics")
                    .font(.headline)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)

                List(selection: $selectedSection) {
                    HelpSectionItem(title: "Getting Started", systemImage: "play.circle", tag: 0)
                    HelpSectionItem(title: "Permissions", systemImage: "lock.shield", tag: 1)
                    HelpSectionItem(title: "Speech Models", systemImage: "brain.head.profile", tag: 2)
                    HelpSectionItem(title: "Hotkeys & Usage", systemImage: "keyboard", tag: 3)
                    HelpSectionItem(title: "Troubleshooting", systemImage: "wrench.and.screwdriver", tag: 4)
                    HelpSectionItem(title: "Privacy & Security", systemImage: "shield.checkered", tag: 5)
                }
                .listStyle(.sidebar)
            }
            .frame(minWidth: 200, maxWidth: 300)

            // Content area
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    switch selectedSection {
                    case 0:
                        GettingStartedHelp()
                    case 1:
                        PermissionsHelp()
                    case 2:
                        ModelsHelp()
                    case 3:
                        HotkeysHelp()
                    case 4:
                        TroubleshootingHelp()
                    case 5:
                        PrivacyHelp()
                    default:
                        GettingStartedHelp()
                    }
                }
                .padding(24)
            }
        }
        .frame(width: 700, height: 600)
    }
}

struct HelpSectionItem: View {
    let title: String
    let systemImage: String
    let tag: Int

    var body: some View {
        Label(title, systemImage: systemImage)
            .tag(tag)
    }
}

// MARK: - Help Content Views

struct GettingStartedHelp: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Getting Started with Tell me")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("Tell me is a privacy-focused speech-to-text application that works completely offline on your Mac.")
                .font(.body)

            VStack(alignment: .leading, spacing: 12) {
                Text("Quick Setup")
                    .font(.headline)

                HelpStep(
                    number: 1,
                    title: "Grant Permissions",
                    description: "Allow Microphone, Accessibility, and Input Monitoring access when prompted."
                )

                HelpStep(
                    number: 2,
                    title: "Download a Model",
                    description: "Go to Preferences → Models and download a speech recognition model (recommended: whisper-small)."
                )

                HelpStep(
                    number: 3,
                    title: "Start Dictating",
                    description: "Press ⌘⇧V anywhere to start dictation. The HUD will appear to show status."
                )

                HelpStep(
                    number: 4,
                    title: "Stop and Insert",
                    description: "Release the hotkey (push-to-talk mode) or press it again (toggle mode) to transcribe and insert text."
                )
            }

            InfoBox(
                title: "First Time Setup",
                content: "If this is your first time, Tell me will guide you through the setup process automatically.",
                type: .info
            )
        }
    }
}

struct PermissionsHelp: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Permissions")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("Tell me requires specific system permissions to function properly.")
                .font(.body)

            VStack(alignment: .leading, spacing: 16) {
                PermissionHelpItem(
                    title: "Microphone",
                    description: "Required to capture your speech for transcription.",
                    required: true,
                    howToGrant: "Grant when prompted, or go to System Settings → Privacy & Security → Microphone."
                )

                PermissionHelpItem(
                    title: "Accessibility",
                    description: "Required to insert transcribed text into other applications.",
                    required: true,
                    howToGrant: "Go to System Settings → Privacy & Security → Accessibility and add Tell me."
                )

                PermissionHelpItem(
                    title: "Input Monitoring",
                    description: "Required to register global keyboard shortcuts and send text insertion events.",
                    required: true,
                    howToGrant: "Go to System Settings → Privacy & Security → Input Monitoring and add Tell me."
                )
            }

            InfoBox(
                title: "Permission Issues",
                content: "If permissions aren't working, try restarting Tell me after granting them. Some permissions may require logging out and back in.",
                type: .warning
            )
        }
    }
}

struct ModelsHelp: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Speech Recognition Models")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("Tell me uses OpenAI Whisper models for speech recognition. All models work entirely offline.")
                .font(.body)

            VStack(alignment: .leading, spacing: 12) {
                Text("Available Models")
                    .font(.headline)

                ModelHelpItem(
                    name: "whisper-tiny",
                    size: "39 MB",
                    ram: "~400 MB",
                    speed: "Very Fast",
                    accuracy: "Basic",
                    recommendation: "Good for testing or very low-end hardware"
                )

                ModelHelpItem(
                    name: "whisper-base",
                    size: "142 MB",
                    ram: "~500 MB",
                    speed: "Fast",
                    accuracy: "Good",
                    recommendation: "Recommended for most users"
                )

                ModelHelpItem(
                    name: "whisper-small",
                    size: "466 MB",
                    ram: "~1 GB",
                    speed: "Medium",
                    accuracy: "Very Good",
                    recommendation: "Best balance of speed and accuracy"
                )
            }

            InfoBox(
                title: "Model Storage",
                content: "Models are stored in ~/Library/Application Support/Tell me/Models and can be deleted from Preferences to free up space.",
                type: .info
            )

            InfoBox(
                title: "No Internet Required",
                content: "Once downloaded, models work completely offline. Your speech never leaves your device.",
                type: .success
            )
        }
    }
}

struct HotkeysHelp: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Hotkeys & Usage")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("Tell me supports global hotkeys to start dictation from anywhere on your system.")
                .font(.body)

            VStack(alignment: .leading, spacing: 12) {
                Text("Activation Modes")
                    .font(.headline)

                HelpModeItem(
                    title: "Push-to-Talk (Default)",
                    description: "Hold down the hotkey to dictate, release to stop and transcribe."
                )

                HelpModeItem(
                    title: "Toggle Mode",
                    description: "Press once to start dictation, press again to stop and transcribe."
                )
            }

            VStack(alignment: .leading, spacing: 12) {
                Text("Default Hotkey")
                    .font(.headline)

                HStack {
                    Text("⌘⇧V")
                        .font(.title2)
                        .fontWeight(.bold)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(8)

                    VStack(alignment: .leading) {
                        Text("Command + Shift + V")
                            .font(.body)
                            .fontWeight(.medium)
                        Text("Can be changed in Preferences → General")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Other Controls")
                    .font(.headline)

                HStack {
                    Text("⎋ Esc")
                        .font(.body)
                        .fontWeight(.bold)
                        .frame(width: 60, alignment: .leading)
                    Text("Cancel dictation at any time")
                }

                HStack {
                    Text("⌘↩ Cmd+Return")
                        .font(.body)
                        .fontWeight(.bold)
                        .frame(width: 120, alignment: .leading)
                    Text("Insert text (in preview mode)")
                }
            }

            InfoBox(
                title: "Hotkey Conflicts",
                content: "If your hotkey conflicts with another app, change it in Preferences → General → Hotkey Combination.",
                type: .warning
            )
        }
    }
}

struct TroubleshootingHelp: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Troubleshooting")
                .font(.largeTitle)
                .fontWeight(.bold)

            VStack(alignment: .leading, spacing: 16) {
                TroubleshootingItem(
                    issue: "Hotkey doesn't work",
                    solutions: [
                        "Check that Input Monitoring permission is granted",
                        "Try changing the hotkey in Preferences",
                        "Restart Tell me after granting permissions",
                        "Make sure no other app is using the same hotkey"
                    ]
                )

                TroubleshootingItem(
                    issue: "Text doesn't insert",
                    solutions: [
                        "Grant Accessibility permission in System Settings",
                        "Try switching insertion method in Preferences → Text Insertion",
                        "Check if you're in a secure input field (password, etc.)",
                        "Restart Tell me after granting permissions"
                    ]
                )

                TroubleshootingItem(
                    issue: "Poor transcription quality",
                    solutions: [
                        "Try a larger model (whisper-small or whisper-base)",
                        "Ensure you're in a quiet environment",
                        "Speak clearly and at normal pace",
                        "Check your microphone input level",
                        "Set the correct language in Preferences → Models"
                    ]
                )

                TroubleshootingItem(
                    issue: "App crashes or hangs",
                    solutions: [
                        "Check available RAM (models need 400MB-1GB+)",
                        "Try reducing processing threads in Preferences → Advanced",
                        "Restart Tell me",
                        "Try a smaller model if using whisper-medium or larger"
                    ]
                )

                TroubleshootingItem(
                    issue: "Microphone not working",
                    solutions: [
                        "Grant Microphone permission when prompted",
                        "Check System Settings → Privacy & Security → Microphone",
                        "Test microphone in other apps",
                        "Check input level in System Settings → Sound"
                    ]
                )
            }

            InfoBox(
                title: "Still Having Issues?",
                content: "Enable logging in Preferences → Advanced and check Console.app for Tell me logs, or try restarting your Mac if permission issues persist.",
                type: .info
            )
        }
    }
}

struct PrivacyHelp: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Privacy & Security")
                .font(.largeTitle)
                .fontWeight(.bold)

            VStack(alignment: .leading, spacing: 12) {
                Text("100% Offline Operation")
                    .font(.headline)

                Text("Tell me is designed with privacy as the top priority:")
                    .font(.body)

                VStack(alignment: .leading, spacing: 8) {
                    PrivacyPoint(
                        icon: "shield.checkered",
                        text: "Your audio never leaves your device"
                    )

                    PrivacyPoint(
                        icon: "wifi.slash",
                        text: "No internet connection required for transcription"
                    )

                    PrivacyPoint(
                        icon: "eye.slash",
                        text: "No telemetry or usage tracking"
                    )

                    PrivacyPoint(
                        icon: "lock.doc",
                        text: "Transcribed text is not stored or logged"
                    )
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                Text("Local Data Storage")
                    .font(.headline)

                Text("Tell me only stores:")
                    .font(.body)

                VStack(alignment: .leading, spacing: 6) {
                    Text("• Settings and preferences in UserDefaults")
                        .font(.body)
                    Text("• Downloaded models in ~/Library/Application Support/Tell me/")
                        .font(.body)
                    Text("• Optional local logs (if enabled, contains only timing and error data)")
                        .font(.body)
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                Text("Secure Input Detection")
                    .font(.headline)

                Text("Tell me automatically detects secure input contexts (like password fields) and disables text insertion to protect your security. In these cases, text is copied to clipboard instead.")
                    .font(.body)
            }

            InfoBox(
                title: "Open Source",
                content: "Tell me is open source software. You can review the code and build it yourself for complete transparency.",
                type: .success
            )
        }
    }
}

// MARK: - Helper Views

struct HelpStep: View {
    let number: Int
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(width: 32, height: 32)
                .background(Color.blue)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.body)
                    .fontWeight(.semibold)
                Text(description)
                    .font(.body)
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct PermissionHelpItem: View {
    let title: String
    let description: String
    let required: Bool
    let howToGrant: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.body)
                    .fontWeight(.semibold)

                if required {
                    Text("REQUIRED")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.red)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(4)
                }
            }

            Text(description)
                .font(.body)
                .foregroundColor(.secondary)

            Text("How to grant: \(howToGrant)")
                .font(.caption)
                .foregroundColor(.blue)
        }
        .padding(12)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }
}

struct ModelHelpItem: View {
    let name: String
    let size: String
    let ram: String
    let speed: String
    let accuracy: String
    let recommendation: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(name)
                    .font(.body)
                    .fontWeight(.semibold)

                Spacer()

                Text(size)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("RAM: \(ram)")
                        .font(.caption)
                    Text("Speed: \(speed)")
                        .font(.caption)
                    Text("Accuracy: \(accuracy)")
                        .font(.caption)
                }

                Spacer()
            }

            Text(recommendation)
                .font(.caption)
                .foregroundColor(.blue)
                .italic()
        }
        .padding(12)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }
}

struct HelpModeItem: View {
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(Color.blue)
                .frame(width: 8, height: 8)
                .padding(.top, 6)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body)
                    .fontWeight(.semibold)
                Text(description)
                    .font(.body)
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct TroubleshootingItem: View {
    let issue: String
    let solutions: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(issue)
                .font(.body)
                .fontWeight(.semibold)

            VStack(alignment: .leading, spacing: 4) {
                ForEach(solutions, id: \.self) { solution in
                    HStack(alignment: .top, spacing: 8) {
                        Text("•")
                            .foregroundColor(.blue)
                        Text(solution)
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding(12)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }
}

struct PrivacyPoint: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.green)
                .frame(width: 20)

            Text(text)
                .font(.body)
        }
    }
}

struct InfoBox: View {
    let title: String
    let content: String
    let type: InfoType

    enum InfoType {
        case info, warning, success, error

        var color: Color {
            switch self {
            case .info: return .blue
            case .warning: return .orange
            case .success: return .green
            case .error: return .red
            }
        }

        var icon: String {
            switch self {
            case .info: return "info.circle"
            case .warning: return "exclamationmark.triangle"
            case .success: return "checkmark.circle"
            case .error: return "xmark.circle"
            }
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: type.icon)
                .foregroundColor(type.color)
                .font(.title3)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.body)
                    .fontWeight(.semibold)
                Text(content)
                    .font(.body)
                    .foregroundColor(.secondary)
            }
        }
        .padding(16)
        .background(type.color.opacity(0.1))
        .cornerRadius(12)
    }
}
import SwiftUI
import CorePermissions
import CoreModels
import CoreSTT

class OnboardingWindowController: NSWindowController {
    private let permissionManager: PermissionManager
    private let modelManager: ModelManager
    private let whisperEngine: WhisperCPPEngine
    private var onboardingView: OnboardingView?

    init(permissionManager: PermissionManager, modelManager: ModelManager, whisperEngine: WhisperCPPEngine, onComplete: @escaping () -> Void) {
        self.permissionManager = permissionManager
        self.modelManager = modelManager
        self.whisperEngine = whisperEngine

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 650, height: 550),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )

        super.init(window: window)

        window.title = NSLocalizedString("onboarding.title", comment: "Welcome to Tell me")
        window.center()
        window.level = .floating

        onboardingView = OnboardingView(
            permissionManager: permissionManager,
            modelManager: modelManager,
            whisperEngine: whisperEngine,
            onComplete: { [weak self] in
                print("Onboarding complete, closing window...")
                onComplete()
                self?.close()
            }
        )

        window.contentView = NSHostingView(rootView: onboardingView!)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

struct OnboardingView: View {
    @ObservedObject var permissionManager: PermissionManager
    @ObservedObject var modelManager: ModelManager
    let whisperEngine: WhisperCPPEngine
    let onComplete: () -> Void

    @State private var currentStep = 0
    @State private var isDownloading = false
    @State private var downloadError: String?
    private let totalSteps = 4

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 12) {
                Image(systemName: "mic.circle.fill")
                    .foregroundColor(.blue)
                    .font(.system(size: 50))

                Text(NSLocalizedString("onboarding.title", comment: "Welcome to Tell me"))
                    .font(.title)
                    .fontWeight(.bold)

                Text(NSLocalizedString("onboarding.subtitle", comment: "Offline speech-to-text for macOS"))
                    .font(.title3)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 50)
            .padding(.bottom, 30)
            .padding(.horizontal, 50)

            // Progress indicator
            HStack(spacing: 8) {
                ForEach(0..<totalSteps, id: \.self) { step in
                    Circle()
                        .fill(step <= currentStep ? Color.blue : Color.gray.opacity(0.3))
                        .frame(width: 8, height: 8)
                }
            }
            .padding(.bottom, 24)

            // Content area
            ScrollView {
                VStack(spacing: 16) {
                    switch currentStep {
                    case 0:
                        WelcomeStep()
                    case 1:
                        PermissionsStep(permissionManager: permissionManager)
                    case 2:
                        ModelsStep(
                            modelManager: modelManager,
                            whisperEngine: whisperEngine,
                            isDownloading: $isDownloading,
                            downloadError: $downloadError
                        )
                    case 3:
                        CompletionStep(hasModel: modelManager.activeModel != nil)
                    default:
                        WelcomeStep()
                    }
                }
                .padding(.horizontal, 50)
            }
            .frame(height: 280)

            // Navigation buttons (fixed at bottom)
            HStack(spacing: 12) {
                Button(NSLocalizedString("onboarding.buttons.skip", comment: "Skip Setup")) {
                    onComplete()
                }
                .buttonStyle(.borderless)
                .controlSize(.regular)
                .foregroundColor(.secondary)

                if currentStep > 0 {
                    Button(NSLocalizedString("onboarding.buttons.back", comment: "Back")) {
                        currentStep = max(0, currentStep - 1)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.regular)
                }

                Spacer()

                if currentStep < totalSteps - 1 {
                    Button(NSLocalizedString("onboarding.buttons.next", comment: "Next")) {
                        currentStep = min(totalSteps - 1, currentStep + 1)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.regular)
                } else {
                    Button(NSLocalizedString("onboarding.buttons.get_started", comment: "Get Started")) {
                        onComplete()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.regular)
                }
            }
            .padding(.horizontal, 50)
            .padding(.top, 30)
            .padding(.bottom, 50)
            .background(Color(NSColor.windowBackgroundColor))
        }
        .frame(width: 650, height: 550)
    }
}

struct WelcomeStep: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(NSLocalizedString("onboarding.what_is", comment: "What is Tell me?"))
                .font(.title3)
                .fontWeight(.semibold)

            VStack(alignment: .leading, spacing: 16) {
                FeatureRow(
                    icon: "mic.fill",
                    title: NSLocalizedString("onboarding.feature.offline", comment: "Offline Speech Recognition"),
                    description: NSLocalizedString("onboarding.feature.offline_desc", comment: "Offline description")
                )

                FeatureRow(
                    icon: "keyboard",
                    title: NSLocalizedString("onboarding.feature.hotkey", comment: "Global Hotkey"),
                    description: NSLocalizedString("onboarding.feature.hotkey_desc", comment: "Hotkey description")
                )

                FeatureRow(
                    icon: "lock.shield",
                    title: NSLocalizedString("onboarding.feature.privacy", comment: "Privacy First"),
                    description: NSLocalizedString("onboarding.feature.privacy_desc", comment: "Privacy description")
                )
            }
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 20)
                .font(.title3)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body)
                    .fontWeight(.medium)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct PermissionsStep: View {
    @ObservedObject var permissionManager: PermissionManager

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(NSLocalizedString("onboarding.permissions.title", comment: "Permissions Required"))
                .font(.headline)

            Text(NSLocalizedString("onboarding.permissions.description", comment: "Permissions description"))
                .font(.body)
                .foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: 12) {
                PermissionStepRow(
                    title: "Microphone",
                    description: "To capture your speech for transcription",
                    status: permissionManager.microphoneStatus,
                    onGrant: {
                        permissionManager.requestMicrophonePermission { _ in }
                    }
                )

                PermissionStepRow(
                    title: "Accessibility",
                    description: "To insert transcribed text into applications",
                    status: permissionManager.accessibilityStatus,
                    onGrant: {
                        permissionManager.openSystemSettings(for: .accessibility)
                    }
                )

                PermissionStepRow(
                    title: "Input Monitoring",
                    description: "To register global keyboard shortcuts",
                    status: permissionManager.inputMonitoringStatus,
                    onGrant: {
                        permissionManager.openSystemSettings(for: .inputMonitoring)
                    }
                )
            }

            Button("Refresh Permission Status") {
                permissionManager.checkAllPermissions()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
    }
}

struct PermissionStepRow: View {
    let title: String
    let description: String
    let status: PermissionStatus
    let onGrant: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.body)
                    .fontWeight(.medium)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            HStack(spacing: 8) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)

                Text(statusText)
                    .font(.caption)
                    .foregroundColor(statusColor)

                if status != .granted {
                    Button("Grant") {
                        onGrant()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
        }
        .padding(12)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }

    private var statusColor: Color {
        switch status {
        case .granted: return .green
        case .denied: return .red
        case .notDetermined, .restricted: return .orange
        }
    }

    private var statusText: String {
        switch status {
        case .granted: return "Granted"
        case .denied: return "Denied"
        case .notDetermined: return "Not Set"
        case .restricted: return "Restricted"
        }
    }
}

struct ModelsStep: View {
    @ObservedObject var modelManager: ModelManager
    let whisperEngine: WhisperCPPEngine
    @Binding var isDownloading: Bool
    @Binding var downloadError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(NSLocalizedString("onboarding.models.title", comment: "Download a Speech Model"))
                .font(.headline)

            Text(NSLocalizedString("onboarding.models.description", comment: "Models description"))
                .font(.body)
                .foregroundColor(.secondary)

            // Model recommendation
            VStack(alignment: .leading, spacing: 12) {
                Text(NSLocalizedString("onboarding.models.recommended", comment: "Recommended: Whisper Tiny"))
                    .font(.body)
                    .fontWeight(.semibold)

                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("whisper-tiny")
                            .font(.body)
                            .fontWeight(.medium)
                        Text(NSLocalizedString("onboarding.models.tiny_description", comment: "Tiny model description"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    if let tinyModel = getTinyModel() {
                        if tinyModel.isDownloaded {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text(NSLocalizedString("onboarding.models.downloaded", comment: "Downloaded"))
                                    .font(.caption)
                                    .foregroundColor(.green)
                            }
                        } else if isDownloading {
                            HStack {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text(NSLocalizedString("onboarding.models.downloading", comment: "Downloading..."))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        } else {
                            Button("Download") {
                                downloadTinyModel()
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                        }
                    }
                }
            }
            .padding(16)
            .background(Color.blue.opacity(0.1))
            .cornerRadius(12)

            // Error display
            if let error = downloadError {
                HStack {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundColor(.red)
                    Text(String(format: NSLocalizedString("onboarding.models.download_failed", comment: "Download failed"), error))
                        .font(.caption)
                        .foregroundColor(.red)
                }
                .padding(12)
                .background(Color.red.opacity(0.1))
                .cornerRadius(8)
            }

            // Additional info
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "info.circle")
                        .foregroundColor(.blue)
                    Text(NSLocalizedString("onboarding.models.info1", comment: "Models info 1"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                HStack {
                    Image(systemName: "wifi.slash")
                        .foregroundColor(.green)
                    Text(NSLocalizedString("onboarding.models.info2", comment: "Models info 2"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    private func getTinyModel() -> ModelInfo? {
        return modelManager.availableModels.first { $0.name == "whisper-tiny" }
    }

    private func downloadTinyModel() {
        guard let tinyModel = getTinyModel() else { return }

        isDownloading = true
        downloadError = nil

        Task {
            do {
                try await modelManager.downloadModel(tinyModel) { progress in
                    // We don't need to track progress value for spinner
                    print("Download progress: \(progress.progress * 100)%")
                }

                DispatchQueue.main.async {
                    isDownloading = false

                    // Set as active model
                    modelManager.setActiveModel(tinyModel)

                    // Load the model
                    Task {
                        do {
                            if let modelPath = modelManager.getModelPath(for: tinyModel) {
                                try await whisperEngine.loadModel(at: modelPath)
                            }
                        } catch {
                            print("Failed to load model: \(error)")
                        }
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    isDownloading = false
                    downloadError = error.localizedDescription
                }
            }
        }
    }
}

struct CompletionStep: View {
    let hasModel: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if hasModel {
                Text(NSLocalizedString("onboarding.completion.ready_title", comment: "You're All Set!"))
                    .font(.headline)
                    .foregroundColor(.green)

                Text(NSLocalizedString("onboarding.completion.ready_desc", comment: "Ready description"))
                    .font(.body)
                    .foregroundColor(.secondary)

                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .top) {
                        Image(systemName: "1.circle.fill")
                            .foregroundColor(.blue)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(NSLocalizedString("onboarding.completion.step1", comment: "Step 1"))
                                .fontWeight(.medium)
                            Text(NSLocalizedString("onboarding.completion.step1_desc", comment: "Step 1 description"))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    HStack(alignment: .top) {
                        Image(systemName: "2.circle.fill")
                            .foregroundColor(.blue)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(NSLocalizedString("onboarding.completion.step2", comment: "Step 2"))
                                .fontWeight(.medium)
                            Text(NSLocalizedString("onboarding.completion.step2_desc", comment: "Step 2 description"))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    HStack(alignment: .top) {
                        Image(systemName: "3.circle.fill")
                            .foregroundColor(.blue)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(NSLocalizedString("onboarding.completion.step3", comment: "Step 3"))
                                .fontWeight(.medium)
                            Text(NSLocalizedString("onboarding.completion.step3_desc", comment: "Step 3 description"))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            } else {
                Text(NSLocalizedString("onboarding.completion.incomplete_title", comment: "Setup Not Complete"))
                    .font(.headline)
                    .foregroundColor(.orange)

                Text(NSLocalizedString("onboarding.completion.incomplete_desc", comment: "Incomplete description"))
                    .font(.body)
                    .foregroundColor(.secondary)

                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text(NSLocalizedString("onboarding.completion.no_model_warning", comment: "No model warning"))
                            .font(.body)
                            .fontWeight(.medium)
                    }
                    .padding(12)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(8)

                    Text(NSLocalizedString("onboarding.completion.what_next", comment: "What to do next:"))
                        .font(.body)
                        .fontWeight(.semibold)

                    VStack(alignment: .leading, spacing: 6) {
                        Text(NSLocalizedString("onboarding.completion.next_step1", comment: "Next step 1"))
                        Text(NSLocalizedString("onboarding.completion.next_step2", comment: "Next step 2"))
                        Text(NSLocalizedString("onboarding.completion.next_step3", comment: "Next step 3"))
                    }
                    .font(.body)
                    .foregroundColor(.secondary)
                }
            }

            Text(NSLocalizedString("onboarding.completion.footer", comment: "Footer text"))
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.top, 8)
        }
    }
}
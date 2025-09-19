import SwiftUI
import CoreModels
import CoreSTT
import CoreUtils
import CorePermissions
import CoreSettings

class PreferencesWindowController: NSWindowController {
    private let modelManager: ModelManager
    private let whisperEngine: WhisperCPPEngine
    private let permissionManager: PermissionManager
    private let settings: CoreSettings.Settings
    private var preferencesView: PreferencesView?

    init(modelManager: ModelManager, whisperEngine: WhisperCPPEngine, permissionManager: PermissionManager, settings: CoreSettings.Settings, initialTab: Int = 0) {
        self.modelManager = modelManager
        self.whisperEngine = whisperEngine
        self.permissionManager = permissionManager
        self.settings = settings

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )

        super.init(window: window)

        window.title = NSLocalizedString("preferences.title", comment: "Tell me Preferences")
        window.center()
        window.minSize = NSSize(width: 750, height: 600)
        window.maxSize = NSSize(width: 1200, height: 800)

        preferencesView = PreferencesView(
            modelManager: modelManager,
            whisperEngine: whisperEngine,
            permissionManager: permissionManager,
            settings: settings,
            initialTab: initialTab,
            onClose: { [weak self] in
                self?.close()
            }
        )

        window.contentView = NSHostingView(rootView: preferencesView!)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setSelectedTab(_ tabIndex: Int) {
        preferencesView?.setSelectedTab(tabIndex)
    }
}

struct PreferencesView: View {
    @ObservedObject var modelManager: ModelManager
    let whisperEngine: WhisperCPPEngine
    @ObservedObject var permissionManager: PermissionManager
    @ObservedObject var settings: CoreSettings.Settings
    let onClose: () -> Void

    @State private var selectedTab: Int
    @State private var isDownloading: [String: Bool] = [:]
    @State private var downloadProgress: [String: Double] = [:]
    @State private var showingDeleteAlert = false
    @State private var modelToDelete: ModelInfo?

    init(modelManager: ModelManager, whisperEngine: WhisperCPPEngine, permissionManager: PermissionManager, settings: CoreSettings.Settings, initialTab: Int = 0, onClose: @escaping () -> Void) {
        self.modelManager = modelManager
        self.whisperEngine = whisperEngine
        self.permissionManager = permissionManager
        self.settings = settings
        self.onClose = onClose
        self._selectedTab = State(initialValue: initialTab)
    }

    func setSelectedTab(_ tabIndex: Int) {
        selectedTab = tabIndex
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            GeneralTab(settings: settings)
                .tabItem {
                    Label(NSLocalizedString("preferences.general", comment: "General"), systemImage: "gearshape")
                }
                .tag(0)

            ModelsTab(
                modelManager: modelManager,
                whisperEngine: whisperEngine,
                settings: settings,
                isDownloading: $isDownloading,
                downloadProgress: $downloadProgress,
                showingDeleteAlert: $showingDeleteAlert,
                modelToDelete: $modelToDelete
            )
            .tabItem {
                Label(NSLocalizedString("preferences.models", comment: "Models"), systemImage: "brain.head.profile")
            }
            .tag(1)

            InsertionTab(settings: settings)
                .tabItem {
                    Label(NSLocalizedString("preferences.insertion", comment: "Text Insertion"), systemImage: "text.cursor")
                }
                .tag(2)

            HUDTab(settings: settings)
                .tabItem {
                    Label(NSLocalizedString("preferences.interface", comment: "Interface"), systemImage: "rectangle.on.rectangle")
                }
                .tag(3)

            AdvancedTab(settings: settings)
                .tabItem {
                    Label(NSLocalizedString("preferences.advanced", comment: "Advanced"), systemImage: "slider.horizontal.3")
                }
                .tag(4)

            PermissionsTab(permissionManager: permissionManager)
                .tabItem {
                    Label(NSLocalizedString("preferences.permissions", comment: "Permissions"), systemImage: "lock.shield")
                }
                .tag(5)
        }
        .frame(minWidth: 750, idealWidth: 800, maxWidth: 1200, minHeight: 600, idealHeight: 600, maxHeight: 800)
        .alert(NSLocalizedString("alert.delete_model", comment: "Delete Model"), isPresented: $showingDeleteAlert) {
            Button(NSLocalizedString("general.cancel", comment: "Cancel"), role: .cancel) {
                modelToDelete = nil
            }
            Button(NSLocalizedString("preferences.models.delete", comment: "Delete"), role: .destructive) {
                if let model = modelToDelete {
                    deleteModel(model)
                }
                modelToDelete = nil
            }
        } message: {
            if let model = modelToDelete {
                Text(String(format: NSLocalizedString("preferences.models.delete_confirm", comment: "Delete confirmation"), model.name))
            }
        }
    }

    private func deleteModel(_ model: ModelInfo) {
        do {
            try modelManager.deleteModel(model)
        } catch {
            print("Failed to delete model: \(error)")
        }
    }
}

struct ModelsTab: View {
    @ObservedObject var modelManager: ModelManager
    let whisperEngine: WhisperCPPEngine
    @ObservedObject var settings: CoreSettings.Settings

    @Binding var isDownloading: [String: Bool]
    @Binding var downloadProgress: [String: Double]
    @Binding var showingDeleteAlert: Bool
    @Binding var modelToDelete: ModelInfo?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(NSLocalizedString("preferences.models.title", comment: "Speech Recognition Models"))
                .font(.title2)
                .fontWeight(.semibold)

            Text(NSLocalizedString("preferences.models.description", comment: "Model description"))
                .font(.caption)
                .foregroundColor(.secondary)

            // Current Model Status
            VStack(alignment: .leading, spacing: 8) {
                Text(NSLocalizedString("preferences.models.current_model", comment: "Current Model"))
                    .font(.headline)

                if let activeModel = modelManager.activeModel {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(activeModel.name)
                                .font(.body)
                                .fontWeight(.medium)
                            Text("\(activeModel.sizeMB) MB • \(activeModel.qualityTier) quality • \(activeModel.estimatedRAM)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Circle()
                            .fill(whisperEngine.isModelLoaded() ? Color.green : Color.orange)
                            .frame(width: 8, height: 8)

                        Text(whisperEngine.isModelLoaded() ? NSLocalizedString("status.loaded", comment: "Loaded") : NSLocalizedString("status.loading", comment: "Loading..."))
                            .font(.caption)
                            .foregroundColor(whisperEngine.isModelLoaded() ? .green : .orange)
                    }
                    .padding(12)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(8)
                } else {
                    Text(NSLocalizedString("preferences.models.no_model", comment: "No model selected"))
                        .foregroundColor(.secondary)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(8)
                }
            }

            // Language Settings
            VStack(alignment: .leading, spacing: 8) {
                Text(NSLocalizedString("preferences.models.language", comment: "Language"))
                    .font(.headline)

                HStack {
                    Text(NSLocalizedString("preferences.models.recognition_language", comment: "Recognition Language:"))
                        .font(.body)

                    Picker(NSLocalizedString("general.language", comment: "Language"), selection: Binding(
                        get: { settings.forcedLanguage ?? "auto" },
                        set: { newValue in
                            settings.forcedLanguage = newValue == "auto" ? nil : newValue
                        }
                    )) {
                        Text(NSLocalizedString("language.auto_detect", comment: "Auto-detect")).tag("auto")
                        Divider()
                        Text(NSLocalizedString("language.english", comment: "English")).tag("en")
                        Text(NSLocalizedString("language.spanish", comment: "Spanish")).tag("es")
                        Text(NSLocalizedString("language.french", comment: "French")).tag("fr")
                        Text(NSLocalizedString("language.german", comment: "German")).tag("de")
                        Text(NSLocalizedString("language.italian", comment: "Italian")).tag("it")
                        Text(NSLocalizedString("language.portuguese", comment: "Portuguese")).tag("pt")
                        Text(NSLocalizedString("language.russian", comment: "Russian")).tag("ru")
                        Text(NSLocalizedString("language.chinese", comment: "Chinese")).tag("zh")
                        Text(NSLocalizedString("language.japanese", comment: "Japanese")).tag("ja")
                        Text(NSLocalizedString("language.korean", comment: "Korean")).tag("ko")
                    }
                    .pickerStyle(.menu)
                    .frame(width: 150)

                    Spacer()
                }
                .padding(12)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(8)
            }

            // Available Models
            VStack(alignment: .leading, spacing: 8) {
                Text(NSLocalizedString("preferences.models.available_models", comment: "Available Models"))
                    .font(.headline)

                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(modelManager.availableModels) { model in
                            ModelRow(
                                model: model,
                                modelManager: modelManager,
                                whisperEngine: whisperEngine,
                                isDownloading: isDownloading[model.name] ?? false,
                                downloadProgress: downloadProgress[model.name] ?? 0.0,
                                onDownload: {
                                    downloadModel(model)
                                },
                                onSelect: {
                                    selectModel(model)
                                },
                                onDelete: {
                                    modelToDelete = model
                                    showingDeleteAlert = true
                                }
                            )
                        }
                    }
                }
                .frame(maxHeight: 200)
            }

            Spacer()
        }
        .padding(20)
    }

    private func downloadModel(_ model: ModelInfo) {
        isDownloading[model.name] = true
        downloadProgress[model.name] = 0.0

        Task {
            do {
                try await modelManager.downloadModel(model) { progress in
                    DispatchQueue.main.async {
                        downloadProgress[model.name] = progress.progress
                    }
                }

                DispatchQueue.main.async {
                    isDownloading[model.name] = false
                    downloadProgress[model.name] = 1.0
                }
            } catch {
                DispatchQueue.main.async {
                    isDownloading[model.name] = false
                    downloadProgress[model.name] = 0.0
                }
                print("Download failed: \(error)")
            }
        }
    }

    private func selectModel(_ model: ModelInfo) {
        modelManager.setActiveModel(model)

        Task {
            do {
                if let modelPath = modelManager.getModelPath(for: model) {
                    try await whisperEngine.loadModel(at: modelPath)
                }
            } catch {
                print("Failed to load model: \(error)")
            }
        }
    }
}

struct ModelRow: View {
    let model: ModelInfo
    @ObservedObject var modelManager: ModelManager
    let whisperEngine: WhisperCPPEngine

    let isDownloading: Bool
    let downloadProgress: Double
    let onDownload: () -> Void
    let onSelect: () -> Void
    let onDelete: () -> Void

    private var isActive: Bool {
        modelManager.activeModel?.name == model.name
    }

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(model.name)
                        .font(.body)
                        .fontWeight(.medium)

                    if isActive {
                        Text(NSLocalizedString("preferences.models.active_badge", comment: "ACTIVE"))
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue)
                            .cornerRadius(4)
                    }
                }

                Text("\(model.sizeMB) MB • \(model.qualityTier) quality • \(model.estimatedRAM)")
                    .font(.caption)
                    .foregroundColor(.secondary)

                if !model.notes.isEmpty {
                    Text(model.notes)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer()

            VStack(spacing: 8) {
                if model.isDownloaded {
                    HStack(spacing: 8) {
                        if !isActive {
                            Button(NSLocalizedString("general.select", comment: "Select")) {
                                onSelect()
                            }
                            .buttonStyle(.bordered)
                        }

                        Button(NSLocalizedString("preferences.models.delete", comment: "Delete")) {
                            onDelete()
                        }
                        .buttonStyle(.bordered)
                        .foregroundColor(.red)
                    }
                } else {
                    if isDownloading {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text(NSLocalizedString("preferences.models.downloading", comment: "Downloading..."))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    } else {
                        Button(NSLocalizedString("preferences.models.download", comment: "Download")) {
                            onDownload()
                        }
                        .buttonStyle(.bordered)
                        .accessibilityLabel("Download \(model.name) model")
                        .accessibilityHint("Downloads the speech recognition model for offline use")
                    }
                }
            }
        }
        .padding(12)
        .background(isActive ? Color.blue.opacity(0.1) : Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isActive ? Color.blue : Color.clear, lineWidth: 2)
        )
    }
}

struct PermissionsTab: View {
    @ObservedObject var permissionManager: PermissionManager

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(NSLocalizedString("preferences.permissions", comment: "Permissions"))
                .font(.title2)
                .fontWeight(.semibold)

            Text(NSLocalizedString("preferences.permissions.description", comment: "Permissions description"))
                .font(.caption)
                .foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: 12) {
                // Microphone Permission
                PermissionRow(
                    title: NSLocalizedString("permissions.microphone.title_short", comment: "Microphone"),
                    description: NSLocalizedString("permissions.microphone.description_short", comment: "Microphone description"),
                    status: permissionManager.microphoneStatus,
                    onOpenSettings: {
                        permissionManager.openSystemSettings(for: .microphone)
                    },
                    onRefresh: {
                        permissionManager.checkAllPermissions()
                    }
                )

                Divider()

                // Accessibility Permission
                PermissionRow(
                    title: NSLocalizedString("permissions.accessibility.title_short", comment: "Accessibility"),
                    description: NSLocalizedString("permissions.accessibility.description_short", comment: "Accessibility description"),
                    status: permissionManager.accessibilityStatus,
                    onOpenSettings: {
                        permissionManager.openSystemSettings(for: .accessibility)
                    },
                    onRefresh: {
                        permissionManager.checkAllPermissions()
                    }
                )

                Divider()

                // Input Monitoring Permission
                PermissionRow(
                    title: NSLocalizedString("permissions.input_monitoring.title_short", comment: "Input Monitoring"),
                    description: NSLocalizedString("permissions.input_monitoring.description_short", comment: "Input Monitoring description"),
                    status: permissionManager.inputMonitoringStatus,
                    onOpenSettings: {
                        permissionManager.openSystemSettings(for: .inputMonitoring)
                    },
                    onRefresh: {
                        permissionManager.checkAllPermissions()
                    }
                )
            }
            .padding(16)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(12)

            // Help text
            VStack(alignment: .leading, spacing: 8) {
                Text(NSLocalizedString("preferences.permissions.need_help", comment: "Need Help?"))
                    .font(.headline)

                Text(NSLocalizedString("preferences.permissions.after_granting", comment: "After granting permissions"))
                    .font(.body)
                    .foregroundColor(.secondary)

                VStack(alignment: .leading, spacing: 4) {
                    Text(NSLocalizedString("preferences.permissions.step1", comment: "Step 1"))
                    Text(NSLocalizedString("preferences.permissions.step2", comment: "Step 2"))
                    Text(NSLocalizedString("preferences.permissions.step3", comment: "Step 3"))
                }
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.leading, 8)
            }

            Spacer()
        }
        .padding(20)
    }
}

struct PermissionRow: View {
    let title: String
    let description: String
    let status: PermissionStatus
    let onOpenSettings: () -> Void
    let onRefresh: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(title)
                        .font(.body)
                        .fontWeight(.medium)

                    Spacer()

                    // Status indicator
                    HStack(spacing: 4) {
                        Circle()
                            .fill(statusColor)
                            .frame(width: 8, height: 8)

                        Text(statusText)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(statusColor)
                    }
                }

                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            VStack(spacing: 6) {
                if status != .granted {
                    Button(NSLocalizedString("permissions.open_settings", comment: "Open System Settings")) {
                        onOpenSettings()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }

                Button(NSLocalizedString("permissions.refresh_status", comment: "Refresh Status")) {
                    onRefresh()
                }
                .buttonStyle(.borderless)
                .controlSize(.small)
                .foregroundColor(.secondary)
            }
        }
    }

    private var statusColor: Color {
        switch status {
        case .granted:
            return .green
        case .denied:
            return .red
        case .notDetermined, .restricted:
            return .orange
        }
    }

    private var statusText: String {
        switch status {
        case .granted:
            return NSLocalizedString("status.granted", comment: "Granted")
        case .denied:
            return NSLocalizedString("status.denied", comment: "Denied")
        case .notDetermined:
            return NSLocalizedString("status.not_set", comment: "Not Set")
        case .restricted:
            return NSLocalizedString("status.restricted", comment: "Restricted")
        }
    }
}

struct GeneralTab: View {
    @ObservedObject var settings: CoreSettings.Settings

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(NSLocalizedString("preferences.general.title", comment: "General Settings"))
                .font(.title2)
                .fontWeight(.semibold)

            // Hotkey Configuration
            VStack(alignment: .leading, spacing: 12) {
                Text(NSLocalizedString("preferences.general.global_hotkey", comment: "Global Hotkey"))
                    .font(.headline)

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(NSLocalizedString("preferences.general.hotkey_combination", comment: "Hotkey Combination:"))
                            .frame(width: 140, alignment: .leading)

                        HotkeyRecorder(hotkey: $settings.hotkey)

                        Spacer()
                    }

                    HStack {
                        Text(NSLocalizedString("preferences.general.mode", comment: "Activation Mode:"))
                            .frame(width: 140, alignment: .leading)

                        Picker(NSLocalizedString("general.mode", comment: "Mode"), selection: $settings.hotkeyMode) {
                            ForEach(HotkeyMode.allCases, id: \.self) { mode in
                                Text(mode.displayName).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 200)

                        Spacer()
                    }
                }
                .padding(16)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(12)
            }

            // Audio and Timing
            VStack(alignment: .leading, spacing: 12) {
                Text(NSLocalizedString("preferences.general.audio_timing", comment: "Audio & Timing"))
                    .font(.headline)

                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Toggle(NSLocalizedString("preferences.general.sounds", comment: "Play sounds"), isOn: $settings.playSounds)
                        Spacer()
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(NSLocalizedString("preferences.general.limit", comment: "Dictation time limit:"))
                            Spacer()
                            Text("\(Int(settings.dictationTimeLimit / 60)) \(NSLocalizedString("preferences.general.minutes", comment: "minutes"))")
                                .foregroundColor(.secondary)
                        }

                        Slider(
                            value: Binding(
                                get: { settings.dictationTimeLimit / 60 },
                                set: { settings.dictationTimeLimit = $0 * 60 }
                            ),
                            in: 1...30,
                            step: 1
                        ) {
                            Text(NSLocalizedString("preferences.general.time_limit_slider", comment: "Time Limit"))
                        }
                    }
                }
                .padding(16)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(12)
            }

            // Settings Management
            VStack(alignment: .leading, spacing: 12) {
                Text(NSLocalizedString("preferences.general.settings_management", comment: "Settings Management"))
                    .font(.headline)

                HStack(spacing: 12) {
                    Button(NSLocalizedString("preferences.general.export_settings", comment: "Export Settings...")) {
                        exportSettings()
                    }
                    .buttonStyle(.bordered)

                    Button(NSLocalizedString("preferences.general.import_settings", comment: "Import Settings...")) {
                        importSettings()
                    }
                    .buttonStyle(.bordered)

                    Spacer()
                }
                .padding(16)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(12)
            }

            Spacer()
        }
        .padding(20)
    }

    private func exportSettings() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "\(NSLocalizedString("app.name", comment: "App name")) Settings.json"

        if panel.runModal() == .OK, let url = panel.url {
            do {
                let data = try settings.exportSettings()
                try data.write(to: url)
                // Show success message
                showAlert(title: NSLocalizedString("alert.success", comment: "Success"), message: NSLocalizedString("success.settings.exported", comment: "Settings exported"))
            } catch {
                showAlert(title: NSLocalizedString("alert.error", comment: "Error"), message: "Failed to export settings: \(error.localizedDescription)")
            }
        }
    }

    private func importSettings() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false

        if panel.runModal() == .OK, let url = panel.url {
            do {
                let data = try Data(contentsOf: url)
                try settings.importSettings(from: data)
                showAlert(title: NSLocalizedString("alert.success", comment: "Success"), message: NSLocalizedString("success.settings.imported", comment: "Settings imported"))
            } catch {
                showAlert(title: NSLocalizedString("alert.error", comment: "Error"), message: "Failed to import settings: \(error.localizedDescription)")
            }
        }
    }

    private func showAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.runModal()
    }
}

// MARK: - New Tab Views

struct InsertionTab: View {
    @ObservedObject var settings: CoreSettings.Settings

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(NSLocalizedString("preferences.insertion.title", comment: "Text Insertion"))
                .font(.title2)
                .fontWeight(.semibold)

            // Insertion Method
            VStack(alignment: .leading, spacing: 12) {
                Text(NSLocalizedString("preferences.insertion.method", comment: "Insertion Method:"))
                    .font(.headline)

                VStack(alignment: .leading, spacing: 8) {
                    Picker(NSLocalizedString("general.method", comment: "Method"), selection: $settings.insertionMethod) {
                        ForEach(InsertionMethod.allCases, id: \.self) { method in
                            Text(method.displayName).tag(method)
                        }
                    }
                    .pickerStyle(.segmented)

                    Text(NSLocalizedString("preferences.insertion.method_description", comment: "Insertion method description"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(16)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(12)
            }

            // Preview Settings
            VStack(alignment: .leading, spacing: 12) {
                Text(NSLocalizedString("preferences.insertion.preview", comment: "Preview"))
                    .font(.headline)

                VStack(alignment: .leading, spacing: 8) {
                    Toggle(NSLocalizedString("preferences.insertion.preview", comment: "Show preview"), isOn: $settings.showPreview)

                    Text(NSLocalizedString("preferences.insertion.preview_description", comment: "Preview description"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(16)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(12)
            }

            // Secure Input Information
            VStack(alignment: .leading, spacing: 12) {
                Text(NSLocalizedString("preferences.insertion.secure_input_title", comment: "Secure Input Handling"))
                    .font(.headline)

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "info.circle")
                            .foregroundColor(.blue)
                        Text(NSLocalizedString("preferences.insertion.secure_input_description", comment: "Secure input description"))
                            .font(.body)
                    }
                }
                .padding(16)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(12)
            }

            Spacer()
        }
        .padding(20)
    }
}

struct HUDTab: View {
    @ObservedObject var settings: CoreSettings.Settings

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(NSLocalizedString("preferences.hud.title", comment: "Interface Settings"))
                .font(.title2)
                .fontWeight(.semibold)

            // HUD Appearance
            VStack(alignment: .leading, spacing: 12) {
                Text(NSLocalizedString("preferences.hud.appearance", comment: "HUD Appearance"))
                    .font(.headline)

                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(NSLocalizedString("preferences.hud.opacity", comment: "Opacity:"))
                            Spacer()
                            Text("\(Int(settings.hudOpacity * 100))%")
                                .foregroundColor(.secondary)
                        }

                        Slider(value: $settings.hudOpacity, in: 0.3...1.0, step: 0.1) {
                            Text(NSLocalizedString("preferences.hud.opacity_slider", comment: "HUD Opacity"))
                        }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(NSLocalizedString("preferences.hud.size", comment: "Size:"))
                            Spacer()
                            Text("\(Int(settings.hudSize * 100))%")
                                .foregroundColor(.secondary)
                        }

                        Slider(value: $settings.hudSize, in: 0.8...1.5, step: 0.1) {
                            Text(NSLocalizedString("preferences.hud.size_slider", comment: "HUD Size"))
                        }
                    }
                }
                .padding(16)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(12)
            }

            // Audio Feedback
            VStack(alignment: .leading, spacing: 12) {
                Text(NSLocalizedString("preferences.hud.audio_feedback", comment: "Audio Feedback"))
                    .font(.headline)

                VStack(alignment: .leading, spacing: 8) {
                    Toggle(NSLocalizedString("preferences.general.sounds", comment: "Play sounds for dictation"), isOn: $settings.playSounds)

                    Text(NSLocalizedString("preferences.hud.sounds_description", comment: "Sounds description"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(16)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(12)
            }

            Spacer()
        }
        .padding(20)
    }
}

struct AdvancedTab: View {
    @ObservedObject var settings: CoreSettings.Settings
    @State private var showingResetAlert = false

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(NSLocalizedString("preferences.advanced.title", comment: "Advanced Settings"))
                .font(.title2)
                .fontWeight(.semibold)

            // Processing Settings
            VStack(alignment: .leading, spacing: 12) {
                Text(NSLocalizedString("preferences.advanced.processing", comment: "Processing"))
                    .font(.headline)

                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(NSLocalizedString("preferences.advanced.threads", comment: "Processing threads:"))
                            Spacer()
                            Text("\(settings.processingThreads)")
                                .foregroundColor(.secondary)
                        }

                        Slider(
                            value: Binding(
                                get: { Double(settings.processingThreads) },
                                set: { settings.processingThreads = Int($0) }
                            ),
                            in: 1...8,
                            step: 1
                        ) {
                            Text(NSLocalizedString("preferences.advanced.threads_slider", comment: "Processing Threads"))
                        }

                        Text(NSLocalizedString("preferences.advanced.threads_description", comment: "Threads description"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(16)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(12)
            }

            // Logging Settings
            VStack(alignment: .leading, spacing: 12) {
                Text(NSLocalizedString("preferences.advanced.logging", comment: "Logging"))
                    .font(.headline)

                VStack(alignment: .leading, spacing: 8) {
                    Toggle(NSLocalizedString("preferences.advanced.enable_logging", comment: "Enable logging"), isOn: $settings.enableLogging)

                    Text(NSLocalizedString("preferences.advanced.logging_description", comment: "Logging description"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(16)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(12)
            }

            // Reset Settings
            VStack(alignment: .leading, spacing: 12) {
                Text(NSLocalizedString("preferences.advanced.reset", comment: "Reset"))
                    .font(.headline)

                HStack {
                    Button(NSLocalizedString("preferences.advanced.reset_button", comment: "Reset All Settings")) {
                        showingResetAlert = true
                    }
                    .buttonStyle(.bordered)
                    .foregroundColor(.red)

                    Spacer()
                }
                .padding(16)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(12)
            }

            Spacer()
        }
        .padding(20)
        .alert(NSLocalizedString("preferences.advanced.reset_title", comment: "Reset Settings"), isPresented: $showingResetAlert) {
            Button(NSLocalizedString("general.cancel", comment: "Cancel"), role: .cancel) { }
            Button(NSLocalizedString("general.reset", comment: "Reset"), role: .destructive) {
                resetSettings()
            }
        } message: {
            Text(NSLocalizedString("preferences.advanced.reset_message", comment: "Reset confirmation"))
        }
    }

    private func resetSettings() {
        // Reset all settings to defaults
        settings.hotkey = HotkeyConfig.default
        settings.hotkeyMode = .pushToTalk
        settings.playSounds = false
        settings.dictationTimeLimit = 600
        settings.hudOpacity = 0.9
        settings.hudSize = 1.0
        settings.forcedLanguage = nil
        settings.insertionMethod = .paste
        settings.showPreview = false
        settings.enableLogging = false
        settings.processingThreads = 4
    }
}
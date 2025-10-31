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

        window.title = L("preferences.title")
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
                    Label(L("preferences.general"), systemImage: "gearshape")
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
                Label(L("preferences.models"), systemImage: "brain.head.profile")
            }
            .tag(1)

            InsertionTab(settings: settings)
                .tabItem {
                    Label(L("preferences.insertion"), systemImage: "text.cursor")
                }
                .tag(2)

            HUDTab(settings: settings)
                .tabItem {
                    Label(L("preferences.interface"), systemImage: "rectangle.on.rectangle")
                }
                .tag(3)

            AdvancedTab(settings: settings)
                .tabItem {
                    Label(L("preferences.advanced"), systemImage: "slider.horizontal.3")
                }
                .tag(4)

            PermissionsTab(permissionManager: permissionManager)
                .tabItem {
                    Label(L("preferences.permissions"), systemImage: "lock.shield")
                }
                .tag(5)
        }
        .frame(minWidth: 750, idealWidth: 800, maxWidth: 1200, minHeight: 600, idealHeight: 600, maxHeight: 800)
        .alert(L("alert.delete_model"), isPresented: $showingDeleteAlert) {
            Button(L("general.cancel"), role: .cancel) {
                modelToDelete = nil
            }
            Button(L("preferences.models.delete"), role: .destructive) {
                if let model = modelToDelete {
                    deleteModel(model)
                }
                modelToDelete = nil
            }
        } message: {
            if let model = modelToDelete {
                Text(String(format: L("preferences.models.delete_confirm"), model.name))
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
            Text(L("preferences.models.title"))
                .font(.title2)
                .fontWeight(.semibold)

            Text(L("preferences.models.description"))
                .font(.caption)
                .foregroundColor(.secondary)

            // Current Model Status
            VStack(alignment: .leading, spacing: 8) {
                Text(L("preferences.models.current_model"))
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

                        Text(whisperEngine.isModelLoaded() ? L("status.loaded") : L("status.loading"))
                            .font(.caption)
                            .foregroundColor(whisperEngine.isModelLoaded() ? .green : .orange)
                    }
                    .padding(12)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(8)
                } else {
                    Text(L("preferences.models.no_model"))
                        .foregroundColor(.secondary)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(8)
                }
            }

            // Language Settings
            VStack(alignment: .leading, spacing: 8) {
                Text(L("preferences.models.language"))
                    .font(.headline)

                HStack {
                    Text(L("preferences.models.recognition_language"))
                        .font(.body)

                    Picker(L("general.language"), selection: Binding(
                        get: { settings.forcedLanguage ?? "auto" },
                        set: { newValue in
                            settings.forcedLanguage = newValue == "auto" ? nil : newValue
                        }
                    )) {
                        Text(L("language.auto_detect")).tag("auto")
                        Divider()
                        Text(L("language.english")).tag("en")
                        Text(L("language.spanish")).tag("es")
                        Text(L("language.french")).tag("fr")
                        Text(L("language.german")).tag("de")
                        Text(L("language.italian")).tag("it")
                        Text(L("language.portuguese")).tag("pt")
                        Text(L("language.russian")).tag("ru")
                        Text(L("language.chinese")).tag("zh")
                        Text(L("language.japanese")).tag("ja")
                        Text(L("language.korean")).tag("ko")
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
                Text(L("preferences.models.available_models"))
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
                        Text(L("preferences.models.active_badge"))
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
                            Button(L("general.select")) {
                                onSelect()
                            }
                            .buttonStyle(.bordered)
                        }

                        Button(L("preferences.models.delete")) {
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
                            Text(L("preferences.models.downloading"))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    } else {
                        Button(L("preferences.models.download")) {
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
            Text(L("preferences.permissions"))
                .font(.title2)
                .fontWeight(.semibold)

            Text(L("preferences.permissions.description"))
                .font(.caption)
                .foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: 12) {
                // Microphone Permission
                PermissionRow(
                    title: L("permissions.microphone.title_short"),
                    description: L("permissions.microphone.description_short"),
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
                    title: L("permissions.accessibility.title_short"),
                    description: L("permissions.accessibility.description_short"),
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
                    title: L("permissions.input_monitoring.title_short"),
                    description: L("permissions.input_monitoring.description_short"),
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
                Text(L("preferences.permissions.need_help"))
                    .font(.headline)

                Text(L("preferences.permissions.after_granting"))
                    .font(.body)
                    .foregroundColor(.secondary)

                VStack(alignment: .leading, spacing: 4) {
                    Text(L("preferences.permissions.step1"))
                    Text(L("preferences.permissions.step2"))
                    Text(L("preferences.permissions.step3"))
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
                    Button(L("permissions.open_settings")) {
                        onOpenSettings()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }

                Button(L("permissions.refresh_status")) {
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
            return L("status.granted")
        case .denied:
            return L("status.denied")
        case .notDetermined:
            return L("status.not_set")
        case .restricted:
            return L("status.restricted")
        }
    }
}

struct GeneralTab: View {
    @ObservedObject var settings: CoreSettings.Settings

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(L("preferences.general.title"))
                .font(.title2)
                .fontWeight(.semibold)

            // Hotkey Configuration
            VStack(alignment: .leading, spacing: 12) {
                Text(L("preferences.general.global_hotkey"))
                    .font(.headline)

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(L("preferences.general.hotkey_combination"))
                            .frame(width: 140, alignment: .leading)

                        HotkeyRecorder(hotkey: $settings.hotkey)

                        Spacer()
                    }

                    HStack {
                        Text(L("preferences.general.mode"))
                            .frame(width: 140, alignment: .leading)

                        Picker(L("general.mode"), selection: $settings.hotkeyMode) {
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
                Text(L("preferences.general.audio_timing"))
                    .font(.headline)

                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Toggle(L("preferences.general.sounds"), isOn: $settings.playSounds)
                        Spacer()
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(L("preferences.general.limit"))
                            Spacer()
                            Text("\(Int(settings.dictationTimeLimit / 60)) \(L("preferences.general.minutes"))")
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
                            Text(L("preferences.general.time_limit_slider"))
                        }
                    }
                }
                .padding(16)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(12)
            }

            // Settings Management
            VStack(alignment: .leading, spacing: 12) {
                Text(L("preferences.general.settings_management"))
                    .font(.headline)

                HStack(spacing: 12) {
                    Button(L("preferences.general.export_settings")) {
                        exportSettings()
                    }
                    .buttonStyle(.bordered)

                    Button(L("preferences.general.import_settings")) {
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
        panel.nameFieldStringValue = "\(L("app.name")) Settings.json"

        if panel.runModal() == .OK, let url = panel.url {
            do {
                let data = try settings.exportSettings()
                try data.write(to: url)
                // Show success message
                showAlert(title: L("alert.success"), message: L("success.settings.exported"))
            } catch {
                showAlert(title: L("alert.error"), message: "Failed to export settings: \(error.localizedDescription)")
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
                showAlert(title: L("alert.success"), message: L("success.settings.imported"))
            } catch {
                showAlert(title: L("alert.error"), message: "Failed to import settings: \(error.localizedDescription)")
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
            Text(L("preferences.insertion.title"))
                .font(.title2)
                .fontWeight(.semibold)

            // Insertion Method
            VStack(alignment: .leading, spacing: 12) {
                Text(L("preferences.insertion.method"))
                    .font(.headline)

                VStack(alignment: .leading, spacing: 8) {
                    Picker(L("general.method"), selection: $settings.insertionMethod) {
                        ForEach(InsertionMethod.allCases, id: \.self) { method in
                            Text(method.displayName).tag(method)
                        }
                    }
                    .pickerStyle(.segmented)

                    Text(L("preferences.insertion.method_description"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(16)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(12)
            }

            // Preview Settings
            VStack(alignment: .leading, spacing: 12) {
                Text(L("preferences.insertion.preview"))
                    .font(.headline)

                VStack(alignment: .leading, spacing: 8) {
                    Toggle(L("preferences.insertion.preview"), isOn: $settings.showPreview)

                    Text(L("preferences.insertion.preview_description"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(16)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(12)
            }

            // Secure Input Information
            VStack(alignment: .leading, spacing: 12) {
                Text(L("preferences.insertion.secure_input_title"))
                    .font(.headline)

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "info.circle")
                            .foregroundColor(.blue)
                        Text(L("preferences.insertion.secure_input_description"))
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
            Text(L("preferences.hud.title"))
                .font(.title2)
                .fontWeight(.semibold)

            // HUD Appearance
            VStack(alignment: .leading, spacing: 12) {
                Text(L("preferences.hud.appearance"))
                    .font(.headline)

                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(L("preferences.hud.opacity"))
                            Spacer()
                            Text("\(Int(settings.hudOpacity * 100))%")
                                .foregroundColor(.secondary)
                        }

                        Slider(value: $settings.hudOpacity, in: 0.3...1.0, step: 0.1) {
                            Text(L("preferences.hud.opacity_slider"))
                        }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(L("preferences.hud.size"))
                            Spacer()
                            Text("\(Int(settings.hudSize * 100))%")
                                .foregroundColor(.secondary)
                        }

                        Slider(value: $settings.hudSize, in: 0.8...1.5, step: 0.1) {
                            Text(L("preferences.hud.size_slider"))
                        }
                    }
                }
                .padding(16)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(12)
            }

            // Audio Feedback
            VStack(alignment: .leading, spacing: 12) {
                Text(L("preferences.hud.audio_feedback"))
                    .font(.headline)

                VStack(alignment: .leading, spacing: 8) {
                    Toggle(L("preferences.general.sounds"), isOn: $settings.playSounds)

                    Text(L("preferences.hud.sounds_description"))
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
            Text(L("preferences.advanced.title"))
                .font(.title2)
                .fontWeight(.semibold)

            // Processing Settings
            VStack(alignment: .leading, spacing: 12) {
                Text(L("preferences.advanced.processing"))
                    .font(.headline)

                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(L("preferences.advanced.threads"))
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
                            Text(L("preferences.advanced.threads_slider"))
                        }

                        Text(L("preferences.advanced.threads_description"))
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
                Text(L("preferences.advanced.logging"))
                    .font(.headline)

                VStack(alignment: .leading, spacing: 8) {
                    Toggle(L("preferences.advanced.enable_logging"), isOn: $settings.enableLogging)

                    Text(L("preferences.advanced.logging_description"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(16)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(12)
            }

            // Reset Settings
            VStack(alignment: .leading, spacing: 12) {
                Text(L("preferences.advanced.reset"))
                    .font(.headline)

                HStack {
                    Button(L("preferences.advanced.reset_button")) {
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
        .alert(L("preferences.advanced.reset_title"), isPresented: $showingResetAlert) {
            Button(L("general.cancel"), role: .cancel) { }
            Button(L("general.reset"), role: .destructive) {
                resetSettings()
            }
        } message: {
            Text(L("preferences.advanced.reset_message"))
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
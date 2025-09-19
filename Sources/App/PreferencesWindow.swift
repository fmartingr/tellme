import SwiftUI
import CoreModels
import CoreSTT
import CoreUtils

class PreferencesWindowController: NSWindowController {
    private let modelManager: ModelManager
    private let whisperEngine: WhisperCPPEngine

    init(modelManager: ModelManager, whisperEngine: WhisperCPPEngine) {
        self.modelManager = modelManager
        self.whisperEngine = whisperEngine

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 500),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )

        super.init(window: window)

        window.title = "MenuWhisper Preferences"
        window.center()
        window.contentView = NSHostingView(
            rootView: PreferencesView(
                modelManager: modelManager,
                whisperEngine: whisperEngine,
                onClose: { [weak self] in
                    self?.close()
                }
            )
        )
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

struct PreferencesView: View {
    @ObservedObject var modelManager: ModelManager
    let whisperEngine: WhisperCPPEngine
    let onClose: () -> Void

    @State private var selectedTab = 0
    @State private var isDownloading: [String: Bool] = [:]
    @State private var downloadProgress: [String: Double] = [:]
    @State private var showingDeleteAlert = false
    @State private var modelToDelete: ModelInfo?

    var body: some View {
        TabView(selection: $selectedTab) {
            ModelsTab(
                modelManager: modelManager,
                whisperEngine: whisperEngine,
                isDownloading: $isDownloading,
                downloadProgress: $downloadProgress,
                showingDeleteAlert: $showingDeleteAlert,
                modelToDelete: $modelToDelete
            )
            .tabItem {
                Label("Models", systemImage: "brain.head.profile")
            }
            .tag(0)

            GeneralTab()
                .tabItem {
                    Label("General", systemImage: "gearshape")
                }
                .tag(1)
        }
        .frame(width: 600, height: 500)
        .alert("Delete Model", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) {
                modelToDelete = nil
            }
            Button("Delete", role: .destructive) {
                if let model = modelToDelete {
                    deleteModel(model)
                }
                modelToDelete = nil
            }
        } message: {
            if let model = modelToDelete {
                Text("Are you sure you want to delete '\(model.name)'? This action cannot be undone.")
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

    @Binding var isDownloading: [String: Bool]
    @Binding var downloadProgress: [String: Double]
    @Binding var showingDeleteAlert: Bool
    @Binding var modelToDelete: ModelInfo?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Speech Recognition Models")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Download and manage speech recognition models. Larger models provide better accuracy but use more memory and processing time.")
                .font(.caption)
                .foregroundColor(.secondary)

            // Current Model Status
            VStack(alignment: .leading, spacing: 8) {
                Text("Current Model")
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

                        Text(whisperEngine.isModelLoaded() ? "Loaded" : "Loading...")
                            .font(.caption)
                            .foregroundColor(whisperEngine.isModelLoaded() ? .green : .orange)
                    }
                    .padding(12)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(8)
                } else {
                    Text("No model selected")
                        .foregroundColor(.secondary)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(8)
                }
            }

            // Available Models
            VStack(alignment: .leading, spacing: 8) {
                Text("Available Models")
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
                        Text("ACTIVE")
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
                            Button("Select") {
                                onSelect()
                            }
                            .buttonStyle(.bordered)
                        }

                        Button("Delete") {
                            onDelete()
                        }
                        .buttonStyle(.bordered)
                        .foregroundColor(.red)
                    }
                } else {
                    if isDownloading {
                        VStack {
                            ProgressView(value: downloadProgress)
                                .frame(width: 80)
                            Text("\(Int(downloadProgress * 100))%")
                                .font(.caption)
                        }
                    } else {
                        Button("Download") {
                            onDownload()
                        }
                        .buttonStyle(.bordered)
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

struct GeneralTab: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("General Settings")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Additional settings will be available in Phase 4.")
                .font(.body)
                .foregroundColor(.secondary)

            Spacer()
        }
        .padding(20)
    }
}
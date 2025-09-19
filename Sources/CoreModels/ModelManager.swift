import Foundation
import CoreUtils
import CryptoKit

public struct ModelInfo: Codable, Identifiable {
    public let id = UUID()
    public let name: String
    public let family: String
    public let format: String
    public let sizeMB: Int
    public let languages: [String]
    public let recommendedBackend: String
    public let qualityTier: String
    public let license: String
    public let sha256: String
    public let downloadURL: String
    public let notes: String

    enum CodingKeys: String, CodingKey {
        case name, family, format, languages, license, sha256, notes
        case sizeMB = "size_mb"
        case recommendedBackend = "recommended_backend"
        case qualityTier = "quality_tier"
        case downloadURL = "download_url"
    }

    public var fileURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let modelsDirectory = appSupport.appendingPathComponent("TellMe/Models")
        return modelsDirectory.appendingPathComponent(filename)
    }

    public var filename: String {
        return "\(name).bin"
    }

    public var isDownloaded: Bool {
        return FileManager.default.fileExists(atPath: fileURL.path)
    }

    public var estimatedRAM: String {
        switch qualityTier {
        case "tiny":
            return "~0.5GB"
        case "base":
            return "~1GB"
        case "small":
            return "~1.5-2GB"
        case "medium":
            return "~2-3GB"
        case "large":
            return "~4-5GB"
        default:
            return "Unknown"
        }
    }
}

public struct ModelCatalog: Codable {
    public let models: [ModelInfo]
}

public struct DownloadProgress {
    public let bytesDownloaded: Int64
    public let totalBytes: Int64
    public let progress: Double

    public var progressText: String {
        let downloaded = ByteCountFormatter.string(fromByteCount: bytesDownloaded, countStyle: .binary)
        let total = ByteCountFormatter.string(fromByteCount: totalBytes, countStyle: .binary)
        return "\(downloaded) / \(total)"
    }
}

public enum ModelError: Error, LocalizedError {
    case catalogNotFound
    case invalidCatalog
    case downloadFailed(String)
    case checksumMismatch
    case diskSpaceInsufficient
    case modelNotFound
    case deleteFailed(String)

    public var errorDescription: String? {
        switch self {
        case .catalogNotFound:
            return "Model catalog not found"
        case .invalidCatalog:
            return "Invalid model catalog format"
        case .downloadFailed(let reason):
            return "Download failed: \(reason)"
        case .checksumMismatch:
            return "Downloaded file checksum does not match expected value"
        case .diskSpaceInsufficient:
            return "Insufficient disk space to download model"
        case .modelNotFound:
            return "Model file not found"
        case .deleteFailed(let reason):
            return "Failed to delete model: \(reason)"
        }
    }
}

@MainActor
public class ModelManager: NSObject, ObservableObject {
    private let logger = Logger(category: "ModelManager")

    @Published public private(set) var availableModels: [ModelInfo] = []
    @Published public private(set) var downloadedModels: [ModelInfo] = []
    @Published public private(set) var activeModel: ModelInfo?
    @Published public private(set) var downloadProgress: [String: DownloadProgress] = [:]

    private let modelsDirectory: URL
    private var urlSession: URLSession
    private var downloadTasks: [String: URLSessionDownloadTask] = [:]
    private var progressCallbacks: [String: (DownloadProgress) -> Void] = [:]

    public override init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        modelsDirectory = appSupport.appendingPathComponent("TellMe/Models")

        // Configure URLSession for downloads (simple session, delegates created per download)
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 3600 // 1 hour for large model downloads
        urlSession = URLSession(configuration: config)

        super.init()

        try? FileManager.default.createDirectory(at: modelsDirectory, withIntermediateDirectories: true)

        // Ensure we have models available - use fallback approach first
        createFallbackCatalog()

        // Try to load from JSON file as well
        loadModelCatalog()

        refreshDownloadedModels()
        loadActiveModelPreference()
    }

    deinit {
        // Cancel any active downloads
        downloadTasks.values.forEach { $0.cancel() }
    }

    public func downloadModel(_ model: ModelInfo, progressCallback: @escaping (DownloadProgress) -> Void = { _ in }) async throws {
        logger.info("Starting download for model: \(model.name)")

        // Check if already downloaded
        if model.isDownloaded {
            logger.info("Model \(model.name) already downloaded")
            return
        }

        // Download both .bin and .mlmodelc files
        try await downloadModelFile(model, progressCallback: progressCallback)
        try await downloadCoreMlEncoder(model)

        // Refresh downloaded models list
        refreshDownloadedModels()
        logger.info("Model \(model.name) downloaded completely with Core ML support")
    }

    private func downloadModelFile(_ model: ModelInfo, progressCallback: @escaping (DownloadProgress) -> Void = { _ in }) async throws {
        // Check disk space
        let requiredSpace = Int64(model.sizeMB) * 1024 * 1024
        let availableSpace = try getAvailableDiskSpace()

        if availableSpace < requiredSpace * 2 { // Need 2x space for download + final file
            throw ModelError.diskSpaceInsufficient
        }

        guard let url = URL(string: model.downloadURL) else {
            throw ModelError.downloadFailed("Invalid download URL")
        }

        let modelName = model.name
        let modelSHA256 = model.sha256
        let modelFileURL = model.fileURL

        print("Starting download for \(modelName) from \(url)")

        // Use simple URLSession download for reliability (progress spinners don't need exact progress)
        let (tempURL, response) = try await urlSession.download(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw ModelError.downloadFailed("HTTP error: \(String(describing: (response as? HTTPURLResponse)?.statusCode))")
        }

        print("Download completed for \(modelName)")

        // Verify SHA256 checksum if provided
        if !modelSHA256.isEmpty {
            try await verifyChecksum(fileURL: tempURL, expectedSHA256: modelSHA256)
        }

        // Move to final location
        if FileManager.default.fileExists(atPath: modelFileURL.path) {
            try FileManager.default.removeItem(at: modelFileURL)
        }

        try FileManager.default.moveItem(at: tempURL, to: modelFileURL)
        logger.info("Model file \(modelName).bin downloaded successfully")
    }

    private func downloadCoreMlEncoder(_ model: ModelInfo) async throws {
        // Map model names to Core ML encoder URLs
        let encoderURLString: String
        switch model.name {
        case "whisper-tiny":
            encoderURLString = "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-tiny-encoder.mlmodelc.zip"
        case "whisper-base":
            encoderURLString = "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base-encoder.mlmodelc.zip"
        case "whisper-small":
            encoderURLString = "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-small-encoder.mlmodelc.zip"
        default:
            logger.info("No Core ML encoder available for \(model.name)")
            return
        }

        guard let encoderURL = URL(string: encoderURLString) else {
            logger.warning("Invalid Core ML encoder URL for \(model.name)")
            return
        }

        do {
            logger.info("Downloading Core ML encoder for \(model.name)")
            let (tempFileURL, response) = try await urlSession.download(from: encoderURL)

            guard let httpResponse = response as? HTTPURLResponse,
                  (200..<300).contains(httpResponse.statusCode) else {
                logger.warning("Core ML encoder download failed for \(model.name)")
                return
            }

            // Extract zip to models directory
            let encoderName = "\(model.name)-encoder.mlmodelc"
            let encoderPath = modelsDirectory.appendingPathComponent(encoderName)

            // Remove existing encoder if present
            if FileManager.default.fileExists(atPath: encoderPath.path) {
                try? FileManager.default.removeItem(at: encoderPath)
            }

            // Unzip the Core ML model
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
            process.arguments = ["-q", tempFileURL.path, "-d", modelsDirectory.path]

            try process.run()
            process.waitUntilExit()

            // Rename from ggml-*-encoder.mlmodelc to whisper-*-encoder.mlmodelc
            let extractedPath = modelsDirectory.appendingPathComponent("ggml-\(model.name.replacingOccurrences(of: "whisper-", with: ""))-encoder.mlmodelc")
            if FileManager.default.fileExists(atPath: extractedPath.path) {
                try FileManager.default.moveItem(at: extractedPath, to: encoderPath)
                logger.info("Core ML encoder for \(model.name) installed successfully")
            }

        } catch {
            logger.warning("Failed to download Core ML encoder for \(model.name): \(error)")
            // Don't throw - Core ML is optional, model will work without it
        }
    }

    public func cancelDownload(for model: ModelInfo) {
        if let task = downloadTasks[model.name] {
            task.cancel()
            downloadTasks.removeValue(forKey: model.name)
            downloadProgress.removeValue(forKey: model.name)
            logger.info("Cancelled download for model: \(model.name)")
        }
    }

    public func deleteModel(_ model: ModelInfo) throws {
        logger.info("Deleting model: \(model.name)")

        guard model.isDownloaded else {
            throw ModelError.modelNotFound
        }

        do {
            try FileManager.default.removeItem(at: model.fileURL)
            logger.info("Model \(model.name) deleted successfully")

            // Clear active model if it was the deleted one
            if activeModel?.name == model.name {
                activeModel = nil
                saveActiveModelPreference()
            }

            refreshDownloadedModels()
        } catch {
            logger.error("Failed to delete model \(model.name): \(error)")
            throw ModelError.deleteFailed(error.localizedDescription)
        }
    }

    public func setActiveModel(_ model: ModelInfo?) {
        logger.info("Setting active model: \(model?.name ?? "none")")
        activeModel = model
        saveActiveModelPreference()
    }

    public func getModelPath(for model: ModelInfo) -> URL? {
        guard model.isDownloaded else { return nil }
        return model.fileURL
    }

    private func verifyChecksum(fileURL: URL, expectedSHA256: String) async throws {
        let data = try Data(contentsOf: fileURL)
        let hash = SHA256.hash(data: data)
        let hashString = hash.compactMap { String(format: "%02x", $0) }.joined()

        if hashString.lowercased() != expectedSHA256.lowercased() {
            logger.error("Checksum mismatch: expected \(expectedSHA256), got \(hashString)")
            throw ModelError.checksumMismatch
        }
    }

    private func getAvailableDiskSpace() throws -> Int64 {
        let attributes = try FileManager.default.attributesOfFileSystem(forPath: modelsDirectory.path)
        return attributes[.systemFreeSize] as? Int64 ?? 0
    }

    private func loadModelCatalog() {
        // Try to load additional models from JSON file if available
        if let catalogURL = Bundle.main.url(forResource: "model-catalog", withExtension: "json") {
            loadCatalogFromURL(catalogURL)
        } else if let resourcePath = Bundle.main.resourcePath {
            let resourceCatalog = URL(fileURLWithPath: resourcePath).appendingPathComponent("model-catalog.json")
            if FileManager.default.fileExists(atPath: resourceCatalog.path) {
                loadCatalogFromURL(resourceCatalog)
            }
        }
        // Note: Fallback catalog already created, so JSON is optional enhancement
    }

    private func createFallbackCatalog() {
        // Create a minimal set of models without requiring the JSON file
        availableModels = [
            ModelInfo(
                name: "whisper-tiny",
                family: "OpenAI-Whisper",
                format: "bin",
                sizeMB: 89, // Updated to include Core ML encoder size
                languages: ["multilingual"],
                recommendedBackend: "whisper.cpp",
                qualityTier: "tiny",
                license: "MIT",
                sha256: "",
                downloadURL: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-tiny.bin",
                notes: "Fastest model, suitable for real-time applications. Includes Core ML acceleration."
            ),
            ModelInfo(
                name: "whisper-base",
                family: "OpenAI-Whisper",
                format: "bin",
                sizeMB: 192, // Updated to include Core ML encoder size
                languages: ["multilingual"],
                recommendedBackend: "whisper.cpp",
                qualityTier: "base",
                license: "MIT",
                sha256: "",
                downloadURL: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.bin",
                notes: "Good balance of speed and accuracy. Includes Core ML acceleration."
            ),
            ModelInfo(
                name: "whisper-small",
                family: "OpenAI-Whisper",
                format: "bin",
                sizeMB: 516, // Updated to include Core ML encoder size
                languages: ["multilingual"],
                recommendedBackend: "whisper.cpp",
                qualityTier: "small",
                license: "MIT",
                sha256: "",
                downloadURL: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-small.bin",
                notes: "Excellent balance of speed and accuracy. Includes Core ML acceleration."
            )
        ]
        logger.info("Created fallback catalog with \(availableModels.count) models")
    }

    private func loadCatalogFromURL(_ url: URL) {
        do {
            let data = try Data(contentsOf: url)
            let catalog = try JSONDecoder().decode(ModelCatalog.self, from: data)
            availableModels = catalog.models
            logger.info("Loaded \(availableModels.count) models from catalog")
        } catch {
            logger.error("Failed to load model catalog from \(url.path): \(error)")
        }
    }

    private func refreshDownloadedModels() {
        logger.info("Refreshing downloaded models")

        downloadedModels = availableModels.filter { $0.isDownloaded }
        logger.info("Found \(downloadedModels.count) downloaded models")
    }

    private func saveActiveModelPreference() {
        if let activeModel = activeModel {
            UserDefaults.standard.set(activeModel.name, forKey: "TellMe.ActiveModel")
        } else {
            UserDefaults.standard.removeObject(forKey: "TellMe.ActiveModel")
        }
    }

    private func loadActiveModelPreference() {
        guard let modelName = UserDefaults.standard.string(forKey: "TellMe.ActiveModel") else {
            return
        }

        activeModel = availableModels.first { $0.name == modelName && $0.isDownloaded }

        if activeModel == nil {
            // Clear preference if model is no longer available or downloaded
            UserDefaults.standard.removeObject(forKey: "TellMe.ActiveModel")
        }
    }
}


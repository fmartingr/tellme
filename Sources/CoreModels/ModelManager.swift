import Foundation
import CoreUtils

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
}

public class ModelManager: ObservableObject {
    private let logger = Logger(category: "ModelManager")

    @Published public private(set) var availableModels: [ModelInfo] = []
    @Published public private(set) var downloadedModels: [ModelInfo] = []
    @Published public private(set) var activeModel: ModelInfo?

    private let modelsDirectory: URL

    public init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        modelsDirectory = appSupport.appendingPathComponent("MenuWhisper/Models")

        try? FileManager.default.createDirectory(at: modelsDirectory, withIntermediateDirectories: true)
        loadModelCatalog()
        refreshDownloadedModels()
    }

    public func downloadModel(_ model: ModelInfo) async throws {
        logger.info("Starting download for model: \(model.name)")
        // TODO: Implement model download with progress tracking and SHA256 verification in Phase 2
    }

    public func deleteModel(_ model: ModelInfo) throws {
        logger.info("Deleting model: \(model.name)")
        // TODO: Implement model deletion in Phase 2
    }

    public func setActiveModel(_ model: ModelInfo) {
        logger.info("Setting active model: \(model.name)")
        activeModel = model
        // TODO: Persist active model selection in Phase 2
    }

    private func loadModelCatalog() {
        // TODO: Load curated model catalog from bundled JSON in Phase 2
        logger.info("Loading model catalog")
    }

    private func refreshDownloadedModels() {
        // TODO: Scan models directory and populate downloadedModels in Phase 2
        logger.info("Refreshing downloaded models")
    }
}
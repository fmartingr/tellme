import Foundation
import CoreUtils

public class WhisperCPPEngine: STTEngine {
    private let logger = Logger(category: "WhisperCPPEngine")
    private var modelPath: URL?
    private var isLoaded = false

    public init() {
        // WhisperCPP integration will be implemented in Phase 2
    }

    public func transcribe(audioData: Data, language: String?) async throws -> String {
        logger.info("Transcribing audio data")
        // TODO: Implement whisper.cpp integration in Phase 2
        throw STTError.transcriptionFailed("Not implemented yet")
    }

    public func isModelLoaded() -> Bool {
        return isLoaded
    }

    public func loadModel(at path: URL) async throws {
        logger.info("Loading model at path: \(path.path)")
        self.modelPath = path
        // TODO: Implement model loading in Phase 2
        isLoaded = true
    }

    public func unloadModel() {
        logger.info("Unloading model")
        modelPath = nil
        isLoaded = false
    }
}
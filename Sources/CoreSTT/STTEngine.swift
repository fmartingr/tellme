import Foundation
import CoreUtils

public protocol STTEngine {
    func transcribe(audioData: Data, language: String?) async throws -> String
    func isModelLoaded() -> Bool
    func loadModel(at path: URL) async throws
    func unloadModel()
}

public enum STTError: Error, LocalizedError {
    case modelNotFound
    case modelLoadFailed(String)
    case transcriptionFailed(String)
    case unsupportedFormat
    case invalidAudioData

    public var errorDescription: String? {
        switch self {
        case .modelNotFound:
            return NSLocalizedString("error.model.not_found", comment: "Model not found error")
        case .modelLoadFailed(let reason):
            return NSLocalizedString("error.model.load_failed", comment: "Model load failed error") + ": \(reason)"
        case .transcriptionFailed(let reason):
            return NSLocalizedString("error.transcription.failed", comment: "Transcription failed error") + ": \(reason)"
        case .unsupportedFormat:
            return "Unsupported audio format"
        case .invalidAudioData:
            return "Invalid audio data"
        }
    }
}
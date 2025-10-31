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
            return L("error.model.not_found")
        case .modelLoadFailed(let reason):
            return L("error.model.load_failed") + ": \(reason)"
        case .transcriptionFailed(let reason):
            return L("error.transcription.failed") + ": \(reason)"
        case .unsupportedFormat:
            return "Unsupported audio format"
        case .invalidAudioData:
            return "Invalid audio data"
        }
    }
}
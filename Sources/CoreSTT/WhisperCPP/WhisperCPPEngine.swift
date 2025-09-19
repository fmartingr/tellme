import Foundation
import CoreUtils
import SwiftWhisper

public class WhisperCPPEngine: STTEngine {
    private let logger = Logger(category: "WhisperCPPEngine")
    private var modelPath: URL?
    private var isLoaded = false
    private var whisperInstance: Whisper?

    // Configuration
    private let numThreads: Int
    private let useGPU: Bool
    private var language: WhisperLanguage = .auto

    public init(numThreads: Int = 0, useGPU: Bool = true) {
        self.numThreads = numThreads <= 0 ? min(8, max(1, ProcessInfo.processInfo.processorCount)) : numThreads
        self.useGPU = useGPU
    }

    deinit {
        unloadModel()
    }

    public func transcribe(audioData: Data, language: String?) async throws -> String {
        logger.info("Transcribing audio data of size: \(audioData.count) bytes")

        guard let whisper = whisperInstance, isLoaded else {
            throw STTError.modelNotFound
        }

        do {
            // Set language if specified
            if let language = language {
                setLanguage(language)
            }

            // Convert audio data to float array
            let audioFrames = try convertAudioDataToFloats(audioData)
            logger.info("Converted audio to \(audioFrames.count) float samples")

            // Perform transcription
            let segments = try await whisper.transcribe(audioFrames: audioFrames)

            // Combine all segment texts
            let fullTranscription = segments.map { $0.text }.joined()
            let cleanedText = normalizeText(fullTranscription)

            logger.info("Transcription completed, length: \(cleanedText.count) characters")
            return cleanedText

        } catch let whisperError as WhisperError {
            logger.error("SwiftWhisper error: \(whisperError)")
            throw mapWhisperError(whisperError)
        } catch {
            logger.error("Transcription error: \(error)")
            throw STTError.transcriptionFailed(error.localizedDescription)
        }
    }

    private func setLanguage(_ languageCode: String) {
        let whisperLanguage: WhisperLanguage

        switch languageCode.lowercased() {
        case "auto":
            whisperLanguage = .auto
        case "en", "english":
            whisperLanguage = .english
        case "es", "spanish":
            whisperLanguage = .spanish
        case "fr", "french":
            whisperLanguage = .french
        case "de", "german":
            whisperLanguage = .german
        case "it", "italian":
            whisperLanguage = .italian
        case "pt", "portuguese":
            whisperLanguage = .portuguese
        case "ja", "japanese":
            whisperLanguage = .japanese
        case "ko", "korean":
            whisperLanguage = .korean
        case "zh", "chinese":
            whisperLanguage = .chinese
        case "ru", "russian":
            whisperLanguage = .russian
        default:
            logger.warning("Unknown language code: \(languageCode), using auto-detection")
            whisperLanguage = .auto
        }

        self.language = whisperLanguage
        whisperInstance?.params.language = whisperLanguage
    }

    private func mapWhisperError(_ error: WhisperError) -> STTError {
        switch error {
        case .instanceBusy:
            return STTError.transcriptionFailed("Whisper instance is busy")
        case .invalidFrames:
            return STTError.invalidAudioData
        case .cancelled:
            return STTError.transcriptionFailed("Transcription was cancelled")
        case .cancellationError(let cancellationError):
            return STTError.transcriptionFailed("Cancellation error: \(cancellationError)")
        }
    }

    private func convertAudioDataToFloats(_ audioData: Data) throws -> [Float] {
        guard audioData.count % 2 == 0 else {
            throw STTError.invalidAudioData
        }

        let sampleCount = audioData.count / 2
        var samples: [Float] = []
        samples.reserveCapacity(sampleCount)

        audioData.withUnsafeBytes { bytes in
            let int16Samples = bytes.bindMemory(to: Int16.self)
            for sample in int16Samples {
                // Convert Int16 to Float in range [-1.0, 1.0]
                samples.append(Float(sample) / 32768.0)
            }
        }

        return samples
    }

    private func normalizeText(_ text: String) -> String {
        return text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "  ", with: " ")
            .replacingOccurrences(of: "\u{201C}", with: "\"")
            .replacingOccurrences(of: "\u{201D}", with: "\"")
            .replacingOccurrences(of: "\u{2018}", with: "'")
            .replacingOccurrences(of: "\u{2019}", with: "'")
            .replacingOccurrences(of: "—", with: "-")
            .replacingOccurrences(of: "–", with: "-")
    }

    public func isModelLoaded() -> Bool {
        return isLoaded && whisperInstance != nil
    }

    public func loadModel(at path: URL) async throws {
        logger.info("Loading model at path: \(path.path)")

        // Unload existing model first
        unloadModel()

        guard FileManager.default.fileExists(atPath: path.path) else {
            throw STTError.modelNotFound
        }

        // Create WhisperParams with our configuration
        let params = WhisperParams(strategy: .greedy)
        params.language = language

        // Configure additional params if needed
        params.n_threads = Int32(numThreads)

        // Initialize SwiftWhisper instance
        let whisper = Whisper(fromFileURL: path, withParams: params)

        self.whisperInstance = whisper
        self.modelPath = path
        self.isLoaded = true

        logger.info("Model loaded successfully with SwiftWhisper")
    }

    public func unloadModel() {
        logger.info("Unloading model")

        whisperInstance = nil
        modelPath = nil
        isLoaded = false

        logger.info("Model unloaded")
    }
}
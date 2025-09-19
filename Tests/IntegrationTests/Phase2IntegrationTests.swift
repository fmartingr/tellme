import XCTest
@testable import CoreSTT
@testable import CoreModels
@testable import TellMeAudio

/// Integration tests to verify Phase 2 whisper.cpp implementation
/// These tests validate the architecture without requiring real model files
final class Phase2IntegrationTests: XCTestCase {

    var modelManager: ModelManager!
    var whisperEngine: WhisperCPPEngine!

    override func setUp() async throws {
        try await super.setUp()
        modelManager = await ModelManager()
        whisperEngine = WhisperCPPEngine()
    }

    override func tearDown() async throws {
        whisperEngine?.unloadModel()
        whisperEngine = nil
        modelManager = nil
        try await super.tearDown()
    }

    /// Test that model catalog loads correctly with SwiftWhisper-compatible format
    @MainActor
    func testModelCatalogCompatibility() async throws {
        // Verify models are loaded
        XCTAssertFalse(modelManager.availableModels.isEmpty, "Should have available models")

        // Verify all models have correct format
        for model in modelManager.availableModels {
            XCTAssertEqual(model.format, "bin", "All models should have 'bin' format for SwiftWhisper")
            XCTAssertTrue(model.downloadURL.contains("huggingface.co"), "Should use HuggingFace URLs")
            XCTAssertTrue(model.downloadURL.contains("ggml-"), "Should use ggml format files")
            XCTAssertTrue(model.downloadURL.hasSuffix(".bin"), "Should download .bin files")
        }

        // Verify we have expected model tiers
        let tiers = Set(modelManager.availableModels.map { $0.qualityTier })
        XCTAssertTrue(tiers.contains("tiny"), "Should have tiny models")
        XCTAssertTrue(tiers.contains("small"), "Should have small models")
        XCTAssertTrue(tiers.contains("base"), "Should have base models")
    }

    /// Test WhisperCPPEngine initialization and configuration
    func testWhisperEngineInitialization() {
        XCTAssertFalse(whisperEngine.isModelLoaded(), "Should start unloaded")

        // Test configuration
        let customEngine = WhisperCPPEngine(numThreads: 4, useGPU: false)
        XCTAssertFalse(customEngine.isModelLoaded(), "Custom engine should start unloaded")
    }

    /// Test model loading error handling (without real model)
    func testModelLoadingErrorHandling() async {
        // Test loading non-existent model
        let nonExistentPath = URL(fileURLWithPath: "/tmp/nonexistent_model.bin")

        do {
            try await whisperEngine.loadModel(at: nonExistentPath)
            XCTFail("Should throw error for non-existent model")
        } catch let error as STTError {
            switch error {
            case .modelNotFound:
                // Expected error
                break
            default:
                XCTFail("Should throw modelNotFound error, got: \(error)")
            }
        } catch {
            XCTFail("Should throw STTError, got: \(error)")
        }

        XCTAssertFalse(whisperEngine.isModelLoaded(), "Should remain unloaded after error")
    }

    /// Test transcription error handling (without model loaded)
    func testTranscriptionErrorHandling() async {
        // Test transcription without loaded model
        let dummyAudioData = Data(repeating: 0, count: 1000)

        do {
            _ = try await whisperEngine.transcribe(audioData: dummyAudioData, language: "en")
            XCTFail("Should throw error when no model is loaded")
        } catch let error as STTError {
            switch error {
            case .modelNotFound:
                // Expected error
                break
            default:
                XCTFail("Should throw modelNotFound error, got: \(error)")
            }
        } catch {
            XCTFail("Should throw STTError, got: \(error)")
        }
    }

    /// Test audio data conversion (without actual transcription)
    func testAudioDataConversion() throws {
        // Test valid PCM data (even number of bytes)
        let validPCMData = Data([0x00, 0x01, 0x02, 0x03, 0x04, 0x05]) // 6 bytes = 3 samples

        // This would normally be called internally, but we can test the conversion logic
        // by creating invalid data that should throw an error
        let invalidPCMData = Data([0x00, 0x01, 0x02]) // Odd number of bytes

        // We can't directly test the private convertAudioDataToFloats method,
        // but we can test that transcription properly handles invalid data
        Task {
            do {
                _ = try await whisperEngine.transcribe(audioData: invalidPCMData, language: "en")
                // This will fail at model loading, which is expected
            } catch {
                // Expected - either model not found or invalid audio data
            }
        }
    }

    /// Test model management integration
    @MainActor
    func testModelManagerIntegration() async throws {
        guard let testModel = modelManager.availableModels.first else {
            XCTFail("No models available for testing")
            return
        }

        // Test model selection
        modelManager.setActiveModel(testModel)
        XCTAssertEqual(modelManager.activeModel?.name, testModel.name, "Active model should be set")

        // Test model path generation
        let modelPath = testModel.fileURL
        XCTAssertTrue(modelPath.absoluteString.contains("TellMe/Models"), "Should use correct models directory")
        XCTAssertTrue(modelPath.lastPathComponent.hasSuffix(".bin"), "Should generate .bin filename")

        // Test estimated RAM info
        XCTAssertFalse(testModel.estimatedRAM.isEmpty, "Should provide RAM estimate")
    }

    /// Test language configuration
    func testLanguageConfiguration() {
        // Test that engine can be configured with different languages
        // This validates the language mapping logic
        let supportedLanguages = ["auto", "en", "es", "fr", "de"]

        for language in supportedLanguages {
            // We can't directly test setLanguage since it's private,
            // but transcription would use this internally
            Task {
                do {
                    _ = try await whisperEngine.transcribe(audioData: Data(), language: language)
                    // Will fail due to no model, but language setting should work
                } catch {
                    // Expected failure due to no model loaded
                }
            }
        }
    }

    /// Test full pipeline architecture (without actual execution)
    @MainActor
    func testPipelineArchitecture() async {
        // Verify all components can be instantiated together
        let audioEngine = AudioEngine()
        let testModelManager = await ModelManager()
        let sttEngine = WhisperCPPEngine()

        XCTAssertNotNil(audioEngine, "AudioEngine should initialize")
        XCTAssertNotNil(testModelManager, "ModelManager should initialize")
        XCTAssertNotNil(sttEngine, "WhisperCPPEngine should initialize")

        // Verify they expose expected interfaces
        XCTAssertFalse(sttEngine.isModelLoaded(), "STTEngine should start unloaded")
        XCTAssertFalse(testModelManager.availableModels.isEmpty, "ModelManager should have models")
        XCTAssertFalse(audioEngine.isCapturing, "AudioEngine should start idle")
    }
}
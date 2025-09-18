import XCTest
@testable import MenuWhisperAudio

final class AudioEngineTests: XCTestCase {
    func testAudioEngineInitialization() {
        let engine = AudioEngine()
        XCTAssertNotNil(engine)
        XCTAssertFalse(engine.isCapturing)
    }
}
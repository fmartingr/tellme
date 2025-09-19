import XCTest
@testable import TellMeAudio

final class AudioEngineTests: XCTestCase {
    func testAudioEngineInitialization() {
        let engine = AudioEngine()
        XCTAssertNotNil(engine)
        XCTAssertFalse(engine.isCapturing)
    }
}
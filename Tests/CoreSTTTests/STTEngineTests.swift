import XCTest
@testable import CoreSTT

final class STTEngineTests: XCTestCase {
    func testWhisperCPPEngineInitialization() {
        let engine = WhisperCPPEngine()
        XCTAssertNotNil(engine)
        XCTAssertFalse(engine.isModelLoaded())
    }
}
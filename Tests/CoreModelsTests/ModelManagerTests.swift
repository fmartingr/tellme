import XCTest
@testable import CoreModels

final class ModelManagerTests: XCTestCase {
    func testModelManagerInitialization() {
        let manager = ModelManager()
        XCTAssertNotNil(manager)
        XCTAssertEqual(manager.availableModels.count, 0)
    }
}
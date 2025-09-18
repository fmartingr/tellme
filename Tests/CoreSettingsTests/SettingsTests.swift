import XCTest
@testable import CoreSettings

final class SettingsTests: XCTestCase {
    func testSettingsInitialization() {
        let settings = Settings()
        XCTAssertNotNil(settings)
        XCTAssertEqual(settings.hotkeyMode, .pushToTalk)
    }
}
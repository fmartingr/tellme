import XCTest
@testable import CorePermissions

final class PermissionManagerTests: XCTestCase {
    func testPermissionManagerInitialization() {
        let manager = PermissionManager()
        XCTAssertNotNil(manager)
    }
}
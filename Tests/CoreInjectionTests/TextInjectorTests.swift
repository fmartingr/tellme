import XCTest
@testable import CoreInjection

final class TextInjectorTests: XCTestCase {
    func testTextInjectorInitialization() {
        let injector = TextInjector()
        XCTAssertNotNil(injector)
    }
}
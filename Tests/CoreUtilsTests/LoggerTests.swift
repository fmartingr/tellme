import XCTest
@testable import CoreUtils

final class LoggerTests: XCTestCase {
    func testLoggerInitialization() {
        let logger = Logger(category: "Test")
        logger.info("Test message")
    }

    func testLoggerLevels() {
        let logger = Logger(category: "Test")
        logger.debug("Debug message")
        logger.info("Info message")
        logger.warning("Warning message")
        logger.error("Error message")
    }
}
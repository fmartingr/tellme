import Foundation
import AppKit
import CoreUtils

public enum InjectionMethod {
    case paste
    case typing
}

public enum InjectionError: Error, LocalizedError {
    case secureInputActive
    case accessibilityPermissionRequired
    case injectionFailed(String)

    public var errorDescription: String? {
        switch self {
        case .secureInputActive:
            return NSLocalizedString("preferences.insertion.secure_input.message", comment: "Secure input message")
        case .accessibilityPermissionRequired:
            return NSLocalizedString("permissions.accessibility.message", comment: "Accessibility permission message")
        case .injectionFailed(let reason):
            return "Text injection failed: \(reason)"
        }
    }
}

public class TextInjector {
    private let logger = Logger(category: "TextInjector")

    public init() {}

    public func injectText(_ text: String, method: InjectionMethod = .paste) throws {
        logger.info("Injecting text using method: \(method)")

        // Check for secure input first
        if isSecureInputActive() {
            // Copy to clipboard but don't inject
            copyToClipboard(text)
            throw InjectionError.secureInputActive
        }

        switch method {
        case .paste:
            try injectViaPaste(text)
        case .typing:
            try injectViaTyping(text)
        }
    }

    private func injectViaPaste(_ text: String) throws {
        logger.debug("Injecting text via paste method")
        // TODO: Implement paste injection (clipboard + ⌘V) in Phase 3
        copyToClipboard(text)
        // TODO: Send ⌘V via CGEvent
    }

    private func injectViaTyping(_ text: String) throws {
        logger.debug("Injecting text via typing method")
        // TODO: Implement character-by-character typing via CGEvent in Phase 3
    }

    private func copyToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        logger.debug("Text copied to clipboard")
    }

    private func isSecureInputActive() -> Bool {
        // TODO: Implement IsSecureEventInputEnabled() check in Phase 3
        return false
    }
}
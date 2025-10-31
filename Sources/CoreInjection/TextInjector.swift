import Foundation
import AppKit
import Carbon
import CoreUtils
import CorePermissions

public enum InjectionMethod: String, CaseIterable {
    case paste = "paste"
    case typing = "typing"

    public var displayName: String {
        switch self {
        case .paste:
            return L("preferences.insertion.method.paste")
        case .typing:
            return L("preferences.insertion.method.typing")
        }
    }
}

public enum InjectionError: Error, LocalizedError {
    case secureInputActive
    case accessibilityPermissionRequired
    case injectionFailed(String)

    public var errorDescription: String? {
        switch self {
        case .secureInputActive:
            return L("preferences.insertion.secure_input.message")
        case .accessibilityPermissionRequired:
            return L("permissions.accessibility.message")
        case .injectionFailed(let reason):
            return "Text injection failed: \(reason)"
        }
    }
}

public class TextInjector {
    private let logger = Logger(category: "TextInjector")
    private let permissionManager: PermissionManager

    public init(permissionManager: PermissionManager? = nil) {
        self.permissionManager = permissionManager ?? PermissionManager()
    }

    public func injectText(_ text: String, method: InjectionMethod = .paste, enableFallback: Bool = true) throws {
        logger.info("Injecting text using method: \(method), fallback enabled: \(enableFallback)")

        // Check permissions required for text injection
        try checkRequiredPermissions()

        // Check for secure input first
        if isSecureInputActive() {
            // Copy to clipboard but don't inject
            copyToClipboard(text)
            throw InjectionError.secureInputActive
        }

        do {
            try attemptInjection(text: text, method: method)
        } catch {
            if enableFallback {
                let fallbackMethod: InjectionMethod = method == .paste ? .typing : .paste
                logger.warning("Primary injection method failed, trying fallback: \(fallbackMethod)")
                try attemptInjection(text: text, method: fallbackMethod)
            } else {
                throw error
            }
        }
    }

    private func checkRequiredPermissions() throws {
        // Refresh permission status first
        permissionManager.checkAllPermissions()

        logger.info("Permission status - Accessibility: \(permissionManager.accessibilityStatus), Input Monitoring: \(permissionManager.inputMonitoringStatus)")

        // Check accessibility permission (required for text injection)
        if permissionManager.accessibilityStatus != .granted {
            logger.error("Accessibility permission not granted: \(permissionManager.accessibilityStatus)")
            throw InjectionError.accessibilityPermissionRequired
        }

        // Check input monitoring permission (required for CGEvent creation)
        if permissionManager.inputMonitoringStatus != .granted {
            logger.error("Input monitoring permission not granted: \(permissionManager.inputMonitoringStatus)")
            throw InjectionError.accessibilityPermissionRequired // Using same error for simplicity
        }

        logger.info("All permissions granted for text injection")
    }

    private func attemptInjection(text: String, method: InjectionMethod) throws {
        switch method {
        case .paste:
            try injectViaPaste(text)
        case .typing:
            try injectViaTyping(text)
        }
    }

    private func injectViaPaste(_ text: String) throws {
        logger.debug("Injecting text via paste method")

        // First copy text to clipboard
        copyToClipboard(text)

        // Small delay to ensure clipboard is updated
        Thread.sleep(forTimeInterval: 0.05)

        // Send ⌘V via CGEvent
        try sendCommandV()
    }

    private func sendCommandV() throws {
        logger.debug("Sending ⌘V keyboard event")

        // Create ⌘V key combination
        let cmdDownEvent = CGEvent(keyboardEventSource: nil, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: true)
        let cmdUpEvent = CGEvent(keyboardEventSource: nil, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: false)

        guard let cmdDown = cmdDownEvent, let cmdUp = cmdUpEvent else {
            logger.error("Failed to create CGEvent objects for ⌘V")
            throw InjectionError.injectionFailed("Failed to create CGEvent for ⌘V")
        }

        // Set command modifier for both events
        cmdDown.flags = .maskCommand
        cmdUp.flags = .maskCommand

        logger.debug("Created ⌘V events, posting to system...")

        // Post the events
        cmdDown.post(tap: .cghidEventTap)
        cmdUp.post(tap: .cghidEventTap)

        logger.info("⌘V events posted successfully")
    }

    private func injectViaTyping(_ text: String) throws {
        logger.debug("Injecting text via typing method")

        for character in text {
            try typeCharacter(character)
            // Small delay between characters to avoid overwhelming the target app
            Thread.sleep(forTimeInterval: 0.01)
        }

        logger.debug("Typing injection completed")
    }

    private func typeCharacter(_ character: Character) throws {
        let string = String(character)

        // Handle common special characters
        switch character {
        case "\n":
            try postKeyEvent(keyCode: CGKeyCode(kVK_Return))
        case "\t":
            try postKeyEvent(keyCode: CGKeyCode(kVK_Tab))
        case " ":
            try postKeyEvent(keyCode: CGKeyCode(kVK_Space))
        default:
            // Use CGEvent string posting for regular characters
            // This respects the current keyboard layout
            let keyDownEvent = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: true)
            let keyUpEvent = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: false)

            guard let keyDown = keyDownEvent, let keyUp = keyUpEvent else {
                throw InjectionError.injectionFailed("Failed to create CGEvent for character: \(character)")
            }

            // Set the Unicode string for the character
            let unicodeChars = string.unicodeScalars.map { UniChar($0.value) }
            keyDown.keyboardSetUnicodeString(stringLength: string.count, unicodeString: unicodeChars)
            keyUp.keyboardSetUnicodeString(stringLength: string.count, unicodeString: unicodeChars)

            // Post the events
            keyDown.post(tap: .cghidEventTap)
            keyUp.post(tap: .cghidEventTap)
        }
    }

    private func postKeyEvent(keyCode: CGKeyCode) throws {
        let keyDownEvent = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: true)
        let keyUpEvent = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: false)

        guard let keyDown = keyDownEvent, let keyUp = keyUpEvent else {
            throw InjectionError.injectionFailed("Failed to create CGEvent for key code: \(keyCode)")
        }

        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
    }

    private func copyToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        let success = pasteboard.setString(text, forType: .string)

        if success {
            logger.info("Text copied to clipboard: \"\(text)\"")
        } else {
            logger.error("Failed to copy text to clipboard")
        }
    }

    private func isSecureInputActive() -> Bool {
        let isSecure = IsSecureEventInputEnabled()
        if isSecure {
            logger.warning("Secure input is active - text injection will be blocked")
        }
        return isSecure
    }
}
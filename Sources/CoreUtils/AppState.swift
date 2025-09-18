import Foundation

public enum AppState: String, CaseIterable {
    case idle = "idle"
    case listening = "listening"
    case processing = "processing"
    case injecting = "injecting"
    case error = "error"

    public var displayName: String {
        switch self {
        case .idle:
            return NSLocalizedString("menubar.idle", comment: "Idle state")
        case .listening:
            return NSLocalizedString("menubar.listening", comment: "Listening state")
        case .processing:
            return NSLocalizedString("menubar.processing", comment: "Processing state")
        case .injecting:
            return "Injecting" // Not shown in menu bar
        case .error:
            return "Error" // Not shown in menu bar
        }
    }
}
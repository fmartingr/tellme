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
            return L("menubar.idle")
        case .listening:
            return L("menubar.listening")
        case .processing:
            return L("menubar.processing")
        case .injecting:
            return "Injecting" // Not shown in menu bar
        case .error:
            return "Error" // Not shown in menu bar
        }
    }
}
import Foundation
import AVFoundation
import AppKit
import CoreUtils

public enum PermissionType: CaseIterable {
    case microphone
    case accessibility
    case inputMonitoring
}

public enum PermissionStatus {
    case notDetermined
    case granted
    case denied
    case restricted
}

public class PermissionManager: ObservableObject {
    private let logger = Logger(category: "PermissionManager")

    @Published public private(set) var microphoneStatus: PermissionStatus = .notDetermined
    @Published public private(set) var accessibilityStatus: PermissionStatus = .notDetermined
    @Published public private(set) var inputMonitoringStatus: PermissionStatus = .notDetermined

    public init() {
        refreshAllPermissions()
    }

    public func requestMicrophonePermission() async -> PermissionStatus {
        logger.info("Requesting microphone permission")

        return await withCheckedContinuation { continuation in
            switch AVCaptureDevice.authorizationStatus(for: .audio) {
            case .authorized:
                continuation.resume(returning: .granted)
            case .denied, .restricted:
                continuation.resume(returning: .denied)
            case .notDetermined:
                AVCaptureDevice.requestAccess(for: .audio) { granted in
                    let status: PermissionStatus = granted ? .granted : .denied
                    Task { @MainActor in
                        self.microphoneStatus = status
                    }
                    continuation.resume(returning: status)
                }
            @unknown default:
                continuation.resume(returning: .notDetermined)
            }
        }
    }

    public func requestAccessibilityPermission() {
        logger.info("Requesting accessibility permission")
        // TODO: Implement accessibility permission request in Phase 1
        // This typically involves guiding the user to System Settings
    }

    public func requestInputMonitoringPermission() {
        logger.info("Requesting input monitoring permission")
        // TODO: Implement input monitoring permission request in Phase 1
        // This typically involves guiding the user to System Settings
    }

    public func openSystemSettings(for permission: PermissionType) {
        logger.info("Opening system settings for permission: \(permission)")

        let urlString: String
        switch permission {
        case .microphone:
            urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone"
        case .accessibility:
            urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        case .inputMonitoring:
            urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent"
        }

        if let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        }
    }

    private func refreshAllPermissions() {
        refreshMicrophonePermission()
        refreshAccessibilityPermission()
        refreshInputMonitoringPermission()
    }

    private func refreshMicrophonePermission() {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .notDetermined:
            microphoneStatus = .notDetermined
        case .authorized:
            microphoneStatus = .granted
        case .denied, .restricted:
            microphoneStatus = .denied
        @unknown default:
            microphoneStatus = .notDetermined
        }
    }

    private func refreshAccessibilityPermission() {
        // TODO: Implement accessibility permission check in Phase 1
        accessibilityStatus = .notDetermined
    }

    private func refreshInputMonitoringPermission() {
        // TODO: Implement input monitoring permission check in Phase 1
        inputMonitoringStatus = .notDetermined
    }
}
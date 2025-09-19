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

    public func requestMicrophonePermission(completion: @escaping (PermissionStatus) -> Void) {
        logger.info("Requesting microphone permission")

        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            completion(.granted)
        case .denied, .restricted:
            completion(.denied)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                let status: PermissionStatus = granted ? .granted : .denied
                Task { @MainActor in
                    self.microphoneStatus = status
                }
                completion(status)
            }
        @unknown default:
            completion(.notDetermined)
        }
    }

    public func requestAccessibilityPermission() {
        logger.info("Requesting accessibility permission")

        if !AXIsProcessTrusted() {
            logger.info("Accessibility permission not granted, opening System Settings")
            openSystemSettings(for: .accessibility)
        } else {
            logger.info("Accessibility permission already granted")
            accessibilityStatus = .granted
        }
    }

    public func requestInputMonitoringPermission() {
        logger.info("Requesting input monitoring permission")

        // For input monitoring, we can try to detect it by attempting to create a CGEvent
        // If it fails, we likely need permission
        let testEvent = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: true)

        if testEvent == nil {
            logger.info("Input monitoring permission likely not granted, opening System Settings")
            openSystemSettings(for: .inputMonitoring)
        } else {
            logger.info("Input monitoring permission appears to be granted")
            inputMonitoringStatus = .granted
        }
    }

    public func checkAllPermissions() {
        logger.info("Checking all permissions")
        refreshAllPermissions()
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
        if AXIsProcessTrusted() {
            accessibilityStatus = .granted
        } else {
            accessibilityStatus = .denied
        }
    }

    private func refreshInputMonitoringPermission() {
        // Test if we can create CGEvents (requires Input Monitoring permission)
        let testEvent = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: true)

        if testEvent != nil {
            inputMonitoringStatus = .granted
            logger.debug("Input monitoring permission appears to be granted")
        } else {
            inputMonitoringStatus = .denied
            logger.warning("Input monitoring permission appears to be denied")
        }
    }
}
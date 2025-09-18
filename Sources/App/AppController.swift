import SwiftUI
import CoreUtils
import MenuWhisperAudio
import CorePermissions
import AVFoundation

public class AppController: ObservableObject {
    private let logger = Logger(category: "AppController")

    // Core components
    private let hotkeyManager = HotkeyManager()
    private let audioEngine = AudioEngine()
    private let permissionManager = PermissionManager()
    private let soundManager = SoundManager()

    // UI components
    private var hudWindow: HUDWindow?

    // State management
    @Published public private(set) var currentState: AppState = .idle
    @Published public var isToggleListening = false

    // Dictation timer
    private var dictationTimer: Timer?
    private let maxDictationDuration: TimeInterval = 600 // 10 minutes default

    public init() {
        setupDelegates()
        setupNotifications()
    }

    deinit {
        cleanup()
    }

    public func start() {
        logger.info("Starting app controller")

        // Check microphone permission first
        checkMicrophonePermission { [weak self] granted in
            if granted {
                self?.setupHotkey()
            } else {
                self?.logger.warning("Microphone permission not granted")
            }
        }
    }

    private func setupDelegates() {
        hotkeyManager.delegate = self
        audioEngine.delegate = self
    }

    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleHUDEscape),
            name: .hudEscapePressed,
            object: nil
        )
    }

    private func setupHotkey() {
        hotkeyManager.enableHotkey()
    }

    private func checkMicrophonePermission(completion: @escaping (Bool) -> Void) {
        permissionManager.requestMicrophonePermission { status in
            DispatchQueue.main.async {
                completion(status == .granted)
            }
        }
    }

    @objc private func handleHUDEscape() {
        logger.info("HUD escape pressed - cancelling dictation")
        cancelDictation()
    }

    private func startListening() {
        guard currentState == .idle else {
            logger.warning("Cannot start listening from state: \(currentState)")
            return
        }

        logger.info("Starting listening")
        currentState = .listening

        do {
            try audioEngine.startCapture()
            showHUD(state: .listening(level: 0))
            startDictationTimer()
            soundManager.playStartSound()
        } catch {
            logger.error("Failed to start audio capture: \(error)")
            currentState = .error
            soundManager.playErrorSound()
            showError("Failed to start microphone: \(error.localizedDescription)")
        }
    }

    private func stopListening() {
        guard currentState == .listening else {
            logger.warning("Cannot stop listening from state: \(currentState)")
            return
        }

        logger.info("Stopping listening")
        stopDictationTimer()
        audioEngine.stopCapture()
        soundManager.playStopSound()

        // Transition to processing state
        currentState = .processing
        showHUD(state: .processing)

        // For Phase 1, we'll just simulate processing and return to idle
        // In Phase 2, this is where we'd call the STT engine
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.finishProcessing()
        }
    }

    private func finishProcessing() {
        logger.info("Finishing processing")
        currentState = .idle
        hideHUD()

        // Reset toggle state if in toggle mode
        if hotkeyManager.currentMode == .toggle {
            isToggleListening = false
        }
    }

    private func cancelDictation() {
        logger.info("Cancelling dictation")
        stopDictationTimer()

        if audioEngine.isCapturing {
            audioEngine.stopCapture()
        }

        currentState = .idle
        hideHUD()

        // Reset toggle state
        if hotkeyManager.currentMode == .toggle {
            isToggleListening = false
        }
    }

    private func startDictationTimer() {
        stopDictationTimer() // Clean up any existing timer

        dictationTimer = Timer.scheduledTimer(withTimeInterval: maxDictationDuration, repeats: false) { [weak self] _ in
            self?.logger.info("Dictation timeout reached")
            self?.stopListening()
        }
    }

    private func stopDictationTimer() {
        dictationTimer?.invalidate()
        dictationTimer = nil
    }

    private func showHUD(state: HUDState) {
        if hudWindow == nil {
            hudWindow = HUDWindow()
        }
        hudWindow?.show(state: state)
    }

    private func hideHUD() {
        hudWindow?.hide()
    }

    private func showError(_ message: String) {
        logger.error("Error: \(message)")
        // TODO: Show error dialog in a later phase
        currentState = .idle
    }

    private func cleanup() {
        stopDictationTimer()
        audioEngine.stopCapture()
        hotkeyManager.disableHotkey()
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - HotkeyManagerDelegate
extension AppController: HotkeyManagerDelegate {
    public func hotkeyPressed(mode: HotkeyMode, isKeyDown: Bool) {
        logger.debug("Hotkey pressed: mode=\(mode), isKeyDown=\(isKeyDown)")

        switch mode {
        case .pushToTalk:
            if isKeyDown {
                startListening()
            } else {
                if currentState == .listening {
                    stopListening()
                }
            }

        case .toggle:
            if isKeyDown { // Only respond to key down in toggle mode
                if currentState == .idle && !isToggleListening {
                    isToggleListening = true
                    startListening()
                } else if currentState == .listening && isToggleListening {
                    isToggleListening = false
                    stopListening()
                }
            }
        }
    }
}

// MARK: - AudioEngineDelegate
extension AppController: AudioEngineDelegate {
    public func audioEngine(_ engine: AudioEngine, didUpdateLevel level: Float) {
        // Update HUD with new level
        hudWindow?.updateLevel(level)
    }

    public func audioEngine(_ engine: AudioEngine, didCaptureAudio data: Data) {
        logger.info("Audio capture completed: \(data.count) bytes")
        // In Phase 2, this is where we'd send the data to STT
    }

    public func audioEngineDidStartCapture(_ engine: AudioEngine) {
        logger.info("Audio engine started capture")
    }

    public func audioEngineDidStopCapture(_ engine: AudioEngine) {
        logger.info("Audio engine stopped capture")
    }
}
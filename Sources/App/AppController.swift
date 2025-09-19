import SwiftUI
import CoreUtils
import MenuWhisperAudio
import CorePermissions
import CoreSTT
import CoreModels
import AVFoundation

public class AppController: ObservableObject {
    private let logger = Logger(category: "AppController")

    // Core components
    private let hotkeyManager = HotkeyManager()
    private let audioEngine = AudioEngine()
    private let permissionManager = PermissionManager()
    private let soundManager = SoundManager()

    // STT components
    public let whisperEngine = WhisperCPPEngine(numThreads: 4, useGPU: true)
    public var modelManager: ModelManager!

    // UI components
    private var hudWindow: HUDWindow?
    private var preferencesWindow: PreferencesWindowController?
    private var statusItem: NSStatusItem?

    // State management
    @Published public private(set) var currentState: AppState = .idle
    @Published public var isToggleListening = false

    // Dictation timer
    private var dictationTimer: Timer?
    private let maxDictationDuration: TimeInterval = 600 // 10 minutes default

    public init() {
        setupDelegates()
        setupNotifications()
        setupSTTComponents()
    }

    private func setupSTTComponents() {
        // Initialize ModelManager - don't auto-load models
        Task { @MainActor in
            self.modelManager = ModelManager()

            // Try to load previously selected model (if any)
            self.loadUserSelectedModel()
        }
    }

    private func loadUserSelectedModel() {
        Task {
            guard let modelManager = self.modelManager else {
                return
            }

            // Check if user has a previously selected model that's downloaded
            if let activeModel = await modelManager.activeModel,
               let modelPath = await modelManager.getModelPath(for: activeModel),
               FileManager.default.fileExists(atPath: modelPath.path) {

                do {
                    try await whisperEngine.loadModel(at: modelPath)
                    logger.info("Loaded user's selected model: \(activeModel.name)")

                    await MainActor.run {
                        updateMenuModelStatus()
                    }
                } catch {
                    logger.error("Failed to load selected model: \(error)")
                }
            } else {
                logger.info("No valid model selected - user needs to download and select a model")
                await MainActor.run {
                    updateMenuModelStatus()
                }
            }
        }
    }


    deinit {
        cleanup()
    }

    public func start() {
        logger.info("Starting app controller")

        // Setup status item menu on main actor
        Task { @MainActor in
            setupStatusItemMenu()
        }

        // Check microphone permission first
        checkMicrophonePermission { [weak self] granted in
            if granted {
                self?.setupHotkey()
            } else {
                self?.logger.warning("Microphone permission not granted")
            }
        }
    }

    @MainActor
    private func setupStatusItemMenu() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem?.button?.image = NSImage(systemSymbolName: "mic", accessibilityDescription: "MenuWhisper")
        statusItem?.button?.imagePosition = .imageOnly

        let menu = NSMenu()

        // Status item
        let statusMenuItem = NSMenuItem()
        statusMenuItem.title = "MenuWhisper"
        statusMenuItem.isEnabled = false
        menu.addItem(statusMenuItem)

        menu.addItem(NSMenuItem.separator())

        // Model status
        let modelMenuItem = NSMenuItem()
        modelMenuItem.title = "Loading model..."
        modelMenuItem.isEnabled = false
        menu.addItem(modelMenuItem)

        menu.addItem(NSMenuItem.separator())

        // Preferences
        let preferencesMenuItem = NSMenuItem(title: "Preferences...", action: #selector(openPreferences), keyEquivalent: ",")
        preferencesMenuItem.target = self
        menu.addItem(preferencesMenuItem)

        // Test item - add direct preferences shortcut
        let testPrefsMenuItem = NSMenuItem(title: "Open Preferences (⇧⌘P)", action: #selector(openPreferences), keyEquivalent: "P")
        testPrefsMenuItem.keyEquivalentModifierMask = [.shift, .command]
        testPrefsMenuItem.target = self
        menu.addItem(testPrefsMenuItem)

        // Quit
        let quitMenuItem = NSMenuItem(title: "Quit MenuWhisper", action: #selector(quitApp), keyEquivalent: "q")
        quitMenuItem.target = self
        menu.addItem(quitMenuItem)

        statusItem?.menu = menu

        // Update model status periodically
        updateMenuModelStatus()
    }

    @objc private func openPreferences() {
        Task { @MainActor in
            showPreferences()
        }
    }

    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }

    @MainActor
    private func updateMenuModelStatus() {
        guard let menu = statusItem?.menu,
              menu.items.count > 3 else { return }

        let modelMenuItem = menu.items[2] // Model status item

        if let activeModel = modelManager?.activeModel, whisperEngine.isModelLoaded() {
            modelMenuItem.title = "Model: \(activeModel.name)"
        } else if modelManager?.activeModel != nil {
            modelMenuItem.title = "Model: Loading..."
        } else {
            modelMenuItem.title = "No model - click Preferences"
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

        // Check if a model is loaded before starting
        guard whisperEngine.isModelLoaded() else {
            logger.warning("No model loaded - showing setup alert")
            Task { @MainActor in
                showModelSetupAlert()
            }
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

        // The audio will be processed in the AudioEngine delegate when capture completes
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

    private func performTranscription(audioData: Data) {
        logger.info("Starting STT transcription for \(audioData.count) bytes")

        Task {
            do {
                guard whisperEngine.isModelLoaded() else {
                    logger.error("No model loaded for transcription")
                    await showTranscriptionError("No speech recognition model loaded")
                    return
                }

                let startTime = Date()
                let transcription = try await whisperEngine.transcribe(audioData: audioData, language: "auto")
                let duration = Date().timeIntervalSince(startTime)

                logger.info("Transcription completed in \(String(format: "%.2f", duration))s: \"\(transcription)\"")

                // For now, just print the result - in Phase 3 we'll inject it
                await MainActor.run {
                    print("🎤 TRANSCRIPTION RESULT: \(transcription)")
                    showTranscriptionResult(transcription)
                }

            } catch {
                logger.error("Transcription failed: \(error)")
                await showTranscriptionError("Speech recognition failed: \(error.localizedDescription)")
            }
        }
    }

    @MainActor
    private func showTranscriptionResult(_ text: String) {
        // For Phase 2, we'll just show it in logs and console
        // In Phase 3, this will inject the text into the active app
        logger.info("Transcription result: \(text)")
        finishProcessing()
    }

    @MainActor
    private func showTranscriptionError(_ message: String) {
        logger.error("Transcription error: \(message)")
        currentState = .error
        showError(message)

        // Return to idle after showing error
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.currentState = .idle
            self.hideHUD()
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

    @MainActor
    public func showPreferences() {
        guard let modelManager = modelManager else {
            logger.error("ModelManager not initialized yet")
            return
        }

        if preferencesWindow == nil {
            preferencesWindow = PreferencesWindowController(
                modelManager: modelManager,
                whisperEngine: whisperEngine
            )
        }

        preferencesWindow?.showWindow(nil)
        preferencesWindow?.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @MainActor
    private func showModelSetupAlert() {
        let alert = NSAlert()
        alert.messageText = "No Speech Recognition Model"
        alert.informativeText = "You need to download and select a speech recognition model before using MenuWhisper.\n\nWould you like to open Preferences to download a model?"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Open Preferences")
        alert.addButton(withTitle: "Cancel")

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            showPreferences()
        }
    }


    private func cleanup() {
        stopDictationTimer()
        audioEngine.stopCapture()
        hotkeyManager.disableHotkey()
        preferencesWindow?.close()
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

        // Only process if we're in the processing state
        guard currentState == .processing else {
            logger.warning("Ignoring audio data - not in processing state")
            return
        }

        // Perform STT transcription
        performTranscription(audioData: data)
    }

    public func audioEngineDidStartCapture(_ engine: AudioEngine) {
        logger.info("Audio engine started capture")
    }

    public func audioEngineDidStopCapture(_ engine: AudioEngine) {
        logger.info("Audio engine stopped capture")
    }
}
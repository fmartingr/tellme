import SwiftUI
import CoreUtils
import TellMeAudio
import CorePermissions
import CoreSTT
import CoreModels
import CoreInjection
import CoreSettings
import AVFoundation

public class AppController: ObservableObject {
    private let logger = Logger(category: "AppController")

    // Core components
    private let hotkeyManager = HotkeyManager()
    private let audioEngine = AudioEngine()
    private let permissionManager = PermissionManager()
    private let soundManager: SoundManager
    private let textInjector: TextInjector

    // Settings
    public let settings = Settings()

    // STT components
    public let whisperEngine: WhisperCPPEngine
    public var modelManager: ModelManager!

    // UI components
    private var hudWindow: HUDWindow?
    private var preferencesWindow: PreferencesWindowController?
    private var onboardingWindow: OnboardingWindowController?
    private var helpWindow: HelpWindowController?
    private var statusItem: NSStatusItem?

    // State management
    @Published public private(set) var currentState: AppState = .idle
    @Published public var isToggleListening = false

    // Dictation timer
    private var dictationTimer: Timer?

    public init() {
        whisperEngine = WhisperCPPEngine(
            numThreads: settings.processingThreads,
            useGPU: true
        )
        soundManager = SoundManager(settings: settings)
        textInjector = TextInjector(permissionManager: permissionManager)
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

        // Debug: Check localization
        let testString = NSLocalizedString("preferences.title", comment: "Test")
        logger.info("Localization test - preferences.title: '\(testString)'")

        // Setup status item menu on main actor
        Task { @MainActor in
            setupStatusItemMenu()
        }

        // Check all required permissions on startup
        checkAllPermissionsOnStartup()

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
        statusItem?.button?.image = NSImage(systemSymbolName: "mic", accessibilityDescription: "Tell me")
        statusItem?.button?.imagePosition = .imageOnly

        let menu = NSMenu()

        // Status item
        let statusMenuItem = NSMenuItem()
        statusMenuItem.title = NSLocalizedString("app.name", comment: "App name")
        statusMenuItem.isEnabled = false
        menu.addItem(statusMenuItem)

        menu.addItem(NSMenuItem.separator())

        // Model status
        let modelMenuItem = NSMenuItem()
        modelMenuItem.title = NSLocalizedString("menubar.loading_model", comment: "Loading model...")
        modelMenuItem.isEnabled = false
        menu.addItem(modelMenuItem)

        menu.addItem(NSMenuItem.separator())

        // Preferences
        let preferencesMenuItem = NSMenuItem(title: NSLocalizedString("menubar.preferences", comment: "Preferences..."), action: #selector(openPreferences), keyEquivalent: ",")
        preferencesMenuItem.target = self
        menu.addItem(preferencesMenuItem)

        // Help
        let helpMenuItem = NSMenuItem(title: NSLocalizedString("menubar.help", comment: "Help"), action: #selector(openHelp), keyEquivalent: "?")
        helpMenuItem.target = self
        menu.addItem(helpMenuItem)

        // Debug: Reset Onboarding (only in development)
        #if DEBUG
        let resetOnboardingMenuItem = NSMenuItem(title: NSLocalizedString("menubar.reset_onboarding", comment: "Reset Onboarding"), action: #selector(resetOnboarding), keyEquivalent: "")
        resetOnboardingMenuItem.target = self
        menu.addItem(resetOnboardingMenuItem)
        #endif

        menu.addItem(NSMenuItem.separator())

        // Quit
        let quitMenuItem = NSMenuItem(title: NSLocalizedString("menubar.quit", comment: "Quit Tell me"), action: #selector(quitApp), keyEquivalent: "q")
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

    @objc private func openHelp() {
        Task { @MainActor in
            showHelp()
        }
    }

    #if DEBUG
    @objc private func resetOnboarding() {
        UserDefaults.standard.removeObject(forKey: "hasShownPermissionOnboarding")
        logger.info("Onboarding status reset - will show on next startup or permission check")

        // Optionally show onboarding immediately
        Task { @MainActor in
            showPermissionOnboarding()
        }
    }
    #endif

    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }

    @MainActor
    private func updateMenuModelStatus() {
        guard let menu = statusItem?.menu,
              menu.items.count > 3 else { return }

        let modelMenuItem = menu.items[2] // Model status item

        if let activeModel = modelManager?.activeModel, whisperEngine.isModelLoaded() {
            modelMenuItem.title = String(format: NSLocalizedString("menubar.model_status", comment: "Model status"), activeModel.name)
        } else if modelManager?.activeModel != nil {
            modelMenuItem.title = NSLocalizedString("menubar.model_loading", comment: "Model loading")
        } else {
            modelMenuItem.title = NSLocalizedString("menubar.no_model", comment: "No model")
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

    private func checkAllPermissionsOnStartup() {
        logger.info("Checking all permissions on startup")

        // Check all permissions and log their status
        permissionManager.checkAllPermissions()

        // Log permission status
        logger.info("Permission status: Microphone=\(permissionManager.microphoneStatus), Accessibility=\(permissionManager.accessibilityStatus), InputMonitoring=\(permissionManager.inputMonitoringStatus)")

        // Check if we need to show permission onboarding for first-time users
        if shouldShowPermissionOnboarding() {
            Task { @MainActor in
                showPermissionOnboarding()
            }
        }
    }


    private func shouldShowPermissionOnboarding() -> Bool {
        // Don't show again if user already dismissed it
        if UserDefaults.standard.bool(forKey: "hasShownPermissionOnboarding") {
            return false
        }

        // Show onboarding if any critical permissions are not granted
        return permissionManager.accessibilityStatus != .granted ||
               permissionManager.inputMonitoringStatus != .granted
    }

    @MainActor
    private func showPermissionOnboarding() {
        guard let modelManager = modelManager else {
            logger.error("ModelManager not initialized for onboarding")
            return
        }

        onboardingWindow = OnboardingWindowController(
            permissionManager: permissionManager,
            modelManager: modelManager,
            whisperEngine: whisperEngine,
            onComplete: { [weak self] in
                // Mark that we've shown the onboarding
                UserDefaults.standard.set(true, forKey: "hasShownPermissionOnboarding")

                // Clear the reference after a brief delay to allow window to close
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self?.onboardingWindow = nil
                }
            }
        )
        onboardingWindow?.showWindow(nil)
        onboardingWindow?.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
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

    private func checkAllRequiredPermissions() -> Bool {
        // Refresh permission status first (they might have been granted since startup)
        permissionManager.checkAllPermissions()

        // Check microphone permission (critical for audio capture)
        if permissionManager.microphoneStatus != .granted {
            logger.warning("Microphone permission not granted")
            Task { @MainActor in
                showMicrophonePermissionAlert()
            }
            return false
        }

        // Check accessibility permission (required for text insertion)
        if permissionManager.accessibilityStatus != .granted {
            logger.warning("Accessibility permission not granted")
            Task { @MainActor in
                showAccessibilityPermissionAlert()
            }
            return false
        }

        // Input monitoring (required for hotkeys and text insertion)
        if permissionManager.inputMonitoringStatus != .granted {
            logger.warning("Input monitoring permission not granted")
            Task { @MainActor in
                showInputMonitoringPermissionAlert()
            }
            return false
        }

        logger.info("All required permissions granted")
        return true
    }

    private func startListening() {
        guard currentState == .idle else {
            logger.warning("Cannot start listening from state: \(currentState)")
            return
        }

        // Check all required permissions before starting
        let allPermissionsGranted = checkAllRequiredPermissions()
        guard allPermissionsGranted else {
            return // Permission alerts will be shown by checkAllRequiredPermissions
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
                let transcription = try await whisperEngine.transcribe(audioData: audioData, language: settings.forcedLanguage ?? "auto")
                let duration = Date().timeIntervalSince(startTime)

                logger.info("Transcription completed in \(String(format: "%.2f", duration))s: \"\(transcription)\"")

                // Inject the transcribed text
                await MainActor.run {
                    injectTranscriptionResult(transcription)
                }

            } catch {
                logger.error("Transcription failed: \(error)")
                await showTranscriptionError("Speech recognition failed: \(error.localizedDescription)")
            }
        }
    }

    @MainActor
    private func injectTranscriptionResult(_ text: String) {
        logger.info("Attempting to inject transcription result: \(text)")

        // Check if preview is enabled
        if settings.showPreview {
            showPreviewDialog(text: text)
        } else {
            performTextInjection(text)
        }
    }

    @MainActor
    private func showPreviewDialog(text: String) {
        let previewDialog = PreviewDialogController(
            text: text,
            onInsert: { [weak self] editedText in
                self?.performTextInjection(editedText)
            },
            onCancel: { [weak self] in
                self?.finishProcessing()
            }
        )
        previewDialog.showWindow(nil)
    }

    @MainActor
    private func performTextInjection(_ text: String) {
        do {
            // Determine injection method from settings
            let injectionMethod: InjectionMethod = settings.insertionMethod == .paste ? .paste : .typing

            // Attempt to inject the text using the configured method
            try textInjector.injectText(text, method: injectionMethod, enableFallback: true)
            logger.info("Text injection successful using \(injectionMethod) method")

            // Show success and finish processing
            finishProcessing()

        } catch InjectionError.secureInputActive {
            logger.warning("Secure input active - text copied to clipboard")
            showSecureInputNotice(text)
            finishProcessing()

        } catch InjectionError.accessibilityPermissionRequired {
            logger.error("Accessibility permission required for text injection")
            showPermissionRequiredNotice()
            finishProcessing()

        } catch {
            logger.error("Text injection failed: \(error)")
            showInjectionError(error.localizedDescription)
            finishProcessing()
        }
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

        dictationTimer = Timer.scheduledTimer(withTimeInterval: settings.dictationTimeLimit, repeats: false) { [weak self] _ in
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
            hudWindow = HUDWindow(settings: settings)
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
    private func showSecureInputNotice(_ text: String) {
        let alert = NSAlert()
        alert.messageText = "Secure Input Active"
        alert.informativeText = "Text injection is blocked because secure input is active (likely in a password field or secure app).\n\nThe transcribed text has been copied to your clipboard instead: \"\(text)\""
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    @MainActor
    private func showPermissionRequiredNotice() {
        let alert = NSAlert()
        alert.messageText = "Permission Required"
        alert.informativeText = "Tell me needs Accessibility and Input Monitoring permissions to insert text into other applications.\n\nWould you like to open System Settings to grant these permissions?"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Cancel")

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            showPreferences(initialTab: 1) // Open Permissions tab
        }
    }

    @MainActor
    private func showInjectionError(_ message: String) {
        let alert = NSAlert()
        alert.messageText = "Text Injection Failed"
        alert.informativeText = "Failed to insert the transcribed text: \(message)"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    @MainActor
    public func showPreferences(initialTab: Int = 0) {
        guard let modelManager = modelManager else {
            logger.error("ModelManager not initialized yet")
            return
        }

        if preferencesWindow == nil {
            preferencesWindow = PreferencesWindowController(
                modelManager: modelManager,
                whisperEngine: whisperEngine,
                permissionManager: permissionManager,
                settings: settings,
                initialTab: initialTab
            )
        } else {
            // If window already exists, update the selected tab
            preferencesWindow?.setSelectedTab(initialTab)
        }

        preferencesWindow?.showWindow(nil)
        preferencesWindow?.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @MainActor
    public func showHelp() {
        if helpWindow == nil {
            helpWindow = HelpWindowController()
        }

        helpWindow?.showWindow(nil)
        helpWindow?.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @MainActor
    private func showMicrophonePermissionAlert() {
        let alert = NSAlert()
        alert.messageText = NSLocalizedString("permissions.microphone.title", comment: "Microphone Access Required")
        alert.informativeText = NSLocalizedString("permissions.microphone.message", comment: "Microphone permission message")
        alert.alertStyle = .warning
        alert.addButton(withTitle: NSLocalizedString("permissions.open_settings", comment: "Open System Settings"))
        alert.addButton(withTitle: NSLocalizedString("general.cancel", comment: "Cancel"))

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            permissionManager.openSystemSettings(for: .microphone)
        }
    }

    @MainActor
    private func showAccessibilityPermissionAlert() {
        let alert = NSAlert()
        alert.messageText = NSLocalizedString("permissions.accessibility.title", comment: "Accessibility Access Required")
        alert.informativeText = NSLocalizedString("permissions.accessibility.message", comment: "Accessibility permission message")
        alert.alertStyle = .warning
        alert.addButton(withTitle: NSLocalizedString("permissions.open_settings", comment: "Open System Settings"))
        alert.addButton(withTitle: NSLocalizedString("general.cancel", comment: "Cancel"))

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            permissionManager.openSystemSettings(for: .accessibility)
        }
    }

    @MainActor
    private func showInputMonitoringPermissionAlert() {
        let alert = NSAlert()
        alert.messageText = NSLocalizedString("permissions.input_monitoring.title", comment: "Input Monitoring Required")
        alert.informativeText = NSLocalizedString("permissions.input_monitoring.message", comment: "Input monitoring permission message")
        alert.alertStyle = .warning
        alert.addButton(withTitle: NSLocalizedString("permissions.open_settings", comment: "Open System Settings"))
        alert.addButton(withTitle: NSLocalizedString("general.cancel", comment: "Cancel"))

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            permissionManager.openSystemSettings(for: .inputMonitoring)
        }
    }

    @MainActor
    private func showModelSetupAlert() {
        let alert = NSAlert()
        alert.messageText = "No Speech Recognition Model"
        alert.informativeText = "You need to download and select a speech recognition model before using Tell me.\n\nWould you like to open Preferences to download a model?"
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
        onboardingWindow?.close()
        helpWindow?.close()
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
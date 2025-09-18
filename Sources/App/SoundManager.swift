import Foundation
import AVFoundation
import AppKit
import CoreUtils

public class SoundManager: ObservableObject {
    private let logger = Logger(category: "SoundManager")

    @Published public var soundsEnabled: Bool = true

    private var startSound: AVAudioPlayer?
    private var stopSound: AVAudioPlayer?

    public init() {
        setupSounds()
    }

    private func setupSounds() {
        // Use system sounds for now
        // In a future version, we could bundle custom sound files
        setupSystemSounds()
    }

    private func setupSystemSounds() {
        // We'll use NSSound for system sounds since AVAudioPlayer requires files
        // These are just placeholders - in a real implementation we'd bundle sound files
        logger.info("Sound manager initialized with system sounds")
    }

    public func playStartSound() {
        guard soundsEnabled else { return }

        logger.debug("Playing start sound")
        // Use a subtle system sound for start
        NSSound(named: "Glass")?.play()
    }

    public func playStopSound() {
        guard soundsEnabled else { return }

        logger.debug("Playing stop sound")
        // Use a different system sound for stop
        NSSound(named: "Blow")?.play()
    }

    public func playErrorSound() {
        logger.debug("Playing error sound")
        // Always play error sound regardless of settings
        NSSound(named: "Funk")?.play()
    }
}
import Foundation
import AVFoundation
import CoreUtils

public protocol AudioEngineDelegate: AnyObject {
    func audioEngine(_ engine: AudioEngine, didUpdateLevel level: Float)
    func audioEngine(_ engine: AudioEngine, didCaptureAudio data: Data)
    func audioEngineDidStartCapture(_ engine: AudioEngine)
    func audioEngineDidStopCapture(_ engine: AudioEngine)
}

public class AudioEngine: ObservableObject {
    private let logger = Logger(category: "AudioEngine")
    private let audioEngine = AVAudioEngine()
    private let inputNode: AVAudioInputNode
    private let mixerNode = AVAudioMixerNode()

    // Audio format for 16 kHz mono PCM
    private let targetFormat = AVAudioFormat(commonFormat: .pcmFormatInt16,
                                             sampleRate: 16000,
                                             channels: 1,
                                             interleaved: false)!

    private var capturedData = Data()
    private let captureQueue = DispatchQueue(label: "com.menuwhisper.audio.capture", qos: .userInitiated)

    public weak var delegate: AudioEngineDelegate?

    @Published public private(set) var isCapturing = false
    @Published public private(set) var currentLevel: Float = 0.0

    public init() {
        inputNode = audioEngine.inputNode
        setupAudioEngine()
    }

    deinit {
        stopCapture()
    }

    private func setupAudioEngine() {
        // Attach mixer node
        audioEngine.attach(mixerNode)

        // Get the input format from the microphone
        let inputFormat = inputNode.inputFormat(forBus: 0)
        logger.info("Input format: \(inputFormat)")

        // Connect input node to mixer
        audioEngine.connect(inputNode, to: mixerNode, format: inputFormat)
    }

    public func startCapture() throws {
        logger.info("Starting audio capture")

        guard !isCapturing else {
            logger.warning("Audio capture already in progress")
            return
        }

        // Reset captured data
        captureQueue.async {
            self.capturedData = Data()
        }

        // Install tap on the mixer node to capture audio
        let inputFormat = inputNode.inputFormat(forBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { [weak self] buffer, time in
            self?.processAudioBuffer(buffer)
        }

        do {
            try audioEngine.start()
            isCapturing = true
            logger.info("Audio engine started successfully")
            delegate?.audioEngineDidStartCapture(self)
        } catch {
            logger.error("Failed to start audio engine: \(error)")
            inputNode.removeTap(onBus: 0)
            throw error
        }
    }

    public func stopCapture() {
        logger.info("Stopping audio capture")

        guard isCapturing else {
            logger.warning("Audio capture not in progress")
            return
        }

        // Remove tap and stop engine
        inputNode.removeTap(onBus: 0)
        audioEngine.stop()

        isCapturing = false
        currentLevel = 0.0

        // Send final captured data to delegate
        captureQueue.async {
            if !self.capturedData.isEmpty {
                DispatchQueue.main.async {
                    self.delegate?.audioEngine(self, didCaptureAudio: self.capturedData)
                }
            }
        }

        delegate?.audioEngineDidStopCapture(self)
        logger.info("Audio capture stopped")
    }

    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        // Calculate RMS level for visualization
        let level = calculateRMS(buffer: buffer)

        DispatchQueue.main.async {
            self.currentLevel = level
            self.delegate?.audioEngine(self, didUpdateLevel: level)
        }

        // Convert to target format (16 kHz mono) if needed
        if let convertedBuffer = convertBufferToTargetFormat(buffer) {
            captureQueue.async {
                self.appendAudioData(from: convertedBuffer)
            }
        }
    }

    private func calculateRMS(buffer: AVAudioPCMBuffer) -> Float {
        guard let channelData = buffer.floatChannelData,
              buffer.frameLength > 0 else {
            return 0.0
        }

        let frameLength = Int(buffer.frameLength)
        let samples = channelData[0] // Use first channel

        var sum: Float = 0.0
        for i in 0..<frameLength {
            sum += samples[i] * samples[i]
        }

        let rms = sqrt(sum / Float(frameLength))

        // Convert to dB and normalize to 0-1 range
        let db = 20 * log10(max(rms, 0.00001)) // Avoid log(0)
        let normalizedLevel = max(0, min(1, (db + 60) / 60)) // Map -60dB to 0dB -> 0 to 1

        return normalizedLevel
    }

    private func convertBufferToTargetFormat(_ inputBuffer: AVAudioPCMBuffer) -> AVAudioPCMBuffer? {
        let inputFormat = inputBuffer.format

        // If already in target format, return as-is
        if inputFormat.sampleRate == targetFormat.sampleRate &&
           inputFormat.channelCount == targetFormat.channelCount {
            return inputBuffer
        }

        // Create converter
        guard let converter = AVAudioConverter(from: inputFormat, to: targetFormat) else {
            logger.error("Failed to create audio converter")
            return nil
        }

        // Calculate output frame capacity
        let inputFrameCount = inputBuffer.frameLength
        let outputFrameCapacity = AVAudioFrameCount(Double(inputFrameCount) * targetFormat.sampleRate / inputFormat.sampleRate)

        // Create output buffer
        guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: outputFrameCapacity) else {
            logger.error("Failed to create output buffer")
            return nil
        }

        var error: NSError?
        let inputBlock: AVAudioConverterInputBlock = { inNumPackets, outStatus in
            outStatus.pointee = .haveData
            return inputBuffer
        }

        converter.convert(to: outputBuffer, error: &error, withInputFrom: inputBlock)

        if let error = error {
            logger.error("Audio conversion failed: \(error)")
            return nil
        }

        return outputBuffer
    }

    private func appendAudioData(from buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.int16ChannelData,
              buffer.frameLength > 0 else {
            return
        }

        let frameLength = Int(buffer.frameLength)
        let samples = channelData[0]

        // Convert Int16 samples to Data
        let data = Data(bytes: samples, count: frameLength * MemoryLayout<Int16>.size)
        capturedData.append(data)
    }
}
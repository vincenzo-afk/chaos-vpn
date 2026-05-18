import AVFoundation
import Foundation

/**
 * Manages the AVAudioEngine graph for real-time voice processing on iOS.
 *
 * Chain: Mic Input → Gain → Bandpass EQ → Distortion → Reverb → Delay → Output
 *
 * Interruption handling: registers for AVAudioSession.interruptionNotification
 * and restarts the engine automatically after interruptions end.
 *
 * LIMITATION: iOS does not expose a true system-wide virtual microphone API.
 * This implementation works with VoIP/communication apps (WhatsApp, FaceTime,
 * Discord via CallKit) using AVAudioSession mode .voiceChat.
 */
class AudioEngineManager {

    // MARK: - Properties
    static let shared = AudioEngineManager()

    private var engine: AVAudioEngine?
    private var inputNode: AVAudioInputNode?
    private var eqNode: AVAudioUnitEQ?
    private var distortionNode: AVAudioUnitDistortion?
    private var reverbNode: AVAudioUnitReverb?
    private var delayNode: AVAudioUnitDelay?
    private var timePitchNode: AVAudioUnitTimePitch?

    // DSP parameters (updated from Flutter via MethodChannel)
    var gainMultiplier: Float = 4.0
    var reverbWetDry: Float = 45.0
    var crackleProb: Float = 0.03
    var dropoutProb: Float = 0.06
    var delayTime: Double = 0.1

    // Chaos state
    private(set) var isActive = false
    private var pitchWobbleTimer: Timer?
    private var interruptionObserver: NSObjectProtocol?

    // MARK: - Setup

    private init() {}

    func start() throws {
        guard !isActive else { return }

        let session = AVAudioSession.sharedInstance()

        // Register interruption handler BEFORE activating session
        registerInterruptionHandler(session: session)

        try session.setCategory(
            .playAndRecord,
            mode: .voiceChat,
            options: [.defaultToSpeaker, .allowBluetooth, .mixWithOthers]
        )
        try session.setPreferredSampleRate(16000)
        try session.setPreferredIOBufferDuration(0.005)
        try session.setActive(true)

        engine = AVAudioEngine()
        guard let engine = engine else { return }

        inputNode = engine.inputNode

        // Node 1: Bandpass EQ (300–3400 Hz telephone effect)
        let eq = AVAudioUnitEQ(numberOfBands: 2)
        engine.attach(eq)
        eq.bands[0].filterType = .highPass
        eq.bands[0].frequency = 300.0
        eq.bands[0].bypass = false
        eq.bands[1].filterType = .lowPass
        eq.bands[1].frequency = 3400.0
        eq.bands[1].bypass = false
        eqNode = eq

        // Node 2: Distortion
        let distortion = AVAudioUnitDistortion()
        engine.attach(distortion)
        distortion.loadFactoryPreset(.multiDistortedFunk)
        distortion.preGain = 20.0
        distortion.wetDryMix = 80.0
        distortionNode = distortion

        // Node 3: Reverb (Large Room)
        let reverb = AVAudioUnitReverb()
        engine.attach(reverb)
        reverb.loadFactoryPreset(.largeChamber)
        reverb.wetDryMix = reverbWetDry
        reverbNode = reverb

        // Node 4: Multi-tap Delay
        let delay = AVAudioUnitDelay()
        engine.attach(delay)
        delay.delayTime = delayTime
        delay.feedback = 40.0
        delay.wetDryMix = 50.0
        delayNode = delay

        // Node 5: Pitch / Time Effect
        let timePitch = AVAudioUnitTimePitch()
        engine.attach(timePitch)
        timePitch.pitch = 0.0
        timePitch.rate = 1.0
        timePitchNode = timePitch

        // Wire the graph
        let format = inputNode!.outputFormat(forBus: 0)
        let outputMixer = AVAudioMixerNode()
        engine.attach(outputMixer)
        outputMixer.volume = gainMultiplier

        engine.connect(inputNode!, to: eq, format: format)
        engine.connect(eq, to: distortion, format: format)
        engine.connect(distortion, to: reverb, format: format)
        engine.connect(reverb, to: delay, format: format)
        engine.connect(delay, to: timePitch, format: format)
        engine.connect(timePitch, to: outputMixer, format: format)
        engine.connect(outputMixer, to: engine.mainMixerNode, format: format)

        // Install tap for PCM access (crackle + dropout injection)
        installChaosTap(on: outputMixer, format: format)

        try engine.start()
        isActive = true

        // Start pitch wobble
        startPitchWobble()

        print("[AudioEngineManager] Engine started")
    }

    // MARK: - Interruption Handling

    private func registerInterruptionHandler(session: AVAudioSession) {
        // Remove any previous observer first
        if let observer = interruptionObserver {
            NotificationCenter.default.removeObserver(observer)
        }

        interruptionObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: session,
            queue: .main
        ) { [weak self] notification in
            guard let self = self,
                  let userInfo = notification.userInfo,
                  let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
                  let type = AVAudioSession.InterruptionType(rawValue: typeValue)
            else { return }

            switch type {
            case .began:
                print("[AudioEngineManager] Interruption began — pausing")
                // Engine will be stopped by the system automatically
                self.pitchWobbleTimer?.invalidate()
                self.pitchWobbleTimer = nil

            case .ended:
                print("[AudioEngineManager] Interruption ended — restarting")
                guard let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt else {
                    return
                }
                let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                if options.contains(.shouldResume) {
                    self.restartEngine()
                }

            @unknown default:
                break
            }
        }
    }

    private func restartEngine() {
        do {
            try AVAudioSession.sharedInstance().setActive(true)
            try engine?.start()
            isActive = true
            startPitchWobble()
            print("[AudioEngineManager] Engine restarted after interruption")
        } catch {
            print("[AudioEngineManager] Failed to restart engine: \(error.localizedDescription)")
            // Retry once after a short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                self?.restartEngine()
            }
        }
    }

    // MARK: - Chaos PCM Tap

    private func installChaosTap(on node: AVAudioMixerNode, format: AVAudioFormat) {
        node.installTap(onBus: 0, bufferSize: 512, format: format) { [weak self] buffer, _ in
            guard let self = self else { return }
            guard let channelData = buffer.floatChannelData else { return }
            let frameCount = Int(buffer.frameLength)
            var rng = SystemRandomNumberGenerator()

            // Dropout: silence entire buffer
            if Float.random(in: 0...1, using: &rng) < self.dropoutProb {
                for channel in 0..<Int(buffer.format.channelCount) {
                    memset(channelData[channel], 0, frameCount * MemoryLayout<Float>.size)
                }
                return
            }

            // Crackle: inject random impulse noise
            for channel in 0..<Int(buffer.format.channelCount) {
                for i in 0..<frameCount {
                    if Float.random(in: 0...1, using: &rng) < self.crackleProb {
                        let impulse: Float = Bool.random(using: &rng) ? 1.0 : -1.0
                        channelData[channel][i] = (channelData[channel][i] + impulse * 0.85)
                            .clamped(to: -1.0...1.0)
                    }
                }
            }
        }
    }

    // MARK: - Pitch Wobble

    private func startPitchWobble() {
        pitchWobbleTimer = Timer.scheduledTimer(
            withTimeInterval: Double.random(in: 0.2...0.6),
            repeats: false
        ) { [weak self] _ in
            guard let self = self, self.isActive else { return }
            // ±3 semitones = ±300 cents
            let newPitch = Float.random(in: -300...300)
            self.timePitchNode?.pitch = newPitch
            self.startPitchWobble()
        }
    }

    // MARK: - Stop

    func stop() {
        guard isActive else { return }
        pitchWobbleTimer?.invalidate()
        pitchWobbleTimer = nil

        // Remove interruption observer
        if let observer = interruptionObserver {
            NotificationCenter.default.removeObserver(observer)
            interruptionObserver = nil
        }

        engine?.stop()
        engine = nil
        isActive = false
        try? AVAudioSession.sharedInstance().setActive(false)
        print("[AudioEngineManager] Engine stopped")
    }

    // MARK: - Update Parameters

    func updateGain(_ gain: Float) {
        gainMultiplier = gain
    }

    func updateReverb(_ wetDry: Float) {
        reverbNode?.wetDryMix = wetDry
    }

    func updateDelay(_ time: Double, feedback: Float) {
        delayNode?.delayTime = time
        delayNode?.feedback = feedback
    }
}

extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        return min(max(self, range.lowerBound), range.upperBound)
    }
}

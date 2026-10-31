import AVFoundation

/// Casino sound effects, fully synthesized at runtime — no audio assets.
///
/// Every effect is rendered into a PCM buffer (sine tones + low-passed
/// noise with decay envelopes) and played through a single player node.
/// Sounds are decorative: any audio failure is swallowed silently.
final class SoundEngine {
    static let shared = SoundEngine()

    private static let muteKey = "casino.soundsMuted"

    var muted: Bool {
        get { UserDefaults.standard.bool(forKey: Self.muteKey) }
        set { UserDefaults.standard.set(newValue, forKey: Self.muteKey) }
    }

    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private var isStarted = false
    private let sampleRate: Double = 44_100

    private init() {}

    // MARK: - Effects

    /// Tiny UI tap click.
    func tap() {
        schedule(duration: 0.07) { t in
            self.tone(t: t, start: 0, freq: 1500, length: 0.07, amp: 0.16, decay: 70)
        }
    }

    /// Reel whoosh when a spin starts: filtered noise swell + soft rising sweep.
    func spinStart() {
        let noise = LowPass()
        schedule(duration: 0.45) { t in
            let envelope = pow(sin(Double.pi * t / 0.45), 1.5)
            let whoosh = Double(noise.next(alpha: 0.16)) * envelope * 0.55
            let sweepPhase = 2 * Double.pi * (180 * t + 575 * t * t)
            let sweep = sin(sweepPhase) * envelope * 0.10
            return whoosh + sweep
        }
    }

    /// Firm thunk when a reel lands.
    func reelStop() {
        let noise = LowPass()
        schedule(duration: 0.14) { t in
            let thump = sin(2 * Double.pi * 105 * t) * exp(-t * 30) * 0.85
            let click = Double(noise.next(alpha: 0.5)) * exp(-t * 55) * 0.30
            return thump + click
        }
    }

    /// Coin pings for small wins, a rising arpeggio cascade for big wins.
    func win(big: Bool) {
        if big {
            let notes: [Double] = [523, 659, 784, 1047, 1319, 1568]
            schedule(duration: 1.8) { t in
                var sum = 0.0
                for (index, freq) in notes.enumerated() {
                    sum += self.tone(t: t, start: Double(index) * 0.09, freq: freq, length: 0.55, amp: 0.20, decay: 7)
                }
                for index in 0..<4 {
                    sum += self.coinPing(t: t, start: Double(index) * 0.12)
                }
                return sum
            }
        } else {
            schedule(duration: 0.85) { t in
                var sum = 0.0
                for index in 0..<3 {
                    sum += self.coinPing(t: t, start: Double(index) * 0.09)
                }
                sum += self.tone(t: t, start: 0.30, freq: 523, length: 0.35, amp: 0.10, decay: 8)
                sum += self.tone(t: t, start: 0.30, freq: 659, length: 0.35, amp: 0.10, decay: 8)
                sum += self.tone(t: t, start: 0.30, freq: 784, length: 0.35, amp: 0.10, decay: 8)
                return sum
            }
        }
    }

    // MARK: - Building blocks

    /// One sine tone with an exponential decay envelope, or 0 outside its window.
    private func tone(t: Double, start: Double, freq: Double, length: Double, amp: Double, decay: Double) -> Double {
        let local = t - start
        guard local >= 0, local <= length else { return 0 }
        return sin(2 * Double.pi * freq * local) * exp(-local * decay) * amp
    }

    /// Classic slot coin: short low ping, then a longer high ping.
    private func coinPing(t: Double, start: Double) -> Double {
        tone(t: t, start: start, freq: 988, length: 0.08, amp: 0.30, decay: 26)
            + tone(t: t, start: start + 0.07, freq: 1319, length: 0.35, amp: 0.30, decay: 9)
    }

    // MARK: - Playback core

    private func schedule(duration: Double, generator: @escaping (Double) -> Double) {
        guard !muted else { return }
        startIfNeeded()
        guard isStarted, let buffer = makeBuffer(duration: duration, generator: generator) else { return }
        player.scheduleBuffer(buffer, at: nil, options: [])
    }

    private func makeBuffer(duration: Double, generator: (Double) -> Double) -> AVAudioPCMBuffer? {
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1) else { return nil }
        let frames = AVAudioFrameCount(duration * sampleRate)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames),
              let channelData = buffer.floatChannelData else { return nil }
        buffer.frameLength = frames
        let channel = channelData[0]
        for frame in 0..<Int(frames) {
            let t = Double(frame) / sampleRate
            var sample = generator(t)
            // Short global fades keep buffer edges click-free.
            let fadeIn = min(1.0, t / 0.004)
            let fadeOut = min(1.0, (duration - t) / 0.010)
            sample *= min(fadeIn, fadeOut)
            channel[frame] = Float(max(-1, min(1, sample)))
        }
        return buffer
    }

    private func startIfNeeded() {
        guard !isStarted else { return }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
        } catch {
            // Decorative only — continue without a configured session.
        }
        engine.attach(player)
        if let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1) {
            engine.connect(player, to: engine.mainMixerNode, format: format)
        }
        player.volume = 0.9
        engine.prepare()
        do {
            try engine.start()
            player.play()
            isStarted = true
        } catch {
            isStarted = false
        }
    }
}

/// One-pole low-pass filter over white noise (for whooshes and thunks).
private final class LowPass {
    private var value: Float = 0

    func next(alpha: Float) -> Float {
        let white = Float.random(in: -1...1)
        value += alpha * (white - value)
        return value
    }
}

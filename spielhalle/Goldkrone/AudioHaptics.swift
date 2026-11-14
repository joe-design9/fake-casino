import AVFoundation
import UIKit

/// Short arcade tones synthesized at runtime. Failures stay silent.
final class SoundEngine {
    static let shared = SoundEngine()

    private let engine = AVAudioEngine()
    private let players = (0..<4).map { _ in AVAudioPlayerNode() }
    private let sampleRate = 44_100.0
    private var started = false
    private var attached = false
    private var unavailable = false
    private var cursor = 0

    private init() {}

    /// Reads the persisted toggle directly so playback stays off the main-actor wallet.
    private var enabled: Bool {
        let key = "goldkrone.sound"
        if UserDefaults.standard.object(forKey: key) == nil { return true }
        return UserDefaults.standard.bool(forKey: key)
    }

    func click() { blip(freq: 880, seconds: 0.045, amp: 0.12) }
    func spin() { noise(seconds: 0.32, amp: 0.18) }
    func stop() { blip(freq: 140, seconds: 0.09, amp: 0.35, decay: 28) }
    func tense() { blip(freq: 620, seconds: 0.12, amp: 0.16, decay: 8) }
    func win() { chord([523, 659, 784], seconds: 0.42) }
    func bigWin() { chord([523, 659, 784, 1046], seconds: 0.7) }
    func mega() { chord([392, 523, 659, 784, 1046, 1318], seconds: 1.05) }
    func risk() { blip(freq: 340, seconds: 0.08, amp: 0.2, decay: 18) }
    func riskWin() { chord([587, 880], seconds: 0.28) }
    func riskLose() { blip(freq: 110, seconds: 0.28, amp: 0.4, decay: 6) }
    func bonus() { chord([523, 659, 784, 1046], seconds: 0.55) }

    private func blip(freq: Double, seconds: Double, amp: Double, decay: Double = 22) {
        schedule(seconds: seconds) { t in
            sin(2 * Double.pi * freq * t) * exp(-t * decay) * amp
        }
    }

    private func chord(_ notes: [Double], seconds: Double) {
        schedule(seconds: seconds) { t in
            var sum = 0.0
            for (index, freq) in notes.enumerated() {
                let start = Double(index) * 0.045
                let local = t - start
                if local >= 0 {
                    sum += sin(2 * Double.pi * freq * local) * exp(-local * 4.5) * 0.16
                }
            }
            return sum
        }
    }

    private func noise(seconds: Double, amp: Double) {
        var state: UInt32 = 0x123456
        schedule(seconds: seconds) { t in
            state = state &* 1664525 &+ 1013904223
            let n = Double(state % 2000) / 1000.0 - 1
            let envelope = sin(Double.pi * min(1, t / seconds))
            return n * envelope * amp * 0.35
        }
    }

    private func schedule(seconds: Double, sample: @escaping (Double) -> Double) {
        guard enabled else { return }
        let run = {
            self.startIfNeeded()
            guard self.started, let buffer = self.buffer(seconds: seconds, sample: sample) else { return }
            let player = self.players[self.cursor % self.players.count]
            self.cursor += 1
            player.scheduleBuffer(buffer, at: nil, options: [])
        }
        if Thread.isMainThread {
            run()
        } else {
            DispatchQueue.main.async(execute: run)
        }
    }

    private func startIfNeeded() {
        guard !started, !unavailable else { return }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.ambient, options: [.mixWithOthers])
            try session.setActive(true)
            if !attached {
                for player in players {
                    engine.attach(player)
                    engine.connect(player, to: engine.mainMixerNode, format: nil)
                }
                attached = true
            }
            if !engine.isRunning {
                try engine.start()
            }
            for player in players where !player.isPlaying {
                player.play()
            }
            started = true
        } catch {
            started = false
            unavailable = true
        }
    }

    private func buffer(seconds: Double, sample: (Double) -> Double) -> AVAudioPCMBuffer? {
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1) else { return nil }
        let frames = AVAudioFrameCount(seconds * sampleRate)
        guard frames > 0,
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames),
              let channels = buffer.floatChannelData else { return nil }
        buffer.frameLength = frames
        let data = channels[0]
        for frame in 0..<Int(frames) {
            let t = Double(frame) / sampleRate
            var value = sample(t)
            let fadeIn = min(1, t / 0.004)
            let fadeOut = min(1, (seconds - t) / 0.012)
            value *= fadeIn * fadeOut
            data[frame] = Float(max(-1, min(1, value)))
        }
        return buffer
    }
}

enum Haptics {
    private static var enabled: Bool {
        let key = "goldkrone.haptics"
        if UserDefaults.standard.object(forKey: key) == nil { return true }
        return UserDefaults.standard.bool(forKey: key)
    }

    static func tap() { impact(.light) }
    static func reel() { impact(.medium) }
    static func win() { impact(.rigid) }
    static func big() { notify(.success) }
    static func mega() { notify(.success) }
    static func risk() { impact(.heavy) }
    static func lose() { notify(.error) }

    private static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        guard enabled else { return }
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }

    private static func notify(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        guard enabled else { return }
        UINotificationFeedbackGenerator().notificationOccurred(type)
    }
}

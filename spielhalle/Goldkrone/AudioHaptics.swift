import AVFoundation
import Foundation
import UIKit

/// Synthesized tones played with AVAudioPlayer.
///
/// AVAudioEngine was the on-device crash: `connect(_:to:format:)` with a nil
/// format raises an Objective-C exception on a real iPhone (the mixer format
/// is not ready yet). Swift `do/catch` does not catch that, and every button
/// called into it. AVAudioPlayer only sees PCM bytes and fails softly.
final class SoundEngine {
    static let shared = SoundEngine()

    private var players: [AVAudioPlayer] = []
    private var sessionReady = false
    private let sampleRate = 22_050

    private init() {}

    private var enabled: Bool {
        if ProcessInfo.processInfo.arguments.contains("-uitest") { return false }
        let key = "goldkrone.sound"
        if UserDefaults.standard.object(forKey: key) == nil { return true }
        return UserDefaults.standard.bool(forKey: key)
    }

    func click() { tone([(880, 0, 0.04, 0.2)]) }
    func spin() { noise(seconds: 0.22) }
    func stop() { tone([(140, 0, 0.08, 0.45)]) }
    func tense() { tone([(640, 0, 0.1, 0.2)]) }
    func win() { tone([(523, 0, 0.18, 0.25), (659, 0.06, 0.18, 0.25), (784, 0.12, 0.22, 0.25)]) }
    func bigWin() { tone([(523, 0, 0.2, 0.22), (659, 0.08, 0.2, 0.22), (784, 0.16, 0.22, 0.22), (1046, 0.24, 0.28, 0.22)]) }
    func mega() { tone([(392, 0, 0.25, 0.2), (523, 0.08, 0.25, 0.2), (659, 0.16, 0.25, 0.2), (784, 0.24, 0.3, 0.2), (1046, 0.32, 0.35, 0.2)]) }
    func risk() { tone([(330, 0, 0.07, 0.3)]) }
    func riskWin() { tone([(587, 0, 0.12, 0.3), (880, 0.08, 0.16, 0.3)]) }
    func riskLose() { tone([(110, 0, 0.22, 0.4)]) }
    func bonus() { tone([(523, 0, 0.16, 0.25), (659, 0.1, 0.16, 0.25), (784, 0.2, 0.22, 0.25)]) }

    private func tone(_ notes: [(freq: Double, start: Double, length: Double, amp: Double)]) {
        let seconds = notes.map { $0.start + $0.length }.max() ?? 0.1
        schedule(seconds: seconds) { t in
            var sum = 0.0
            for note in notes {
                let local = t - note.start
                guard local >= 0, local <= note.length else { continue }
                sum += sin(2 * Double.pi * note.freq * local) * exp(-local * 8) * note.amp
            }
            return sum
        }
    }

    private func noise(seconds: Double) {
        var state: UInt32 = 0x1234ABCD
        schedule(seconds: seconds) { t in
            state = state &* 1664525 &+ 1013904223
            let n = Double(Int32(bitPattern: state)) / Double(Int32.max)
            return n * sin(Double.pi * min(1, t / seconds)) * 0.18
        }
    }

    private func schedule(seconds: Double, sample: (Double) -> Double) {
        guard enabled, seconds > 0, seconds < 3 else { return }
        let data = render(seconds: seconds, sample: sample)
        let run = { self.play(data) }
        if Thread.isMainThread {
            run()
        } else {
            DispatchQueue.main.async(execute: run)
        }
    }

    private func render(seconds: Double, sample: (Double) -> Double) -> Data {
        let frames = max(1, Int(seconds * Double(sampleRate)))
        var pcm = [Int16]()
        pcm.reserveCapacity(frames)
        for frame in 0..<frames {
            let t = Double(frame) / Double(sampleRate)
            var value = sample(t)
            let fade = min(1, t / 0.004) * min(1, (seconds - t) / 0.008)
            value = max(-1, min(1, value * fade))
            pcm.append(Int16(value * 32_000))
        }
        return wav(pcm: pcm)
    }

    private func play(_ data: Data) {
        prepareSession()
        guard let player = try? AVAudioPlayer(data: data) else { return }
        player.prepareToPlay()
        player.play()
        players.append(player)
        players.removeAll { !$0.isPlaying }
    }

    private func prepareSession() {
        guard !sessionReady else { return }
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.ambient, options: [.mixWithOthers])
            try session.setActive(true)
            sessionReady = true
        } catch {
            sessionReady = false
        }
    }

    private func wav(pcm: [Int16]) -> Data {
        let dataSize = pcm.count * 2
        var data = Data()
        func append(_ string: String) { data.append(contentsOf: string.utf8) }
        func append32(_ value: UInt32) {
            var little = value.littleEndian
            data.append(Data(bytes: &little, count: 4))
        }
        func append16(_ value: UInt16) {
            var little = value.littleEndian
            data.append(Data(bytes: &little, count: 2))
        }
        append("RIFF")
        append32(UInt32(36 + dataSize))
        append("WAVE")
        append("fmt ")
        append32(16)
        append16(1)
        append16(1)
        append32(UInt32(sampleRate))
        append32(UInt32(sampleRate * 2))
        append16(2)
        append16(16)
        append("data")
        append32(UInt32(dataSize))
        pcm.withUnsafeBufferPointer { buffer in
            guard let base = buffer.baseAddress else { return }
            data.append(Data(bytes: base, count: buffer.count * MemoryLayout<Int16>.size))
        }
        return data
    }
}

enum Haptics {
    private static var enabled: Bool {
        if ProcessInfo.processInfo.arguments.contains("-uitest") { return false }
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
        let fire = {
            guard enabled else { return }
            let generator = UIImpactFeedbackGenerator(style: style)
            generator.prepare()
            generator.impactOccurred()
        }
        if Thread.isMainThread { fire() } else { DispatchQueue.main.async(execute: fire) }
    }

    private static func notify(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        let fire = {
            guard enabled else { return }
            let generator = UINotificationFeedbackGenerator()
            generator.prepare()
            generator.notificationOccurred(type)
        }
        if Thread.isMainThread { fire() } else { DispatchQueue.main.async(execute: fire) }
    }
}

enum LaunchFlags {
    static var uiTest: Bool {
        ProcessInfo.processInfo.arguments.contains("-uitest")
    }
}

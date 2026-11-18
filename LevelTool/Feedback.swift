import AVFoundation
import UIKit

@MainActor
final class ToneEngine {
    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private var ready = false
    private var attached = false
    private var lastBeep = -Double.infinity
    private var inside = false
    func prepare() {
        guard !ready else { return }
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
            let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!
            if !attached { engine.attach(player); engine.connect(player, to: engine.mainMixerNode, format: format); attached = true }
            try engine.start(); player.play(); ready = true
        } catch { ready = false }
    }
    func beep(duration: Double = 0.08) {
        prepare(); guard ready else { return }
        let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!
        let frames = AVAudioFrameCount(44100 * duration)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames), let channel = buffer.floatChannelData?[0] else { return }
        buffer.frameLength = frames
        for i in 0..<Int(frames) {
            let envelope = min(1, min(Double(i) / 220, Double(Int(frames) - i) / 220))
            channel[i] = Float(sin(2 * .pi * 880 * Double(i) / 44100) * 0.12 * envelope)
        }
        player.scheduleBuffer(buffer)
    }
    func update(error: Double, tolerance: Double, time: Double, single: Bool) {
        let reached = abs(error) <= tolerance
        let interval = reached ? 0.55 : 0.1 + min(abs(error), 10) / 10 * 0.7
        if time - lastBeep >= interval && (!reached || !single || !inside) {
            beep(duration: reached ? 0.5 : 0.06); lastBeep = time
        }
        inside = reached
    }
    func stop() { player.stop(); engine.stop(); ready = false; lastBeep = -.infinity; inside = false }
}
@MainActor
final class VoiceReader {
    private let synth = AVSpeechSynthesizer()
    private var last: Double?
    func read(_ text: String, value: Double) {
        guard !synth.isSpeaking, last == nil || abs(value - last!) > 0.2 else { return }
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
        let utterance = AVSpeechUtterance(string: text)
        let language = Bundle.main.preferredLocalizations.first ?? "en"
        utterance.voice = AVSpeechSynthesisVoice(language: language == "zh-Hant" ? "zh-TW" : (language == "zh-Hans" ? "zh-CN" : "en-US"))
        utterance.rate = 0.46; synth.speak(utterance); last = value
    }
    func stop() { synth.stopSpeaking(at: .immediate); last = nil }
}

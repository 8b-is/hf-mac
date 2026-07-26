import Foundation
import AVFoundation
@preconcurrency import Speech

/// hf.app's voice layer (preview) — on-device speech with Apple-native engines.
///
/// TTS speaks the local model's replies (`AVSpeechSynthesizer`). STT dictates
/// prompts by microphone, forced on-device (`SFSpeechRecognizer`
/// `requiresOnDeviceRecognition`) so audio never leaves the Mac. The 8b-native
/// swap — `liquid-rust` (STT) + `kokoro-tiny` (TTS) as sidecars — slots in behind
/// this same interface; see ROADMAP.md.
@MainActor
@Observable
final class VoiceEngine {
    // MARK: Text-to-speech
    private let synth = AVSpeechSynthesizer()
    var speakReplies = false

    // MARK: Speech-to-text (dictation)
    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private let audioEngine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    var isDictating = false
    var transcript = ""
    var note: String?

    // MARK: - Speak (TTS)
    func speak(_ text: String) {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard speakReplies, !t.isEmpty else { return }
        if synth.isSpeaking { synth.stopSpeaking(at: .immediate) }
        let u = AVSpeechUtterance(string: t)
        u.rate = AVSpeechUtteranceDefaultSpeechRate
        synth.speak(u)
    }

    func stopSpeaking() { synth.stopSpeaking(at: .immediate) }

    // MARK: - Dictate (STT, on-device)
    func toggleDictation() { isDictating ? stopDictation() : startDictation() }

    func startDictation() {
        transcript = ""; note = nil
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            Task { @MainActor in
                guard let self else { return }
                guard status == .authorized else {
                    self.note = "Enable Speech Recognition in System Settings › Privacy."
                    return
                }
                self.beginAudio()
            }
        }
    }

    private func beginAudio() {
        guard let recognizer, recognizer.isAvailable else {
            note = "Speech recognizer unavailable for this locale."; return
        }
        let req = SFSpeechAudioBufferRecognitionRequest()
        req.shouldReportPartialResults = true
        if recognizer.supportsOnDeviceRecognition { req.requiresOnDeviceRecognition = true }
        request = req

        let input = audioEngine.inputNode
        let format = input.outputFormat(forBus: 0)
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            req.append(buffer)
        }
        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch {
            note = "Microphone error: \(error.localizedDescription)"; return
        }
        isDictating = true

        task = recognizer.recognitionTask(with: req) { [weak self] result, error in
            Task { @MainActor in
                guard let self else { return }
                if let result { self.transcript = result.bestTranscription.formattedString }
                if error != nil || (result?.isFinal ?? false) { self.stopDictation() }
            }
        }
    }

    func stopDictation() {
        guard isDictating else { return }
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        task?.cancel()
        task = nil; request = nil
        isDictating = false
    }
}

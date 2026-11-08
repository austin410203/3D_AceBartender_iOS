import Foundation
import AVFoundation
import Speech

/// Bartender 的聲音＋按住說話。
/// 規則（老闆 2026-11-01）：女 Bartender 女聲、男 Bartender 男聲；同一輪只用一種引擎（beginConversation 決定）；
/// 線上語音失敗重試一次後這句安靜，不換聲音；系統語音只用同性別，沒有就不念。台詞排隊，一句念完才念下一句。
@MainActor
final class Voice: NSObject, ObservableObject, AVAudioPlayerDelegate, AVSpeechSynthesizerDelegate {
  static let shared = Voice()
  @Published var listening = false
  var on = true
  private enum Engine { case api, system }
  private var engine: Engine = .system
  private var apiDead = false
  private var queue: [(String, Bartender, Lang)] = []
  private var speaking = false
  private var token = 0
  private var player: AVAudioPlayer?
  private let synth = AVSpeechSynthesizer()
  private var lockedVoice: [String: AVSpeechSynthesisVoice?] = [:]
  private var finish: (() -> Void)?

  override init() { super.init(); synth.delegate = self }

  func beginConversation() {
    engine = Net.shared.tts && !apiDead ? .api : .system
    lockedVoice.removeAll()
  }

  func stop() {
    token += 1; queue.removeAll(); speaking = false
    player?.stop(); player = nil
    if synth.isSpeaking { synth.stopSpeaking(at: .immediate) }
  }

  func speak(_ text: String, _ bt: Bartender, _ lang: Lang) {
    guard on, !text.isEmpty else { return }
    queue.append((text, bt, lang))
    if !speaking { next() }
  }

  private func next() {
    guard !queue.isEmpty else { speaking = false; return }
    speaking = true
    let (text, bt, lang) = queue.removeFirst()
    let my = token
    Task { @MainActor in
      if engine == .api {
        var data: Data?
        for _ in 0..<2 where data == nil && !apiDead && my == token {
          let (d, dead) = await Net.shared.ttsAudio(text: text, bt: bt, lang: lang)
          data = d; if dead { apiDead = true }
        }
        guard my == token else { return }
        if let data, play(data, my) { return }
        next(); return   // 失敗就安靜，字還是看得到
      }
      guard my == token else { return }
      if !systemSpeak(text, bt, lang) { next() }
    }
  }

  private func activateSession() {
    try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
    try? AVAudioSession.sharedInstance().setActive(true)
  }

  private func play(_ data: Data, _ my: Int) -> Bool {
    activateSession()
    guard let p = try? AVAudioPlayer(data: data) else { return false }
    p.delegate = self; player = p
    return p.play()
  }
  nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
    Task { @MainActor in self.next() }
  }

  /// 系統語音：同語言、同性別；沒有同性別的聲音就不念（不會把男 Bartender 念成女聲）
  private func voice(for bt: Bartender, _ lang: Lang) -> AVSpeechSynthesisVoice? {
    let key = "\(bt.id)|\(lang.rawValue)"
    if let v = lockedVoice[key] { return v }
    let want: AVSpeechSynthesisVoiceGender = bt.gender == "male" ? .male : .female
    let prefix = String(lang.locale.prefix(2))
    let all = AVSpeechSynthesisVoice.speechVoices().filter { $0.language.hasPrefix(prefix) && $0.gender == want }
    let best = all.first { $0.language == lang.locale && $0.quality != .default } ?? all.first { $0.language == lang.locale } ?? all.first
    lockedVoice[key] = best
    return best
  }

  private func systemSpeak(_ text: String, _ bt: Bartender, _ lang: Lang) -> Bool {
    guard let v = voice(for: bt, lang) else { return false }
    activateSession()
    let u = AVSpeechUtterance(string: text)
    u.voice = v
    switch (bt.gender, bt.ageBand) {
    case ("female", "young"): u.pitchMultiplier = 1.15; u.rate = 0.52
    case ("female", _): u.pitchMultiplier = 1.0; u.rate = 0.49
    case ("male", "young"): u.pitchMultiplier = 1.0; u.rate = 0.52
    default: u.pitchMultiplier = 0.8; u.rate = 0.46
    }
    synth.speak(u)
    return true
  }
  nonisolated func speechSynthesizer(_ s: AVSpeechSynthesizer, didFinish u: AVSpeechUtterance) { Task { @MainActor in self.next() } }

  // MARK: 按住說話（字放進輸入框，玩家改好再送）
  private let audio = AVAudioEngine()
  private var request: SFSpeechAudioBufferRecognitionRequest?
  private var task: SFSpeechRecognitionTask?
  private var heard = ""
  private var endHandler: ((String?) -> Void)?

  func listen(lang: Lang, onText: @escaping (String) -> Void, onEnd: @escaping (String?) -> Void) {
    stop()
    SFSpeechRecognizer.requestAuthorization { status in
      Task { @MainActor in
        guard status == .authorized else { onEnd(nil); return }
        AVAudioApplication.requestRecordPermission { ok in
          Task { @MainActor in
            guard ok else { onEnd(nil); return }
            self.startListening(lang: lang, onText: onText, onEnd: onEnd)
          }
        }
      }
    }
  }

  private func startListening(lang: Lang, onText: @escaping (String) -> Void, onEnd: @escaping (String?) -> Void) {
    guard let rec = SFSpeechRecognizer(locale: Locale(identifier: lang.locale)), rec.isAvailable else { onEnd(nil); return }
    let s = AVAudioSession.sharedInstance()
    try? s.setCategory(.playAndRecord, mode: .measurement, options: [.duckOthers, .defaultToSpeaker])
    try? s.setActive(true, options: .notifyOthersOnDeactivation)
    let req = SFSpeechAudioBufferRecognitionRequest()
    req.shouldReportPartialResults = true
    request = req
    let input = audio.inputNode
    let fmt = input.outputFormat(forBus: 0)
    guard fmt.sampleRate > 0 else { onEnd(nil); return }
    input.removeTap(onBus: 0)
    input.installTap(onBus: 0, bufferSize: 1024, format: fmt) { buf, _ in req.append(buf) }
    audio.prepare()
    do { try audio.start() } catch { onEnd(nil); return }
    listening = true
    heard = ""
    endHandler = onEnd
    task = rec.recognitionTask(with: req) { result, error in
      let text = result?.bestTranscription.formattedString
      let done = error != nil || (result?.isFinal ?? false)
      Task { @MainActor in
        if let text, self.endHandler != nil { self.heard = text; onText(text) }
        if done { self.finishListening() }
      }
    }
  }

  func stopListening() {
    guard listening else { return }
    request?.endAudio()
    Task { @MainActor [weak self] in try? await Task.sleep(nanoseconds: 1_500_000_000); self?.finishListening() }
  }
  /// 只會回報一次
  private func finishListening() {
    endAudio()
    let h = endHandler; endHandler = nil
    h?(heard)
  }
  private func endAudio() {
    if audio.isRunning { audio.stop(); audio.inputNode.removeTap(onBus: 0) }
    task?.cancel(); request = nil; task = nil; listening = false
    try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
  }
}

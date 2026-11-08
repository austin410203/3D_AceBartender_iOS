import Foundation

/// 和 Worker（bar.emptyoffice.app）講話：/api/health、/api/llm、/api/tts。金鑰只在 Worker。
/// 內部測試期間 Worker 有密碼鎖：玩家在選單輸入內部測試碼 → POST /__unlock，拿到的 cookie 由 URLSession 自動帶。
/// 連不上、被鎖、超過每日上限 → 用核心的離線劇本，一樣能玩。
@MainActor
final class Net {
  static let shared = Net()
  static let base = URL(string: "https://bar.emptyoffice.app")!
  enum Mode: String { case unknown, live, offline }
  private(set) var mode: Mode = .unknown
  private(set) var reason = "init"
  private(set) var tts = false
  var forcedOffline = false

  private let session: URLSession = {
    let c = URLSessionConfiguration.default
    c.timeoutIntervalForRequest = 20
    c.httpCookieStorage = .shared
    c.httpCookieAcceptPolicy = .always
    return URLSession(configuration: c)
  }()

  private func post(_ path: String, _ body: [String: Any], timeout: TimeInterval = 18) async -> (Int, Data)? {
    var req = URLRequest(url: Self.base.appendingPathComponent(path))
    req.httpMethod = "POST"
    req.timeoutInterval = timeout
    req.setValue("application/json", forHTTPHeaderField: "Content-Type")
    req.httpBody = try? JSONSerialization.data(withJSONObject: body)
    do {
      let (d, r) = try await session.data(for: req)
      return ((r as? HTTPURLResponse)?.statusCode ?? 0, d)
    } catch { return nil }
  }

  func health() async {
    if forcedOffline { mode = .offline; reason = "forced"; return }
    var req = URLRequest(url: Self.base.appendingPathComponent("api/health"))
    req.cachePolicy = .reloadIgnoringLocalCacheData
    req.timeoutInterval = 8
    guard let res = try? await session.data(for: req), let code = (res.1 as? HTTPURLResponse)?.statusCode else { mode = .offline; reason = "no_net"; return }
    let d = res.0
    guard code == 200, let j = try? JSONSerialization.jsonObject(with: d) as? [String: Any] else { mode = .offline; reason = code == 401 ? "locked" : "no_worker"; return }
    let live = j["live"] as? Bool ?? false
    mode = live ? .live : .offline; reason = live ? "" : "no_key"
    tts = j["tts"] as? Bool ?? false
  }

  /// 內部測試碼（網頁同一組）。回傳是否解鎖成功。
  func unlock(code: String) async -> Bool {
    var req = URLRequest(url: Self.base.appendingPathComponent("__unlock"))
    req.httpMethod = "POST"
    req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
    let enc = code.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? ""
    req.httpBody = "pw=\(enc)&next=%2Fapi%2Fhealth".data(using: .utf8)
    _ = try? await session.data(for: req)
    await health()
    return mode == .live || reason == "no_key"
  }

  enum LLMResult { case data(Data), safety(String), offline }

  /// kind=chat/report。回 Worker 的 data（JSON），安全旗標，或 offline（呼叫端改用離線劇本）。
  func llm(_ req: [String: Any]) async -> LLMResult {
    guard mode == .live, !forcedOffline else { return .offline }
    var body = req; body["pid"] = Saves.pid
    guard let res = await post("api/llm", body, timeout: (req["kind"] as? String) == "report" ? 30 : 16),
          let j = try? JSONSerialization.jsonObject(with: res.1) as? [String: Any] else { return .offline }
    let code = res.0
    if j["ok"] as? Bool == true {
      if let s = j["safety"] as? String { return .safety(s) }
      if let data = j["data"], let out = try? JSONSerialization.data(withJSONObject: data) { return .data(out) }
    } else if let e = j["error"] as? String {
      if e.hasPrefix("cap_") { mode = .offline; reason = e }
      if code == 401 { mode = .offline; reason = "locked" }
    }
    return .offline
  }

  /// Google 語音（MP3）。失敗回 nil；429／503 代表這一輪都不會有。
  func ttsAudio(text: String, bt: Bartender, lang: Lang) async -> (Data?, Bool) {
    guard tts, mode == .live else { return (nil, true) }
    let body: [String: Any] = ["gender": bt.gender, "ageBand": bt.ageBand, "id": bt.id, "lang": lang.rawValue, "text": text, "pid": Saves.pid]
    guard let res = await post("api/tts", body, timeout: 15) else { return (nil, false) }
    let (code, d) = res
    if code == 200, d.count > 200 { return (d, false) }
    return (nil, code == 429 || code == 503)
  }
}

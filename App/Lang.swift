import Foundation

/// 五種語言：繁中、英、日、韓、西。第一次開依手機語言（zh* → 中文，ja/ko/es → 該語言，其他 → 英文），之後照玩家選的。
enum Lang: String, CaseIterable, Identifiable, Codable {
  case zh, en, ja, ko, es
  var id: String { rawValue }
  var name: String { ["zh": "中文", "en": "English", "ja": "日本語", "ko": "한국어", "es": "Español"][rawValue]! }
  var locale: String { ["zh": "zh-TW", "en": "en-US", "ja": "ja-JP", "ko": "ko-KR", "es": "es-ES"][rawValue]! }
  /// 中日不用空白分句，英韓西用
  var sep: String { self == .zh || self == .ja ? "" : " " }
  var listSep: String { self == .zh || self == .ja ? "、" : ", " }

  static func fromDevice() -> Lang {
    for id in Locale.preferredLanguages {
      let code = id.lowercased()
      if code.hasPrefix("zh") { return .zh }
      if code.hasPrefix("ja") { return .ja }
      if code.hasPrefix("ko") { return .ko }
      if code.hasPrefix("es") { return .es }
      if code.hasPrefix("en") { return .en }
    }
    return .en
  }
}

/// 介面字串：原文（繁中）當 key，翻譯來自核心（網頁的 ui 翻譯表＋native_strings.json）。
enum Strings {
  static var lang: Lang = .zh
  private static var cache: [Lang: [String: String]] = [:]
  private static let cacheLock = NSLock()

  static func t(_ s: String) -> String {
    if lang == .zh { return s }
    cacheLock.lock()
    if let hit = cache[lang]?[s] { cacheLock.unlock(); return hit }
    cacheLock.unlock()
    let out = Core.call("t", ["s": s, "lang": lang.rawValue], as: String.self) ?? s
    cacheLock.lock(); cache[lang, default: [:]][s] = out; cacheLock.unlock()
    return out
  }
}

/// L("讓{name}幫我調", ["name": "小茉"])
func L(_ s: String, _ vars: [String: Any] = [:]) -> String {
  var o = Strings.t(s)
  for (k, v) in vars { o = o.replacingOccurrences(of: "{\(k)}", with: "\(v)") }
  return o
}

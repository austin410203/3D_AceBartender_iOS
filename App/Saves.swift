import Foundation

/// 存檔（UserDefaults JSON）：設定、這一攤、酒譜本、統計、小記、我家酒櫃。欄位和網頁版一樣。
struct Settings: Codable {
  var voice = true
  var bartender = "mei"
  var lang: Lang? = nil
  var age = false
  var zeroOnly = false
  var labCode: String? = nil
}

struct Msg: Codable, Hashable, Identifiable {
  var id = UUID()
  var who: String   // me / bt / sys / drink
  var text: String
  enum CodingKeys: String, CodingKey { case who, text }
}

struct Current: Codable, Hashable { var id: String; var tweak: Tweak? }

struct Visit: Codable {
  var v = 1
  var bartender: String
  var started = Date().timeIntervalSince1970
  var chat: [Msg] = []
  var current: Current? = nil
  var served: [String] = []
  var tr: [Msg] = []
  var tweaks: [String: Tweak] = [:]
  var paid = false
}

struct SavedInfo: Codable { var at: Double; var by: String; var tweak: Tweak? }
struct Book: Codable { var saved: [String: SavedInfo] = [:]; var made: [String: Int] = [:] }
struct Stats: Codable { var drinks = 0; var nights = 0; var byBt: [String: Int] = [:]; var recent: [String: [String]] = [:] }

struct NightTab: Codable, Identifiable, Hashable {
  var no: Int
  var at: Double
  var bartender: String
  var drinks: [String]
  var ids: [String]
  var report: TabReport
  var live: Bool
  var id: Double { at }
}

enum Saves {
  private static let d = UserDefaults.standard
  static func load<T: Decodable>(_ key: String, _ fallback: T) -> T {
    guard let data = d.data(forKey: "bar." + key), let v = try? JSONDecoder().decode(T.self, from: data) else { return fallback }
    return v
  }
  static func save<T: Encodable>(_ key: String, _ value: T?) {
    guard let value else { d.removeObject(forKey: "bar." + key); return }
    if let data = try? JSONEncoder().encode(value) { d.set(data, forKey: "bar." + key) }
  }
  /// 玩家 id（隨機，只給 Worker 算每日次數）
  static var pid: String {
    if let p = d.string(forKey: "bar.pid") { return p }
    let p = UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased().prefix(24)
    d.set(String(p), forKey: "bar.pid"); return String(p)
  }
  static func wipeForTests() { for k in ["settings", "visit", "book", "stats", "tabs", "pantry"] { d.removeObject(forKey: "bar." + k) } }
}

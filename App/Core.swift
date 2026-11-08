import Foundation
import JavaScriptCore

/// 規則核心：網頁版的酒譜、推薦、離線劇本、翻譯（Data/core.js）在 JavaScriptCore 裡跑。
/// Swift 只呼叫 BarCore.call(名稱, 參數 JSON)，回 {"ok":true,"v":…}。核心是同步、單執行緒，所以加鎖。
enum Core {
  private static let lock = NSLock()
  private static let ctx: JSContext = {
    let c = JSContext()!
    c.exceptionHandler = { _, e in print("NATIVE core js exception: \(e?.toString() ?? "?")") }
    if let url = Bundle.main.url(forResource: "core", withExtension: "js", subdirectory: "Data"),
       let src = try? String(contentsOf: url, encoding: .utf8) {
      c.evaluateScript(src, withSourceURL: url)
    } else {
      print("NATIVE core.js missing from the bundle")
    }
    return c
  }()

  static func warmUp() { lock.lock(); _ = ctx; lock.unlock() }

  static func raw(_ name: String, _ args: [String: Any] = [:]) -> Data? {
    guard JSONSerialization.isValidJSONObject(args),
          let json = try? JSONSerialization.data(withJSONObject: args),
          let s = String(data: json, encoding: .utf8) else { print("NATIVE core bad args for \(name)"); return nil }
    lock.lock(); defer { lock.unlock() }
    guard let core = ctx.objectForKeyedSubscript("BarCore"), !core.isUndefined,
          let out = core.invokeMethod("call", withArguments: [name, s]), let str = out.toString() else { return nil }
    return str.data(using: .utf8)
  }

  private struct Env<T: Decodable>: Decodable { let ok: Bool; let v: T?; let error: String? }

  static func call<T: Decodable>(_ name: String, _ args: [String: Any] = [:], as type: T.Type = T.self) -> T? {
    guard let d = raw(name, args) else { return nil }
    do {
      let e = try JSONDecoder().decode(Env<T>.self, from: d)
      if !e.ok { print("NATIVE core \(name) error: \(e.error ?? "?")") }
      return e.v
    } catch {
      print("NATIVE core \(name) decode error: \(error)")
      return nil
    }
  }
}

// MARK: - 資料模型（和 native/core/entry.js 的輸出一一對應）

struct Tweak: Codable, Hashable {
  var sweet = 0, sour = 0, strength = 0
  var swaps: [String] = []
  var dict: [String: Any] { ["sweet": sweet, "sour": sour, "strength": strength, "swaps": swaps] }
  var isEmpty: Bool { sweet == 0 && sour == 0 && strength == 0 && swaps.isEmpty }
}

struct GlassArt: Codable, Hashable { let glass: String; let color: String; let ice: Bool; let fizzy: Bool; let garnish: String }
struct Ingredient: Codable, Hashable { let n: String; let ml: Double?; let amt: String?; let role: String; let color: String
  var amount: String { if let ml { return ml == ml.rounded() ? "\(Int(ml)) ml" : String(format: "%.1f ml", ml) }; return amt ?? "" }
}
struct InfusionInfo: Codable, Hashable { let what, ratio, time, strain, keep, warn: String }
struct SourceInfo: Codable, Hashable { let label: String; let url: String }
struct MakeInfo: Codable, Hashable { let tools: [String]; let steps: [String] }

struct Recipe: Codable, Identifiable, Hashable {
  let id, name, en, nameZh, cat, catLabel, base, baseLabel: String
  let tags: [String]
  let str, level: Int
  let color, glass, glassLabel, ice, tech, techLabel: String
  let ingredients: [Ingredient]
  let steps: [String]
  let garnish, home, why, zero, note: String
  let source: SourceInfo
  let official, inspired, orig, tweaked: Bool
  let tweak: Tweak?
  let changes: [String]
  let infusion: InfusionInfo?
  let alcoholic: Bool
  let art: GlassArt
  let firstMain: String
  let make: MakeInfo
}

struct ListRow: Codable, Identifiable, Hashable {
  let id, name, en, cat, base: String
  let inspired, alcoholic: Bool
  let art: GlassArt
  let tags: [String]
  let find: String
}

struct Spec: Codable, Hashable { let cats, tags, avoid: [String]; let str: Int; let strLabel: String; let signature: [String] }
struct Bartender: Codable, Identifiable, Hashable {
  let id, name, title, blurb: String
  let age: Int
  let gender, ageBand: String
  let img: [String: String]
  let bio: String
  let spec: Spec
  func image(_ mood: String) -> String { img[mood] ?? img["smile"] ?? "\(id)_smile" }
}

struct KV: Codable, Hashable { let k: String; let label: String }
struct PantryItem: Codable, Hashable, Identifiable { let id: String; let name: String }
struct Basic: Codable, Hashable { let k: String; let v: String }
struct Chip: Codable, Hashable { let label: String; let text: String }
struct Meta: Codable {
  let cats, bases: [KV]
  let pantry: [PantryItem]
  let basics: [Basic]
  let infusionRules: [String]
  let btIds: [String]
  let waterAfter, textMax, total: Int
  let chips: [String: [Chip]]
  static let empty = Meta(cats: [], bases: [], pantry: [], basics: [], infusionRules: [], btIds: [], waterAfter: 3, textMax: 120, total: 0, chips: [:])
}

struct ChatOut: Codable {
  var player_distress: Bool?
  var drink_safety: String?
  var intent: String?
  var recipe_id: String?
  var tweak: Tweak?
  var mood: String?
  var line: String
}

struct TabReport: Codable, Hashable {
  var headline: String
  var summary: String
  var note: String?
  var taste: String?
  var best_line: String?
  var next_id: String?
}

struct HelpInfo: Codable { let title, lead: String; let items: [[String]]; let emergency, note, stop: String }
struct NextBottle: Codable { let name: String; let gain: Int }
struct CabinetInfo: Codable { let can: [String]; let next: NextBottle? }

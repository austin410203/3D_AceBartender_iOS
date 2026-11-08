import Foundation
import SwiftUI

/// 畫面流程（照網頁 game.js）：門口（選 Bartender）→ 吧台（點酒、說口感、聊天）→ 酒譜卡 → 結帳（今晚喝過的圖文清單）。
@MainActor
final class Bar: ObservableObject {
  enum Screen { case title, bar, checkout }
  enum Sheet: Identifiable, Equatable {
    case recipe(String, Tweak?), list, book, cabinet, basics, pick, menu, help, about, howto, age, lab
    var id: String {
      switch self {
      case .recipe(let i, let t): return "recipe-\(i)-\(t?.sweet ?? 9)\(t?.sour ?? 9)\(t?.strength ?? 9)\(t?.swaps.joined() ?? "")"
      default: return "\(self)"
      }
    }
  }

  @Published var screen: Screen = .title
  @Published var sheet: Sheet?
  @Published var lang: Lang
  @Published var settings: Settings
  @Published var visit: Visit?
  @Published var book: Book
  @Published var stats: Stats
  @Published var tabs: [NightTab]
  @Published var pantry: [String]
  @Published var meta = Meta.empty
  @Published var bartenders: [Bartender] = []
  @Published var list: [ListRow] = []
  // 吧台畫面狀態
  @Published var busy = false
  @Published var busyText = ""
  @Published var bubble: String?
  @Published var mood = "smile"
  @Published var shaking = false
  @Published var making: (tools: [String], text: String, progress: Double)?
  @Published var input = ""
  @Published var toast: String?
  @Published var curTab: NightTab?
  @Published var tabLoading = false
  @Published var netMode: Net.Mode = .unknown
  @Published var pickSel = "mei"
  var lastLive = false
  private var bubbleTask: Task<Void, Never>?
  private var toastTask: Task<Void, Never>?
  let fast: Bool

  init(fast: Bool = false) {
    self.fast = fast
    let s = Saves.load("settings", Settings())
    settings = s
    lang = s.lang ?? Lang.fromDevice()
    visit = Saves.load("visit", Visit?.none)
    book = Saves.load("book", Book())
    stats = Saves.load("stats", Stats())
    tabs = Saves.load("tabs", [NightTab]())
    pantry = Saves.load("pantry", [String]())
    Strings.lang = lang
    Voice.shared.on = s.voice
    reloadLang()
  }

  // MARK: 語言
  func setLang(_ l: Lang) {
    lang = l; Strings.lang = l; settings.lang = l; saveSettings()
    Voice.shared.stop(); Voice.shared.beginConversation()
    reloadLang()
  }
  func reloadLang() {
    meta = Core.call("meta", ["lang": lang.rawValue], as: Meta.self) ?? .empty
    bartenders = Core.call("bartenders", ["lang": lang.rawValue], as: [Bartender].self) ?? []
    list = Core.call("list", ["lang": lang.rawValue], as: [ListRow].self) ?? []
  }

  // MARK: 小工具
  func saveSettings() { Saves.save("settings", settings) }
  func persist() { Saves.save("visit", visit) }
  func bt(_ id: String) -> Bartender? { bartenders.first { $0.id == id } }
  var who: Bartender? { bt(visit?.bartender ?? settings.bartender) ?? bartenders.first }
  func recipe(_ id: String, _ tweak: Tweak? = nil) -> Recipe? {
    var a: [String: Any] = ["id": id, "lang": lang.rawValue]
    if let tweak { a["tweak"] = tweak.dict }
    return Core.call("recipe", a, as: Recipe.self)
  }
  func tweakIn(_ id: String) -> Tweak? { visit?.tweaks[id] }
  var current: Recipe? { visit?.current.flatMap { recipe($0.id, $0.tweak) } }
  func rapport(_ id: String) -> String { Core.call("rapport", ["n": stats.byBt[id] ?? 0, "lang": lang.rawValue], as: String.self) ?? "" }
  func showToast(_ t: String) {
    toast = t; toastTask?.cancel()
    toastTask = Task { try? await Task.sleep(nanoseconds: 2_300_000_000); if !Task.isCancelled { toast = nil } }
  }
  private func wait(_ ms: UInt64) async { try? await Task.sleep(nanoseconds: (fast ? min(ms, 30) : ms) * 1_000_000) }

  func boot() async {
    Core.warmUp()
    await Net.shared.health()
    netMode = Net.shared.mode
    Voice.shared.beginConversation()
  }

  // MARK: 門口
  func start() {
    if !settings.age { sheet = .age; return }
    enter()
  }
  func ageOK(zero: Bool) { settings.age = true; settings.zeroOnly = zero; saveSettings(); sheet = nil; enter() }
  func endOldVisit() { visit = nil; persist() }

  func enter() {
    if var v = visit, v.v == 1, !v.served.isEmpty || !v.chat.isEmpty {
      if v.bartender != settings.bartender {
        v.bartender = settings.bartender
        v.chat.append(Msg(who: "sys", text: L("── {name}接手 ──", ["name": bt(settings.bartender)?.name ?? ""])))
      }
      visit = v
    } else {
      var v = Visit(bartender: settings.bartender)
      let g = Core.call("greet", ["bt": settings.bartender, "lang": lang.rawValue], as: String.self) ?? ""
      v.chat.append(Msg(who: "bt", text: g))
      if settings.zeroOnly { v.chat.append(Msg(who: "sys", text: L("今晚只看無酒精酒單。"))) }
      visit = v
    }
    Voice.shared.stop(); Voice.shared.beginConversation()
    screen = .bar; mood = "smile"; persist()
    if let line = visit?.chat.last(where: { $0.who == "bt" })?.text { say(line, "smile") }
  }

  func goHome() { Voice.shared.stop(); persist(); sheet = nil; screen = .title }

  // MARK: 換人
  func switchBt(_ id: String) {
    sheet = nil
    guard var v = visit, id != v.bartender else { return }
    Voice.shared.stop()
    v.bartender = id; settings.bartender = id; saveSettings()
    let name = bt(id)?.name ?? ""
    v.chat.append(Msg(who: "sys", text: L("── {name}接手 ──", ["name": name])))
    let g = Core.call("greet", ["bt": id, "lang": lang.rawValue], as: String.self) ?? ""
    v.chat.append(Msg(who: "bt", text: g))
    visit = v; persist(); say(g, "smile")
  }

  // MARK: 說話泡泡＋聲音
  func say(_ text: String, _ m: String = "talk") {
    mood = m == "concern" ? "concern" : "talk"
    bubble = text
    bubbleTask?.cancel()
    let concern = m == "concern"
    bubbleTask = Task { try? await Task.sleep(nanoseconds: fast ? 60_000_000 : 9_000_000_000); if !Task.isCancelled { bubble = nil; if !concern { mood = "smile" } } }
    if let b = who { Voice.shared.speak(text, b, lang) }
  }

  // MARK: 點酒：一律走這裡
  func send(_ raw: String, orderId: String = "") async {
    let text = String(raw.trimmingCharacters(in: .whitespacesAndNewlines).prefix(meta.textMax))
    guard !text.isEmpty, !busy, var v = visit else { return }
    Voice.shared.stop()
    input = ""
    if Core.call("crisis", ["text": text], as: Bool.self) == true {
      let h = Core.call("help", ["lang": lang.rawValue], as: HelpInfo.self)
      v.chat.append(Msg(who: "me", text: L("（訊息已收回）")))
      v.chat.append(Msg(who: "bt", text: h?.stop ?? ""))
      visit = v; persist(); sheet = .help; return
    }
    v.chat.append(Msg(who: "me", text: text)); v.tr.append(Msg(who: "me", text: String(text.prefix(160))))
    visit = v
    busy = true; busyText = L("{name}想一下…", ["name": who?.name ?? ""])
    let hist = v.chat.filter { $0.who == "me" || $0.who == "bt" }.dropLast().suffix(6).map { ["who": $0.who, "text": $0.text] }
    let served = Core.call("servedAlcohol", ["served": v.served], as: Int.self) ?? 0
    let req: [String: Any] = [
      "kind": "chat", "bartender": v.bartender, "lang": lang.rawValue, "text": text, "hist": Array(hist),
      "current": v.current?.id ?? "", "served": v.served, "servedAlcohol": served, "pantry": pantry, "zeroOnly": settings.zeroOnly,
      "order_id": orderId, "recent": stats.recent[v.bartender] ?? [], "seed": Int.random(in: 0..<1_000_000_000),
    ]
    var out: ChatOut?
    var live = false
    switch await Net.shared.llm(req) {
    case .safety:
      busy = false
      let h = Core.call("help", ["lang": lang.rawValue], as: HelpInfo.self)
      visit?.chat.append(Msg(who: "bt", text: h?.stop ?? "")); persist(); sheet = .help; return
    case .data(let d):
      out = try? JSONDecoder().decode(ChatOut.self, from: d); live = out != nil
    case .offline: break
    }
    netMode = Net.shared.mode
    if out == nil || out!.line.trimmingCharacters(in: .whitespaces).isEmpty {
      await wait(450)
      out = Core.call("chat", ["req": req], as: ChatOut.self)
    }
    guard var d = out else { busy = false; return }
    // 用戶端再驗一次：id 不在酒譜就退回離線判斷；從酒單按的一定是那一杯；只看無酒精不會拿到有酒的
    if let id = d.recipe_id, !id.isEmpty, Core.call("exists", ["id": id], as: Bool.self) != true { d = Core.call("chat", ["req": req], as: ChatOut.self) ?? d }
    if !orderId.isEmpty, let id = d.recipe_id, !id.isEmpty, (d.drink_safety ?? "ok") == "ok", !settings.zeroOnly { d.recipe_id = orderId }
    if let id = d.recipe_id, !id.isEmpty, settings.zeroOnly, Core.call("isAlcoholic", ["id": id], as: Bool.self) == true {
      d.recipe_id = Core.call("zeroPick", ["text": text, "bt": v.bartender, "served": v.served], as: String.self)
    }
    lastLive = live
    if let id = d.recipe_id, !id.isEmpty { await serve(id, d.tweak, d.line, d.mood ?? "talk") }
    else {
      visit?.chat.append(Msg(who: "bt", text: d.line)); visit?.tr.append(Msg(who: "bt", text: String(d.line.prefix(160))))
      busy = false; persist(); say(d.line, d.mood ?? "talk")
    }
  }

  private func serve(_ id: String, _ tweakIn: Tweak?, _ line: String, _ m: String) async {
    let clean = tweakIn.flatMap { t in t.isEmpty ? nil : Core.call("cleanTweak", ["id": id, "tweak": t.dict], as: Tweak.self) }
    guard let r = recipe(id, clean), let b = who else { busy = false; return }
    let same = visit?.current?.id == r.id
    busy = true; busyText = L("{who}正在調{name}…", ["who": b.name, "name": r.name])
    bubble = nil; mood = "act"; shaking = true
    // 調酒動畫：Bartender 換動作、工具輪流跳、進度條
    for (i, step) in r.make.steps.enumerated() {
      withAnimation(.easeInOut(duration: 0.25)) { making = (r.make.tools, "\(r.name)：\(step)", Double(i + 1) / Double(r.make.steps.count)) }
      await wait(700)
    }
    making = nil; shaking = false
    guard var v = visit else { busy = false; return }
    if !same { v.served.append(r.id) }
    if let t = r.tweak { v.tweaks[r.id] = t } else { v.tweaks.removeValue(forKey: r.id) }
    v.current = Current(id: r.id, tweak: r.tweak)
    v.chat.append(Msg(who: "bt", text: line))
    v.tr.append(Msg(who: "bt", text: String(line.prefix(160))))
    v.tr.append(Msg(who: "drink", text: r.name + (r.tweaked ? "（\(L("微調版"))）" : "")))
    if !same {
      stats.drinks += 1; stats.byBt[b.id, default: 0] += 1
      stats.recent[b.id] = Array(([r.id] + (stats.recent[b.id] ?? []).filter { $0 != r.id }).prefix(12))
      Saves.save("stats", stats)
    }
    visit = v; busy = false; persist()
    say(line, m == "concern" ? "concern" : "talk")
    // 不限杯數（老闆指定），第 3 杯有酒的時候只提醒一次，不擋人
    let alc = Core.call("servedAlcohol", ["served": v.served], as: Int.self) ?? 0
    if alc == meta.waterAfter, r.alcoholic, !same {
      visit?.chat.append(Msg(who: "sys", text: L("{name}幫你倒了一杯水。慢慢喝，不用趕。", ["name": b.name]))); persist()
    }
  }

  func order(_ id: String) {
    sheet = nil
    let name = Core.call("name", ["id": id, "lang": lang.rawValue], as: String.self) ?? id
    Task { await send(L("我要一杯{name}", ["name": name]), orderId: id) }
  }
  func ask(_ text: String, about id: String) {
    sheet = nil
    if visit?.current?.id != id { visit?.current = Current(id: id, tweak: tweakIn(id)) }
    Task { await send(text) }
  }

  // MARK: 酒譜本
  func isSaved(_ id: String) -> Bool { book.saved[id] != nil }
  func toggleSave(_ id: String, tweak: Tweak?, force: Bool = false) {
    if book.saved[id] != nil && !force { book.saved.removeValue(forKey: id) }
    else if book.saved[id] == nil { book.saved[id] = SavedInfo(at: Date().timeIntervalSince1970 * 1000, by: visit?.bartender ?? "", tweak: tweak) }
    Saves.save("book", book)
  }
  func markMade(_ id: String, tweak: Tweak?) {
    book.made[id, default: 0] += 1
    if book.saved[id] == nil { book.saved[id] = SavedInfo(at: Date().timeIntervalSince1970 * 1000, by: visit?.bartender ?? "", tweak: tweak) }
    Saves.save("book", book)
    showToast(L("記下來了，下次跟 Bartender 說說味道"))
  }
  func setPantry(_ ids: [String]) { pantry = ids; Saves.save("pantry", pantry) }

  // MARK: 結帳：今晚喝過的圖文清單，每杯可以存、分享、匯出；也可以回吧台，或結束本輪回門口
  var tonight: [Recipe] {
    guard let v = visit else { return [] }
    let tw = v.tweaks.mapValues { $0.dict }
    return Core.call("recipes", ["ids": v.served, "tweaks": tw, "lang": lang.rawValue], as: [Recipe].self) ?? []
  }

  func pay() {
    guard !busy, let v = visit, let b = who else { return }
    Voice.shared.stop()
    screen = .checkout; curTab = nil; tabLoading = true
    Task {
      let drinks = v.served
      let req: [String: Any] = ["kind": "report", "bartender": b.id, "lang": lang.rawValue, "drinks": drinks, "served": drinks, "pantry": pantry,
                                "history": v.tr.suffix(30).map { ["who": $0.who, "text": $0.text] }]
      var rep: TabReport?
      var live = false
      if case .data(let d) = await Net.shared.llm(req) { rep = try? JSONDecoder().decode(TabReport.self, from: d); live = rep != nil }
      if rep == nil { await wait(400); rep = Core.call("report", ["req": req], as: TabReport.self) }
      let report = rep ?? TabReport(headline: L("今晚小記"), summary: "")
      let again = visit?.paid ?? false
      if !again { stats.nights += 1; Saves.save("stats", stats) }
      let names = drinks.compactMap { Core.call("name", ["id": $0, "lang": lang.rawValue], as: String.self) }
      let tab = NightTab(no: max(stats.nights, 1), at: Date().timeIntervalSince1970 * 1000, bartender: b.id, drinks: names, ids: drinks, report: report, live: live)
      tabs = Array(([tab] + (again ? Array(tabs.dropFirst()) : tabs)).prefix(30))
      Saves.save("tabs", tabs)
      visit?.paid = true; persist()
      curTab = tab; tabLoading = false
    }
  }
  func backToBar() { screen = .bar }
  func endRound() { Voice.shared.stop(); visit = nil; persist(); curTab = nil; bubble = nil; screen = .title }

  // MARK: 設定
  func toggleVoice() { settings.voice.toggle(); Voice.shared.on = settings.voice; if !settings.voice { Voice.shared.stop() }; saveSettings() }
  func toggleZero() { settings.zeroOnly.toggle(); saveSettings() }
  func unlockLab(_ code: String) async -> Bool {
    let ok = await Net.shared.unlock(code: code)
    netMode = Net.shared.mode
    if ok { settings.labCode = "set"; saveSettings(); Voice.shared.beginConversation() }
    return ok
  }
}

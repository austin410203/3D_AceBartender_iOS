import SwiftUI

/// 結帳：今晚小記（LLM 或離線）＋今晚喝過的圖文清單。每杯可存、分享、匯出；全部可一次存、分享、匯出長圖或文字檔。
/// 最後「回吧台繼續喝」或「結束本輪，回到門口」。
struct CheckoutView: View {
  @EnvironmentObject var bar: Bar
  var body: some View {
    let list = bar.tonight
    ScrollView {
      VStack(alignment: .leading, spacing: 14) {
        Text(L("結帳")).font(.system(size: 26, weight: .black)).foregroundStyle(C.hot2).padding(.top, 14)
        reportCard
        Text(L("今晚喝過的調酒（{n} 杯）", ["n": list.count])).font(.system(size: 18, weight: .heavy))
        if list.isEmpty { Text(L("今晚沒有點酒，聊聊也很好。")).foregroundStyle(C.dim) }
        ForEach(Array(list.enumerated()), id: \.offset) { _, r in DrinkCard(r: r) }
        if !list.isEmpty {
          let allSaved = list.allSatisfy { bar.isSaved($0.id) }
          VStack(spacing: 8) {
            Button(allSaved ? L("全部都在酒譜本了") : L("全部存進酒譜本")) { for r in list { bar.toggleSave(r.id, tweak: r.tweak, force: true) }; bar.showToast(L("已存進酒譜本")) }
              .buttonStyle(Soft(on: allSaved, wide: true)).disabled(allSaved)
            HStack(spacing: 8) {
              Button(L("全部分享")) { Share.nightText(list, bar: bar) }.buttonStyle(Soft(wide: true))
              Button(L("匯出圖片")) { Share.nightImage(list, bar: bar) }.buttonStyle(Soft(wide: true))
              Button(L("匯出文字檔")) { Share.nightFile(list, bar: bar) }.buttonStyle(Soft(wide: true))
            }
          }
        }
        if let t = bar.curTab, let id = t.report.next_id, let row = bar.list.first(where: { $0.id == id }) {
          Text(L("下次在家試試")).font(.system(size: 16, weight: .heavy))
          DrinkRow(row: row, orderable: false)
        }
        VStack(spacing: 8) {
          Button(L("回吧台繼續喝")) { bar.backToBar() }.buttonStyle(Soft(wide: true)).accessibilityIdentifier("back")
          Button(L("結束本輪，回到門口")) { bar.endRound() }.buttonStyle(Primary(big: true)).accessibilityIdentifier("endRound")
        }.padding(.top, 6)
        Text(L("飲酒過量，有害健康。禁止酒駕。未滿 18 歲請勿飲酒。")).font(.system(size: 11)).foregroundStyle(C.dim).padding(.bottom, 24)
      }
      .padding(.horizontal, 16)
      .frame(maxWidth: 560)
      .frame(maxWidth: .infinity)
    }
  }

  @ViewBuilder var reportCard: some View {
    if let t = bar.curTab {
      TabCard(t: t)
      HStack(spacing: 8) {
        Button { Share.tabText(t, bar: bar) } label: { IconLabel(icon: "ui/share", text: L("分享小記")) }.buttonStyle(Soft(wide: true))
        Button { Share.tabImage(t, bar: bar) } label: { IconLabel(icon: "ui/download", text: L("下載小記圖片")) }.buttonStyle(Soft(wide: true))
      }
    } else {
      HStack { ProgressView().tint(C.hot2); Text(L("小記撰寫中……")).foregroundStyle(C.dim) }
        .frame(maxWidth: .infinity, minHeight: 120).background(C.panel, in: RoundedRectangle(cornerRadius: 16))
    }
  }
}

/// 今晚小記（紙質）
struct TabCard: View {
  @EnvironmentObject var bar: Bar
  let t: NightTab
  var body: some View {
    let r = t.report, d = Date(timeIntervalSince1970: t.at / 1000)
    VStack(alignment: .leading, spacing: 10) {
      HStack { Text("\(L("今晚小記")) No.\(String(format: "%03d", t.no))"); Spacer(); Text(d.formatted(date: .numeric, time: .omitted)) }
        .font(.system(size: 12, weight: .bold)).foregroundStyle(C.paperDim)
      Text(r.headline).font(.system(size: 22, weight: .black)).foregroundStyle(C.paperInk).fixedSize(horizontal: false, vertical: true)
      Text(r.summary).font(.system(size: 15)).foregroundStyle(C.paperInk).fixedSize(horizontal: false, vertical: true)
      if let taste = r.taste, !taste.isEmpty { Text(taste).font(.system(size: 15, weight: .bold)).foregroundStyle(C.paperInk) }
      if let best = r.best_line, !best.isEmpty {
        VStack(alignment: .leading, spacing: 2) {
          Text("「\(best)」").font(.system(size: 15, weight: .semibold)).foregroundStyle(C.paperInk)
          Text("— " + L("今晚金句（客人原話）")).font(.system(size: 11)).foregroundStyle(C.paperDim)
        }.padding(10).frame(maxWidth: .infinity, alignment: .leading).background(Color(hex: "#efe4cf"), in: RoundedRectangle(cornerRadius: 10))
      }
      if let b = bar.bt(t.bartender) {
        HStack(alignment: .top, spacing: 10) {
          Img.view("cast/" + b.image("smile")).resizable().scaledToFit().frame(width: 58, height: 58).background(Color(hex: "#efe4cf"), in: Circle()).clipShape(Circle())
          VStack(alignment: .leading, spacing: 2) { Text(b.name).font(.system(size: 14, weight: .heavy)); Text("「\(r.note ?? "")」").font(.system(size: 14)).fixedSize(horizontal: false, vertical: true) }
            .foregroundStyle(C.paperInk)
        }
      }
    }
    .padding(16).background(C.paper, in: RoundedRectangle(cornerRadius: 18))
  }
}

/// 結帳清單的一杯
struct DrinkCard: View {
  @EnvironmentObject var bar: Bar
  let r: Recipe
  var body: some View {
    let saved = bar.isSaved(r.id)
    HStack(alignment: .top, spacing: 10) {
      Button { bar.sheet = .recipe(r.id, r.tweak) } label: { GlassView(art: r.art).frame(width: 64, height: 80) }.buttonStyle(.plain)
      VStack(alignment: .leading, spacing: 6) {
        Button { bar.sheet = .recipe(r.id, r.tweak) } label: {
          VStack(alignment: .leading, spacing: 0) { Text(r.name).font(.system(size: 17, weight: .heavy)).foregroundStyle(C.paperInk); Text(r.en).font(.system(size: 12)).foregroundStyle(C.paperDim) }
        }.buttonStyle(.plain)
        Flow(spacing: 4) {
          Badge(text: r.catLabel, kind: "cat")
          if r.tweaked { Badge(text: L("微調版"), kind: "tweak") }
          if r.inspired { Badge(text: L("在家版推估"), kind: "inspired") }
        }
        VStack(spacing: 2) {
          ForEach(Array(r.ingredients.enumerated()), id: \.offset) { _, i in
            HStack { Text(i.n).font(.system(size: 13)); Spacer(); Text(i.amount).font(.system(size: 13, weight: .bold)).monospacedDigit() }.foregroundStyle(C.paperInk)
          }
        }
        HStack(spacing: 6) {
          Button(saved ? L("已在酒譜本") : L("存進酒譜本")) { bar.toggleSave(r.id, tweak: r.tweak) }.buttonStyle(Soft(on: saved, wide: true)).layoutPriority(1)
          Button(L("分享")) { Share.recipeText(r, bar: bar) }.buttonStyle(Soft())
          Button(L("匯出")) { Share.recipeImage(r, bar: bar) }.buttonStyle(Soft())
        }
      }
    }
    .padding(12).background(C.paper, in: RoundedRectangle(cornerRadius: 16))
  }
}

/// 分享：文字（系統分享面板）、圖片（SwiftUI 畫成 1080 寬 PNG）、文字檔
@MainActor
enum Share {
  static func recipeText(_ r: Recipe, bar: Bar) {
    var a: [String: Any] = ["id": r.id, "lang": bar.lang.rawValue]; if let t = r.tweak { a["tweak"] = t.dict }
    ShareSheet.present([Core.call("recipeText", a, as: String.self) ?? r.name])
  }
  static func nightItems(_ list: [Recipe]) -> [[String: Any]] { list.map { r in var d: [String: Any] = ["id": r.id]; if let t = r.tweak { d["tweak"] = t.dict }; return d } }
  static func nightText(_ list: [Recipe], bar: Bar) { ShareSheet.present([Core.call("nightText", ["items": nightItems(list), "lang": bar.lang.rawValue], as: String.self) ?? ""]) }
  static func nightFile(_ list: [Recipe], bar: Bar) { ShareSheet.text(Core.call("nightText", ["items": nightItems(list), "lang": bar.lang.rawValue], as: String.self) ?? "", file: "\(L("今晚喝過的調酒")).txt") }
  static func tabText(_ t: NightTab, bar: Bar) {
    let r = t.report
    let s = "【\(L("今晚小記")) No.\(String(format: "%03d", t.no))】\(r.headline)\n\(r.summary)\n\(r.taste ?? "")\n\(t.drinks.joined(separator: bar.lang.listSep))\n\(bar.bt(t.bartender)?.name ?? "")：「\(r.note ?? "")」" + ((r.best_line ?? "").isEmpty ? "" : "\n\(L("今晚金句（客人原話）"))：「\(r.best_line!)」") + "\n— \(L("王牌酒保"))"
    ShareSheet.present([s])
  }
  private static func render<V: View>(_ v: V, bar: Bar) -> UIImage? {
    let r = ImageRenderer(content: v.environmentObject(bar).frame(width: 360).padding(12).background(C.bg).environment(\.colorScheme, .dark))
    r.scale = 3
    return r.uiImage
  }
  static func recipeImage(_ r: Recipe, bar: Bar) {
    let card = VStack(spacing: 8) {
      RecipeCard(r: r, done: .constant([]), interactive: false)
      footer(bar)
    }
    if let img = render(card, bar: bar) { ShareSheet.present([img]) }
  }
  static func tabImage(_ t: NightTab, bar: Bar) {
    let list = Core.call("recipes", ["ids": t.ids, "lang": bar.lang.rawValue], as: [Recipe].self) ?? []
    let card = VStack(spacing: 10) { TabCard(t: t); ForEach(Array(list.prefix(8).enumerated()), id: \.offset) { _, r in MiniDrink(r: r) }; footer(bar) }
    if let img = render(card, bar: bar) { ShareSheet.present([img]) }
  }
  static func nightImage(_ list: [Recipe], bar: Bar) {
    let card = VStack(spacing: 10) {
      Text(L("今晚喝過的調酒（{n} 杯）", ["n": list.count])).font(.system(size: 20, weight: .heavy)).foregroundStyle(C.hot2)
      if let t = bar.curTab { TabCard(t: t) }
      ForEach(Array(list.prefix(16).enumerated()), id: \.offset) { _, r in MiniDrink(r: r) }
      footer(bar)
    }
    if let img = render(card, bar: bar) { ShareSheet.present([img]) }
    if list.count > 16 { bar.showToast(L("圖片放不下全部，完整內容請匯出文字檔")) }
  }
  @ViewBuilder static func footer(_ bar: Bar) -> some View {
    VStack(spacing: 2) {
      Text(L("王牌酒保")).font(.system(size: 15, weight: .black)).foregroundStyle(C.hot2)
      Text(L("飲酒過量，有害健康。禁止酒駕。未滿 18 歲請勿飲酒。")).font(.system(size: 10)).foregroundStyle(C.dim).multilineTextAlignment(.center)
    }
  }
}

/// 分享圖裡的一杯（小）
struct MiniDrink: View {
  let r: Recipe
  var body: some View {
    HStack(alignment: .top, spacing: 10) {
      GlassView(art: r.art).frame(width: 48, height: 60)
      VStack(alignment: .leading, spacing: 2) {
        Text(r.name).font(.system(size: 15, weight: .heavy))
        Text(r.ingredients.map { "\($0.n) \($0.amount)" }.joined(separator: "・")).font(.system(size: 11.5)).fixedSize(horizontal: false, vertical: true)
      }.foregroundStyle(C.paperInk)
      Spacer(minLength: 0)
    }
    .padding(10).background(C.paper, in: RoundedRectangle(cornerRadius: 12))
  }
}

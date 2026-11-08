import SwiftUI

/// 酒譜卡：原料與比例條、杯型、冰、作法、可勾的步驟、裝飾、在家替代、為什麼這樣配、無酒精版、出處
struct RecipeSheet: View {
  @EnvironmentObject var bar: Bar
  @Environment(\.openURL) private var openURL
  let id: String
  let tweak: Tweak?
  @State private var done: Set<Int> = []
  var body: some View {
    if let r = bar.recipe(id, tweak) {
      ScrollView {
        RecipeCard(r: r, done: $done, interactive: true)
          .padding(14)
        actions(r).padding(.horizontal, 14)
        Text(L("飲酒過量，有害健康。禁止酒駕。未滿 18 歲請勿飲酒。")).font(.system(size: 11)).foregroundStyle(C.dim).padding(.vertical, 18).padding(.horizontal, 14)
      }
      .background(C.bg2)
    } else {
      Text("…").frame(maxWidth: .infinity, maxHeight: .infinity).background(C.bg2)
    }
  }

  @ViewBuilder func actions(_ r: Recipe) -> some View {
    let saved = bar.isSaved(r.id), made = bar.book.made[r.id] ?? 0
    VStack(spacing: 8) {
      HStack(spacing: 8) {
        Button(saved ? L("已在酒譜本") : L("存進酒譜本")) { bar.toggleSave(r.id, tweak: r.tweak) }.buttonStyle(Soft(on: saved, wide: true))
        Button(made > 0 ? L("做過 {n} 次", ["n": made]) : L("我做過了")) { bar.markMade(r.id, tweak: r.tweak) }.buttonStyle(Soft(on: made > 0, wide: true))
      }
      HStack(spacing: 8) {
        Button { Share.recipeImage(r, bar: bar) } label: { IconLabel(icon: "ui/download", text: L("匯出圖片")) }.buttonStyle(Soft(wide: true))
        Button { Share.recipeText(r, bar: bar) } label: { IconLabel(icon: "ui/share", text: L("分享")) }.buttonStyle(Soft(wide: true))
      }
      if bar.visit != nil && bar.screen == .bar {
        Flow(spacing: 8) {
          Button(L("為什麼這樣配？")) { bar.ask(L("這杯為什麼這樣配？"), about: r.id) }.buttonStyle(Soft())
          if !r.firstMain.isEmpty { Button(L("沒有{x}怎麼辦？", ["x": String(r.firstMain.prefix(18))])) { bar.ask(L("家裡沒有{x}怎麼辦？", ["x": r.firstMain]), about: r.id) }.buttonStyle(Soft()) }
          if bar.visit?.current?.id != r.id { Button(L("點這杯")) { bar.order(r.id) }.buttonStyle(Soft(on: true)) }
        }
      }
    }
  }
}

struct RecipeCard: View {
  @EnvironmentObject var bar: Bar
  @Environment(\.openURL) private var openURL
  let r: Recipe
  @Binding var done: Set<Int>
  var interactive: Bool
  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(alignment: .top, spacing: 12) {
        GlassView(art: r.art).frame(width: 86, height: 106)
        VStack(alignment: .leading, spacing: 5) {
          Text(r.name).font(.system(size: 23, weight: .black)).foregroundStyle(C.paperInk).fixedSize(horizontal: false, vertical: true)
          if r.en != r.name { Text(r.en).font(.system(size: 13, weight: .semibold)).foregroundStyle(C.paperDim) }
          Flow(spacing: 5) {
            Badge(text: r.catLabel, kind: "cat")
            if r.official { Badge(text: L("酒吧刊出比例"), kind: "official") }
            if r.inspired { Badge(text: L("在家版推估"), kind: "inspired") }
            if r.orig { Badge(text: L("原創在家版"), kind: "orig") }
            if r.tweaked { Badge(text: L("微調版"), kind: "tweak") }
          }
          if r.str > 0 { HStack(spacing: 6) { Text(L("烈度")).font(.system(size: 12)).foregroundStyle(C.paperDim); StrengthDots(n: r.str, dark: false) } }
          else { Text(L("完全無酒精")).font(.system(size: 12, weight: .bold)).foregroundStyle(Color(hex: "#2f6b45")) }
        }
      }
      Flow(spacing: 5) { ForEach(r.tags, id: \.self) { Badge(text: $0) } }
      if let inf = r.infusion { infusionBox(inf) }
      section(L("原料與比例")) {
        let ml = r.ingredients.filter { ($0.ml ?? 0) > 0 }
        let sum = ml.reduce(0) { $0 + ($1.ml ?? 0) }
        if ml.count > 1 {
          GeometryReader { g in
            HStack(spacing: 1) { ForEach(Array(ml.enumerated()), id: \.offset) { _, i in Rectangle().fill(Color(hex: i.color)).frame(width: max(2, g.size.width * (i.ml ?? 0) / sum - 1)) } }
          }.frame(height: 14).clipShape(RoundedRectangle(cornerRadius: 7))
        }
        VStack(spacing: 0) {
          ForEach(Array(r.ingredients.enumerated()), id: \.offset) { _, i in
            HStack(alignment: .firstTextBaseline) {
              Circle().fill(Color(hex: i.color)).frame(width: 8, height: 8)
              Text(i.n).font(.system(size: 15)).foregroundStyle(C.paperInk).fixedSize(horizontal: false, vertical: true)
              Spacer(minLength: 8)
              Text(i.amount).font(.system(size: 15, weight: .heavy)).foregroundStyle(C.paperInk).monospacedDigit()
            }.padding(.vertical, 6)
            Divider().overlay(Color(hex: "#e2d6c1"))
          }
        }
        if !r.changes.isEmpty { VStack(alignment: .leading, spacing: 3) { ForEach(r.changes, id: \.self) { Text("・" + $0).font(.system(size: 13)).foregroundStyle(C.teal) } } }
        if !bar.pantry.isEmpty {
          let miss = Core.call("missing", ["id": r.id, "have": bar.pantry, "lang": bar.lang.rawValue], as: [String].self) ?? []
          Text(miss.isEmpty ? L("你家的材料今晚就能做。") : L("你家還缺：{list}", ["list": miss.joined(separator: bar.lang.listSep)]))
            .font(.system(size: 13, weight: .semibold)).foregroundStyle(miss.isEmpty ? Color(hex: "#2f6b45") : Color(hex: "#a3541c"))
        }
      }
      HStack(spacing: 8) {
        fact(L("杯型"), r.glassLabel); fact(L("冰"), r.ice); fact(L("作法"), r.techLabel)
      }
      section(L("跟著做（一項一項勾）")) {
        VStack(alignment: .leading, spacing: 8) {
          ForEach(Array(r.steps.enumerated()), id: \.offset) { n, s in
            Button { if interactive { if done.contains(n) { done.remove(n) } else { done.insert(n) } } } label: {
              HStack(alignment: .top, spacing: 10) {
                Image(systemName: done.contains(n) ? "checkmark.square.fill" : "square").font(.system(size: 18)).foregroundStyle(done.contains(n) ? C.ok : C.paperDim)
                Text("\(n + 1). \(s)").font(.system(size: 15)).foregroundStyle(done.contains(n) ? C.paperDim : C.paperInk).strikethrough(done.contains(n)).fixedSize(horizontal: false, vertical: true).multilineTextAlignment(.leading)
                Spacer(minLength: 0)
              }
            }.buttonStyle(.plain)
          }
        }
      }
      text(L("裝飾"), r.garnish)
      text(L("在家替代方案"), r.home)
      text(L("為什麼這樣配"), r.why)
      if r.cat != "zero" { text(L("無酒精版"), r.zero) }
      VStack(alignment: .leading, spacing: 3) {
        if !r.note.isEmpty { Text(r.note).font(.system(size: 12)).foregroundStyle(C.paperDim) }
        if let u = URL(string: r.source.url), !r.source.url.isEmpty {
          Button { openURL(u) } label: { Text("\(L("出處"))：\(r.source.label)").underline() }.font(.system(size: 12)).foregroundStyle(Color(hex: "#8a5a12"))
        } else { Text("\(L("出處"))：\(r.source.label)").font(.system(size: 12)).foregroundStyle(C.paperDim) }
      }
    }
    .padding(16)
    .background(C.paper, in: RoundedRectangle(cornerRadius: 18))
  }
  func infusionBox(_ x: InfusionInfo) -> some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack(spacing: 6) { Img.view("props/jar").resizable().scaledToFit().frame(width: 28, height: 28); Text(L("祕密配方：先泡好 {what}", ["what": x.what])).font(.system(size: 15, weight: .heavy)).foregroundStyle(C.paperInk) }
      Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 10, verticalSpacing: 4) {
        kv(L("比例"), x.ratio); kv(L("時間"), x.time); kv(L("過濾"), x.strain); kv(L("保存"), x.keep)
        if !x.warn.isEmpty { kv(L("注意"), x.warn) }
      }
      Button(L("泡酒安全守則")) { bar.sheet = .basics }.font(.system(size: 13, weight: .semibold)).foregroundStyle(Color(hex: "#8a5a12"))
    }
    .padding(12).background(Color(hex: "#f1e3c4"), in: RoundedRectangle(cornerRadius: 12))
  }
  func kv(_ k: String, _ v: String) -> some View {
    GridRow { Text(k).font(.system(size: 12, weight: .bold)).foregroundStyle(C.paperDim); Text(v).font(.system(size: 14)).foregroundStyle(C.paperInk).fixedSize(horizontal: false, vertical: true) }
  }
  func fact(_ k: String, _ v: String) -> some View {
    VStack(spacing: 2) { Text(k).font(.system(size: 11)).foregroundStyle(C.paperDim); Text(v).font(.system(size: 13, weight: .bold)).foregroundStyle(C.paperInk).multilineTextAlignment(.center).lineLimit(2).minimumScaleFactor(0.7) }
      .frame(maxWidth: .infinity).padding(.vertical, 8).background(Color(hex: "#efe4cf"), in: RoundedRectangle(cornerRadius: 10))
  }
  func section<V: View>(_ title: String, @ViewBuilder _ v: () -> V) -> some View {
    VStack(alignment: .leading, spacing: 8) { Text(title).font(.system(size: 15, weight: .heavy)).foregroundStyle(C.paperInk); v() }
  }
  func text(_ title: String, _ s: String) -> some View {
    section(title) { Text(s).font(.system(size: 15)).foregroundStyle(C.paperInk).fixedSize(horizontal: false, vertical: true) }
  }
}

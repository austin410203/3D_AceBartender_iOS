import SwiftUI

/// 門口：選 Bartender（四張卡＋背景小卡）、推門進去
struct TitleView: View {
  @EnvironmentObject var bar: Bar
  @State private var armedEnd = false
  var body: some View {
    ScrollView {
      VStack(spacing: 12) {
        Text("EMPTY OFFICE").font(.system(size: 11, weight: .heavy)).kerning(3).foregroundStyle(C.dim).padding(.top, 18)
        Text(L("王牌酒保")).font(.system(size: 40, weight: .black)).foregroundStyle(C.hot2).multilineTextAlignment(.center).minimumScaleFactor(0.6)
        Text(L("點一杯，回家自己調。") + "\n" + L("今晚想讓誰幫你調？")).font(.system(size: 15)).foregroundStyle(C.dim).multilineTextAlignment(.center)
        BartenderCards(selected: bar.settings.bartender) { id in bar.settings.bartender = id; bar.saveSettings() }
        if let b = bar.bt(bar.settings.bartender) { ProfileCard(b: b, big: false) }
        Button(startLabel) { bar.start() }.buttonStyle(Primary(big: true)).accessibilityIdentifier("start")
        if !(bar.visit?.served.isEmpty ?? true) {
          Button(armedEnd ? L("再按一次確定") : L("結束上次那一攤（按兩次）")) {
            if armedEnd { bar.endOldVisit(); armedEnd = false } else { armedEnd = true; Task { try? await Task.sleep(nanoseconds: 3_000_000_000); armedEnd = false } }
          }.font(.system(size: 14)).foregroundStyle(armedEnd ? C.red : C.dim)
        }
        HStack(spacing: 8) {
          Button { bar.sheet = .book } label: { IconLabel(icon: "ui/book", text: L("酒譜本")) }.buttonStyle(Soft())
          Button { bar.sheet = .howto } label: { IconLabel(icon: "ui/help", text: L("玩法")) }.buttonStyle(Soft())
          Button { bar.toggleVoice() } label: { IconLabel(icon: bar.settings.voice ? "ui/sound" : "ui/mute", text: bar.settings.voice ? L("語音：開") : L("語音：關")) }.buttonStyle(Soft())
        }
        LangPicker()
        Text(modeLine).font(.system(size: 12)).foregroundStyle(C.dim).multilineTextAlignment(.center)
        Text(L("僅限 18 歲以上。飲酒過量有害健康，禁止酒駕。酒吧和 Bartender 都是虛構的；酒譜可以在家照著做，也都有無酒精版本。"))
          .font(.system(size: 11.5)).foregroundStyle(C.dim.opacity(0.8)).multilineTextAlignment(.center).padding(.bottom, 24)
      }
      .padding(.horizontal, 16)
      .frame(maxWidth: 560)
      .frame(maxWidth: .infinity)
    }
    .scrollIndicators(.hidden)
  }
  var startLabel: String {
    if let n = bar.visit?.served.count, n > 0 { return L("回到吧台（今晚 {n} 杯）", ["n": n]) }
    return L("讓{name}幫我調", ["name": bar.bt(bar.settings.bartender)?.name ?? ""])
  }
  var modeLine: String {
    switch bar.netMode {
    case .unknown: return L("連線中…")
    case .live: return "● " + L("即時 AI 模式") + "：" + L("Bartender 會聽你說話；比例和步驟來自酒譜資料")
    case .offline: return L("離線劇本模式") + "：" + L("靠關鍵字比對酒譜，一樣能點酒")
    }
  }
}

struct IconLabel: View {
  let icon: String; let text: String
  var size: CGFloat = 20
  var body: some View {
    HStack(spacing: 6) { Img.view(icon).resizable().scaledToFit().frame(width: size, height: size); Text(text).lineLimit(1).minimumScaleFactor(0.7) }
  }
}

struct LangPicker: View {
  @EnvironmentObject var bar: Bar
  var body: some View {
    Menu {
      ForEach(Lang.allCases) { l in Button(l.name) { bar.setLang(l) } }
    } label: {
      HStack(spacing: 6) { Image(systemName: "globe"); Text(bar.lang.name); Image(systemName: "chevron.down").font(.system(size: 11)) }
        .font(.system(size: 14)).foregroundStyle(C.ink).padding(.vertical, 8).padding(.horizontal, 12).background(C.panel, in: RoundedRectangle(cornerRadius: 12))
    }
    .accessibilityLabel(L("語言"))
  }
}

struct BartenderCards: View {
  @EnvironmentObject var bar: Bar
  let selected: String
  let onPick: (String) -> Void
  var body: some View {
    HStack(spacing: 8) {
      ForEach(bar.bartenders) { b in
        Button { onPick(b.id) } label: {
          VStack(spacing: 2) {
            Img.view("cast/" + b.image("smile")).resizable().scaledToFit().frame(height: 74)
            Text(b.name).font(.system(size: 14, weight: .heavy)).lineLimit(1).minimumScaleFactor(0.6)
            Text(b.title).font(.system(size: 10.5)).foregroundStyle(C.dim).lineLimit(2).multilineTextAlignment(.center).minimumScaleFactor(0.7)
          }
          .padding(.vertical, 8).padding(.horizontal, 4).frame(maxWidth: .infinity, minHeight: 138)
          .background(b.id == selected ? C.hot.opacity(0.22) : C.panel, in: RoundedRectangle(cornerRadius: 14))
          .overlay(RoundedRectangle(cornerRadius: 14).stroke(b.id == selected ? C.hot : C.line, lineWidth: b.id == selected ? 2 : 1))
        }
        .buttonStyle(.plain).accessibilityIdentifier("bt-\(b.id)")
      }
    }
  }
}

/// 背景小卡：背景故事、最擅長、偏愛的味道、比較少推、烈度、招牌酒（點杯子看酒譜）
struct ProfileCard: View {
  @EnvironmentObject var bar: Bar
  let b: Bartender
  let big: Bool
  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(spacing: 10) {
        if big { Img.view("cast/" + b.image("talk")).resizable().scaledToFit().frame(width: 76, height: 76).background(C.panel, in: Circle()).clipShape(Circle()) }
        VStack(alignment: .leading, spacing: 2) {
          Text(b.name).font(.system(size: 19, weight: .heavy)).foregroundStyle(C.paperInk)
          Text("\(b.title)・\(L("{n} 歲", ["n": b.age]))").font(.system(size: 13)).foregroundStyle(C.paperDim)
        }
      }
      Text(b.bio).font(.system(size: 14)).foregroundStyle(C.paperInk).fixedSize(horizontal: false, vertical: true)
      Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 10, verticalSpacing: 8) {
        row(L("最擅長")) { Flow { ForEach(b.spec.cats, id: \.self) { Badge(text: $0, kind: "cat") } } }
        row(L("偏愛的味道")) { Flow { ForEach(b.spec.tags, id: \.self) { Badge(text: $0) } } }
        if !b.spec.avoid.isEmpty { row(L("比較少推")) { Flow { ForEach(b.spec.avoid, id: \.self) { Badge(text: $0, kind: "dim") } } } }
        row(L("喜歡的烈度")) { HStack { StrengthDots(n: b.spec.str, dark: false); Text(b.spec.strLabel).font(.system(size: 13)).foregroundStyle(C.paperInk) } }
      }
      HStack(alignment: .firstTextBaseline) {
        Text(L("招牌酒")).font(.system(size: 15, weight: .heavy)).foregroundStyle(C.paperInk)
        Text(L("點杯子看酒譜")).font(.system(size: 11)).foregroundStyle(C.paperDim)
      }
      HStack(alignment: .top, spacing: 6) {
        ForEach(b.spec.signature, id: \.self) { id in
          let row = bar.list.first { $0.id == id }
          Button { bar.sheet = .recipe(id, nil) } label: {
            VStack(spacing: 2) {
              if let row { GlassView(art: row.art).frame(height: 54) }
              Text(row?.name ?? id).font(.system(size: 11, weight: .semibold)).foregroundStyle(C.paperInk).multilineTextAlignment(.center).lineLimit(2).minimumScaleFactor(0.7)
            }.frame(maxWidth: .infinity)
          }.buttonStyle(.plain)
        }
      }
    }
    .padding(14)
    .background(C.paper, in: RoundedRectangle(cornerRadius: 16))
  }
  @ViewBuilder func row<V: View>(_ k: String, @ViewBuilder _ v: () -> V) -> some View {
    GridRow {
      Text(k).font(.system(size: 12, weight: .bold)).foregroundStyle(C.paperDim).frame(width: 78, alignment: .leading).lineLimit(2).minimumScaleFactor(0.7)
      v()
    }
  }
}

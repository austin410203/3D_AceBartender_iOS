import SwiftUI

/// 共用的視窗外框：標題＋關閉
struct SheetFrame<Content: View>: View {
  @EnvironmentObject var bar: Bar
  let title: String
  @ViewBuilder let content: () -> Content
  var body: some View {
    VStack(spacing: 0) {
      HStack {
        Text(title).font(.system(size: 20, weight: .heavy)).lineLimit(1).minimumScaleFactor(0.7)
        Spacer()
        Button { bar.sheet = nil } label: { Img.view("ui/close").resizable().scaledToFit().frame(width: 22, height: 22).padding(8).background(C.panel, in: Circle()) }
          .accessibilityLabel(L("關閉"))
      }
      .padding(.horizontal, 16).padding(.top, 18).padding(.bottom, 8)
      content()
    }
    .background(C.bg2)
  }
}

/// 一列酒：杯子、名字、口感、點
struct DrinkRow: View {
  @EnvironmentObject var bar: Bar
  let row: ListRow
  var orderable = true
  var body: some View {
    HStack(spacing: 10) {
      GlassView(art: row.art).frame(width: 40, height: 50)
      Button { bar.sheet = .recipe(row.id, bar.tweakIn(row.id)) } label: {
        VStack(alignment: .leading, spacing: 2) {
          HStack(spacing: 6) {
            Text(row.name).font(.system(size: 15.5, weight: .bold)).foregroundStyle(C.ink).lineLimit(1).minimumScaleFactor(0.75)
            if let m = bar.book.made[row.id] { Text(L("做過 {n}", ["n": m])).font(.system(size: 11, weight: .bold)).foregroundStyle(C.ok) }
            else if bar.isSaved(row.id) { Text(L("收藏")).font(.system(size: 11, weight: .bold)).foregroundStyle(C.hot2) }
          }
          Text(([row.en] + [row.tags.joined(separator: bar.lang.listSep)] + (row.inspired ? [L("在家版推估")] : [])).joined(separator: "・"))
            .font(.system(size: 12)).foregroundStyle(C.dim).lineLimit(1)
        }.frame(maxWidth: .infinity, alignment: .leading)
      }.buttonStyle(.plain)
      if orderable && bar.visit != nil && bar.screen == .bar {
        Button(L("點")) { bar.order(row.id) }.font(.system(size: 14, weight: .heavy)).foregroundStyle(Color(hex: "#24170a"))
          .padding(.horizontal, 14).padding(.vertical, 7).background(C.hot, in: Capsule()).buttonStyle(.plain)
          .accessibilityIdentifier("order-\(row.id)")
      }
    }
    .padding(.vertical, 5)
  }
}

// MARK: 酒單
struct MenuListSheet: View {
  @EnvironmentObject var bar: Bar
  @State private var cat = "all"
  @State private var base = "all"
  @State private var q = ""
  var body: some View {
    SheetFrame(title: L("酒單")) {
      VStack(spacing: 8) {
        TextField(L("搜尋酒名、基酒、口感…"), text: $q).padding(10).background(C.panel, in: RoundedRectangle(cornerRadius: 12)).padding(.horizontal, 16)
        pills(bar.settings.zeroOnly ? bar.meta.cats.filter { $0.k == "zero" } : [KV(k: "all", label: L("全部"))] + bar.meta.cats, sel: $cat)
        pills([KV(k: "all", label: L("所有基酒"))] + bar.meta.bases, sel: $base)
        Text(L("共 {n} 杯", ["n": rows.count])).font(.system(size: 12)).foregroundStyle(C.dim).frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 16)
        List(rows) { r in DrinkRow(row: r).listRowBackground(C.bg2) }.listStyle(.plain).scrollContentBackground(.hidden)
      }
    }
    .onAppear { if bar.settings.zeroOnly { cat = "zero" } }
  }
  var rows: [ListRow] {
    let s = q.trimmingCharacters(in: .whitespaces).lowercased()
    return bar.list.filter { (cat == "all" || $0.cat == cat) && (base == "all" || $0.base == base) && (!bar.settings.zeroOnly || $0.cat == "zero") && (s.isEmpty || $0.find.contains(s)) }
  }
  func pills(_ items: [KV], sel: Binding<String>) -> some View {
    ScrollView(.horizontal) {
      HStack(spacing: 6) {
        ForEach(items, id: \.k) { it in
          Button(it.label) { sel.wrappedValue = it.k }.buttonStyle(Soft(on: sel.wrappedValue == it.k))
        }
      }.padding(.horizontal, 16)
    }.scrollIndicators(.hidden)
  }
}

// MARK: 我的酒譜本
struct BookSheet: View {
  @EnvironmentObject var bar: Bar
  @State private var tab = "saved"
  var body: some View {
    SheetFrame(title: L("我的酒譜本")) {
      VStack(spacing: 8) {
        Text(L("收藏 {a} 杯・做過 {b} 杯・全部 {c} 杯", ["a": bar.book.saved.count, "b": bar.book.made.count, "c": bar.meta.total]))
          .font(.system(size: 12.5)).foregroundStyle(C.dim).frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 16)
        ScrollView(.horizontal) {
          HStack(spacing: 6) {
            ForEach([("saved", "收藏"), ("made", "做過"), ("infusion", "祕密配方"), ("fruit", "水果"), ("wine", "紅白酒"), ("tea", "茶酒"), ("asia", "亞洲名店"), ("nights", "去過的夜晚")], id: \.0) { k, v in
              Button(L(v)) { tab = k }.buttonStyle(Soft(on: tab == k))
            }
          }.padding(.horizontal, 16)
        }.scrollIndicators(.hidden)
        if tab == "nights" { nights } else {
          let ids = tab == "saved" ? bar.book.saved.sorted { $0.value.at > $1.value.at }.map(\.key) : tab == "made" ? Array(bar.book.made.keys) : bar.list.filter { $0.cat == tab }.map(\.id)
          let rows = ids.compactMap { id in bar.list.first { $0.id == id } }
          if rows.isEmpty { empty(L("還沒有。點一杯，打開酒譜卡按「存進酒譜本」。")) }
          else { List(rows) { r in DrinkRow(row: r, orderable: false).listRowBackground(C.bg2) }.listStyle(.plain).scrollContentBackground(.hidden) }
        }
      }
    }
  }
  var nights: some View {
    Group {
      if bar.tabs.isEmpty { empty(L("還沒有。結帳時會留下小記。")) } else {
        List(bar.tabs.prefix(10)) { t in
          VStack(alignment: .leading, spacing: 4) {
            Text(t.report.headline).font(.system(size: 15, weight: .bold))
            Text("\(Date(timeIntervalSince1970: t.at / 1000).formatted(date: .abbreviated, time: .omitted))・\(bar.bt(t.bartender)?.name ?? "")・\(L("{n} 杯", ["n": t.ids.count]))").font(.system(size: 12)).foregroundStyle(C.dim)
            HStack { Button(L("分享")) { Share.tabText(t, bar: bar) }.buttonStyle(Soft()); Button(L("下載圖片")) { Share.tabImage(t, bar: bar) }.buttonStyle(Soft()) }
          }.listRowBackground(C.bg2)
        }.listStyle(.plain).scrollContentBackground(.hidden)
      }
    }
  }
  func empty(_ s: String) -> some View { Text(s).font(.system(size: 14)).foregroundStyle(C.dim).padding(24).frame(maxHeight: .infinity, alignment: .top) }
}

// MARK: 我家酒櫃
struct CabinetSheet: View {
  @EnvironmentObject var bar: Bar
  var body: some View {
    SheetFrame(title: L("我家酒櫃")) {
      let info = Core.call("cabinet", ["have": bar.pantry, "zeroOnly": bar.settings.zeroOnly, "lang": bar.lang.rawValue], as: CabinetInfo.self)
      List {
        Section {
          Text(L("勾你家有的東西，Bartender 推薦時會優先挑你今晚就做得出來的。")).font(.system(size: 13)).foregroundStyle(C.dim)
          LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: 8) {
            ForEach(bar.meta.pantry) { p in
              let on = bar.pantry.contains(p.id)
              Button { bar.setPantry(on ? bar.pantry.filter { $0 != p.id } : bar.pantry + [p.id]) } label: {
                HStack(spacing: 6) { Image(systemName: on ? "checkmark.square.fill" : "square").foregroundStyle(on ? C.hot : C.dim); Text(p.name).font(.system(size: 13.5)).lineLimit(2).minimumScaleFactor(0.8) }
              }.buttonStyle(.plain)
            }
          }
          if let info {
            Text(L("現在能做 {n} 杯。", ["n": info.can.count]) + (info.next.map { L("再買「{x}」可以多做 {n} 杯。", ["x": $0.name, "n": $0.gain]) } ?? ""))
              .font(.system(size: 14, weight: .semibold)).foregroundStyle(C.hot2)
          }
        }.listRowBackground(C.bg2)
        Section {
          ForEach((info?.can ?? []).prefix(30), id: \.self) { id in if let r = bar.list.first(where: { $0.id == id }) { DrinkRow(row: r) } }
        }.listRowBackground(C.bg2)
      }.listStyle(.plain).scrollContentBackground(.hidden)
    }
  }
}

// MARK: 在家調酒小抄
struct BasicsSheet: View {
  @EnvironmentObject var bar: Bar
  var body: some View {
    SheetFrame(title: L("在家調酒小抄")) {
      ScrollView {
        VStack(alignment: .leading, spacing: 12) {
          ScrollView(.horizontal) { HStack { ForEach(["jigger", "shaker", "mixglass", "barspoon", "strainer", "muddler", "jar", "filter", "teapot", "lemon", "ice", "honey"], id: \.self) { Img.view("props/" + $0).resizable().scaledToFit().frame(width: 46, height: 46) } } }.scrollIndicators(.hidden)
          ForEach(bar.meta.basics, id: \.self) { b in
            VStack(alignment: .leading, spacing: 3) { Text(b.k).font(.system(size: 15, weight: .heavy)).foregroundStyle(C.hot2); Text(b.v).font(.system(size: 14)).fixedSize(horizontal: false, vertical: true) }
          }
          Text(L("Infusion 祕密配方：泡酒安全守則")).font(.system(size: 16, weight: .heavy)).padding(.top, 6)
          ForEach(bar.meta.infusionRules, id: \.self) { Text("・" + $0).font(.system(size: 14)).fixedSize(horizontal: false, vertical: true) }
        }.padding(16)
      }
    }
  }
}

// MARK: 換人
struct PickSheet: View {
  @EnvironmentObject var bar: Bar
  var body: some View {
    SheetFrame(title: L("換一位 Bartender")) {
      ScrollView {
        VStack(spacing: 12) {
          BartenderCards(selected: bar.pickSel) { bar.pickSel = $0 }
          if let b = bar.bt(bar.pickSel) { ProfileCard(b: b, big: false) }
          Button(L("請{name}來調", ["name": bar.bt(bar.pickSel)?.name ?? ""])) { bar.switchBt(bar.pickSel) }
            .buttonStyle(Primary(big: true)).disabled(bar.pickSel == bar.visit?.bartender).opacity(bar.pickSel == bar.visit?.bartender ? 0.5 : 1)
        }.padding(16)
      }
    }
    .onAppear { if bar.pickSel.isEmpty { bar.pickSel = bar.visit?.bartender ?? bar.settings.bartender } }
  }
}

// MARK: 關於這位 Bartender
struct AboutSheet: View {
  @EnvironmentObject var bar: Bar
  var body: some View {
    SheetFrame(title: L("關於{name}", ["name": bar.who?.name ?? ""])) {
      ScrollView {
        VStack(spacing: 12) {
          if let b = bar.who { ProfileCard(b: b, big: true) }
          if bar.screen == .bar { Button { bar.pickSel = bar.who?.id ?? "mei"; bar.sheet = .pick } label: { IconLabel(icon: "ui/swap", text: L("換 Bartender")) }.buttonStyle(Soft(wide: true)) }
        }.padding(16)
      }
    }
  }
}

// MARK: 選單
struct MenuSheet: View {
  @EnvironmentObject var bar: Bar
  var body: some View {
    SheetFrame(title: L("選單")) {
      ScrollView {
        VStack(spacing: 8) {
          item("ui/help", L("關於{name}", ["name": bar.who?.name ?? ""])) { bar.sheet = .about }
          item("ui/swap", L("換 Bartender")) { bar.pickSel = bar.visit?.bartender ?? "mei"; bar.sheet = .pick }
          item("ui/help", L("玩法")) { bar.sheet = .howto }
          item(bar.settings.voice ? "ui/sound" : "ui/mute", bar.settings.voice ? L("語音：開") : L("語音：關")) { bar.toggleVoice() }
          item("ui/menu", bar.settings.zeroOnly ? L("只看無酒精：開") : L("只看無酒精：關")) { bar.toggleZero() }
          LangPicker().frame(maxWidth: .infinity, alignment: .leading)
          item("ui/save", L("內部測試碼")) { bar.sheet = .lab }
          item("ui/close", L("回門口（這一攤會保留）")) { bar.goHome() }
          Text(Bundle.main.versionLine).font(.system(size: 11)).foregroundStyle(C.dim).padding(.top, 8)
        }.padding(16)
      }
    }
  }
  func item(_ icon: String, _ text: String, _ act: @escaping () -> Void) -> some View {
    Button(action: act) { IconLabel(icon: icon, text: text, size: 22).frame(maxWidth: .infinity, alignment: .leading) }.buttonStyle(Soft(wide: true))
  }
}

extension Bundle {
  var versionLine: String {
    let v = infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0", b = infoDictionary?["CFBundleVersion"] as? String ?? "1"
    return "\(L("王牌酒保")) \(v) (\(b))・Empty Office"
  }
}

// MARK: 怎麼玩
struct HowToSheet: View {
  @EnvironmentObject var bar: Bar
  var body: some View {
    SheetFrame(title: L("怎麼玩")) {
      ScrollView {
        VStack(alignment: .leading, spacing: 12) {
          step(1, L("選一位 Bartender。"), L("小茉愛茶、阿澈愛玩亞洲新派、蘭姐愛優雅的酸酒、老周愛烈的經典，同一句話他們推的酒不一樣，可以中途換人。"))
          step(2, L("點一杯"), L("：直接說酒名，或打開酒單挑。"))
          step(3, L("祕密配方"), L("：問 Bartender「有什麼祕密配方」，或翻酒單的「祕密配方」。先泡好一瓶 Infusion（鳳梨蘭姆、桂花琴酒、培根波本…），就能一直調。"))
          step(4, L("說口感"), L("：「偏酸」「水果味」「紅酒」「白酒」「威士忌基底」「今天好累」都可以，Bartender 會從酒譜挑一杯給你，也可以微調（少甜、淡一點）。"))
          step(5, L("看酒譜卡"), L("：原料、比例、作法、杯型、裝飾、在家替代方案和無酒精版本都有。可以存進酒譜本、下載圖片、分享。"))
          step(6, L("在家做"), L("：跟著步驟一項一項勾，做完按「我做過了」。「我家酒櫃」勾你有的東西，就知道今晚能做哪些。"))
          step(7, L("追問"), L("：「這杯為什麼這樣配」「家裡沒有蛋白怎麼辦」，都可以問。"))
          Text(L("比例和步驟都來自遊戲內的酒譜資料，不是 AI 現編的。沒有連上 AI 時會用離線劇本，一樣能玩。")).font(.system(size: 13)).foregroundStyle(C.dim)
          Text(L("僅限 18 歲以上。飲酒過量有害健康，禁止酒駕。酒吧和 Bartender 都是虛構的；酒譜可以在家照著做，也都有無酒精版本。")).font(.system(size: 12)).foregroundStyle(C.dim)
        }.padding(16)
      }
    }
  }
  func step(_ n: Int, _ head: String, _ text: String) -> some View {
    HStack(alignment: .top, spacing: 10) {
      Text("\(n)").font(.system(size: 14, weight: .heavy)).foregroundStyle(Color(hex: "#24170a")).frame(width: 24, height: 24).background(C.hot2, in: Circle())
      (Text(head).bold() + Text(text)).font(.system(size: 14.5)).fixedSize(horizontal: false, vertical: true)
    }
  }
}

// MARK: 年齡確認
struct AgeSheet: View {
  @EnvironmentObject var bar: Bar
  var body: some View {
    VStack(spacing: 14) {
      Text(L("你滿 18 歲了嗎？")).font(.system(size: 24, weight: .heavy)).padding(.top, 28)
      Text(L("這是教調酒的遊戲，裡面有酒類配方。依規定僅限 18 歲以上。")).font(.system(size: 15)).multilineTextAlignment(.center)
      Text(L("飲酒過量，有害健康。禁止酒駕。未滿 18 歲請勿飲酒。")).font(.system(size: 13, weight: .semibold)).foregroundStyle(C.warn).multilineTextAlignment(.center)
      Button(L("我已滿 18 歲，進去")) { bar.ageOK(zero: false) }.buttonStyle(Primary(big: true)).accessibilityIdentifier("age18")
      Button(L("未滿 18 歲或今天不喝酒：只看無酒精酒單")) { bar.ageOK(zero: true) }.buttonStyle(Soft(wide: true))
      Spacer()
    }
    .padding(20)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(C.bg2)
    .presentationDetents([.medium, .large])
    .interactiveDismissDisabled()
  }
}

// MARK: 求助
struct HelpSheet: View {
  @EnvironmentObject var bar: Bar
  @Environment(\.openURL) private var openURL
  var body: some View {
    let h = Core.call("help", ["lang": bar.lang.rawValue], as: HelpInfo.self)
    SheetFrame(title: h?.title ?? "") {
      ScrollView {
        VStack(alignment: .leading, spacing: 12) {
          Text(h?.lead ?? "").font(.system(size: 15)).fixedSize(horizontal: false, vertical: true)
          ForEach(h?.items ?? [], id: \.self) { it in
            if it.count >= 4, let u = URL(string: it[3]) {
              Button { openURL(u) } label: {
                VStack(alignment: .leading, spacing: 2) {
                  Text(it[1]).font(.system(size: 22, weight: .heavy)).foregroundStyle(C.hot2)
                  Text(it[0] + (it[2].isEmpty ? "" : "・" + it[2])).font(.system(size: 13)).foregroundStyle(C.ink)
                }.frame(maxWidth: .infinity, alignment: .leading).padding(12).background(C.panel, in: RoundedRectangle(cornerRadius: 12))
              }.buttonStyle(.plain)
            }
          }
          Text(h?.emergency ?? "").font(.system(size: 14, weight: .bold)).foregroundStyle(C.warn)
          Text(h?.note ?? "").font(.system(size: 12)).foregroundStyle(C.dim)
          Button(L("我知道了，繼續")) { bar.sheet = nil }.buttonStyle(Soft(wide: true))
        }.padding(16)
      }
    }
  }
}

// MARK: 內部測試碼（TestFlight 期間連上 AI 用；正式上架前由老闆決定開放方式）
struct LabSheet: View {
  @EnvironmentObject var bar: Bar
  @State private var code = ""
  @State private var state = ""
  var body: some View {
    SheetFrame(title: L("內部測試碼")) {
      VStack(alignment: .leading, spacing: 12) {
        Text(L("輸入內部測試碼，Bartender 就會用即時 AI 回話。沒有測試碼也能玩（離線劇本）。")).font(.system(size: 14)).foregroundStyle(C.dim)
        SecureField(L("內部測試碼"), text: $code).keyboardType(.numberPad).padding(12).background(C.panel, in: RoundedRectangle(cornerRadius: 12))
        Button(L("連線")) {
          state = L("連線中…")
          Task { state = await bar.unlockLab(code) ? L("已連上即時 AI 模式") : L("測試碼不對，或現在連不上") }
        }.buttonStyle(Primary(big: true)).disabled(code.isEmpty)
        Text(state).font(.system(size: 14, weight: .semibold)).foregroundStyle(C.hot2)
        Spacer()
      }.padding(16)
    }
  }
}

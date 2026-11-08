import SwiftUI

/// 吧台：HUD、吧台場景（前後兩層同一張圖夾住 Bartender）、快速按鈕、對話、輸入框、按住說話
struct BarView: View {
  @EnvironmentObject var bar: Bar
  @ObservedObject private var voice = Voice.shared
  @State private var chatOpen = false
  @FocusState private var typing: Bool
  var body: some View {
    VStack(spacing: 8) {
      hud
      BarScene().frame(height: sceneH)
      chips
      chat
      inputRow
      callBar
    }
    .padding(.horizontal, 12)
    .padding(.bottom, 6)
    .frame(maxWidth: 560)
    .frame(maxWidth: .infinity)
    .onTapGesture { typing = false }
  }
  private var sceneH: CGFloat { min(max(UIScreen.main.bounds.height * 0.42, 280), 470) }

  var hud: some View {
    HStack(spacing: 8) {
      Button { bar.sheet = .about } label: {
        VStack(alignment: .leading, spacing: 0) {
          Text(bar.who?.name ?? "").font(.system(size: 17, weight: .heavy)).lineLimit(1)
          Text(bar.rapport(bar.who?.id ?? "")).font(.system(size: 11)).foregroundStyle(C.dim)
        }
      }.buttonStyle(.plain).accessibilityIdentifier("hudWho")
      Spacer()
      stat(L("今晚"), "\(bar.visit?.served.count ?? 0)", L("杯"))
      stat(L("酒譜本"), "\(bar.book.saved.count)", "")
      Button { bar.sheet = .menu } label: { Img.view("ui/gear").resizable().scaledToFit().frame(width: 26, height: 26).padding(8).background(C.panel, in: Circle()) }
        .accessibilityLabel(L("選單")).accessibilityIdentifier("menu")
    }
    .padding(.top, 4)
  }
  func stat(_ a: String, _ n: String, _ b: String) -> some View {
    HStack(alignment: .firstTextBaseline, spacing: 3) {
      Text(a).font(.system(size: 11)).foregroundStyle(C.dim)
      Text(n).font(.system(size: 18, weight: .heavy)).foregroundStyle(C.hot2)
      if !b.isEmpty { Text(b).font(.system(size: 11)).foregroundStyle(C.dim) }
    }
    .padding(.horizontal, 9).padding(.vertical, 5).background(C.panel, in: Capsule())
  }

  var chips: some View {
    let key = bar.settings.zeroOnly ? "zero" : bar.visit?.current != nil ? "drink" : "base"
    return ScrollView(.horizontal) {
      HStack(spacing: 6) {
        ForEach(bar.meta.chips[key] ?? [], id: \.self) { c in
          Button(c.label) { Task { await bar.send(c.text) } }
            .font(.system(size: 13.5)).padding(.horizontal, 12).padding(.vertical, 7)
            .background(C.panel, in: Capsule()).overlay(Capsule().stroke(C.line)).buttonStyle(.plain)
            .disabled(bar.busy)
        }
      }
    }
    .scrollIndicators(.hidden)
  }

  var chat: some View {
    let msgs = bar.visit?.chat ?? []
    let talk = msgs.filter { $0.who != "sys" }.count
    let shown = chatOpen ? msgs : Array(msgs.suffix(3))
    return VStack(spacing: 4) {
      ScrollViewReader { sv in
        ScrollView {
          VStack(spacing: 6) {
            ForEach(shown) { m in Bubble(m: m).id(m.id) }
            if bar.busy && bar.making == nil { HStack { Text("…").padding(.horizontal, 12).padding(.vertical, 6).background(.white, in: RoundedRectangle(cornerRadius: 14)).foregroundStyle(.gray); Spacer() } }
          }.padding(.vertical, 2)
        }
        .frame(maxHeight: chatOpen ? .infinity : 150)
        .onChange(of: msgs.count) { _, _ in if let l = shown.last { withAnimation { sv.scrollTo(l.id, anchor: .bottom) } } }
        .onAppear { if let l = shown.last { sv.scrollTo(l.id, anchor: .bottom) } }
      }
      if talk >= 3 {
        Button(chatOpen ? L("收合對話") : L("展開全部對話（{n}）", ["n": talk])) { withAnimation { chatOpen.toggle() } }
          .font(.system(size: 12)).foregroundStyle(C.dim)
      }
    }
    .frame(maxHeight: .infinity, alignment: .bottom)
  }

  var inputRow: some View {
    HStack(spacing: 8) {
      TextField(L("想喝什麼？酒名、口感都可以"), text: $bar.input, axis: .vertical)
        .lineLimit(1...3).focused($typing).submitLabel(.send)
        .onSubmit { send() }
        .padding(.horizontal, 12).padding(.vertical, 10)
        .background(C.panel, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(C.line))
        .accessibilityIdentifier("input")
      Button { send() } label: { Img.view("ui/send").resizable().scaledToFit().frame(width: 24, height: 24).padding(11).background(C.hot, in: Circle()) }
        .disabled(bar.busy || bar.input.trimmingCharacters(in: .whitespaces).isEmpty).accessibilityLabel(L("送出"))
    }
  }
  func send() { let t = bar.input; typing = false; Task { await bar.send(t) } }

  var callBar: some View {
    HStack {
      Button { bar.sheet = .book } label: { IconLabel(icon: "ui/book", text: L("酒譜本")) }.buttonStyle(Soft()).frame(maxWidth: .infinity, alignment: .leading)
      MicButton()
      Button { bar.pay() } label: { IconLabel(icon: "ui/receipt", text: L("結帳")) }.buttonStyle(Soft(on: !(bar.visit?.served.isEmpty ?? true))).frame(maxWidth: .infinity, alignment: .trailing)
        .accessibilityIdentifier("pay").disabled(bar.busy)
    }
  }
}

/// 按住說話（≥72pt，置中）：放開後字進輸入框，改好再按送出
struct MicButton: View {
  @EnvironmentObject var bar: Bar
  @ObservedObject private var voice = Voice.shared
  @State private var down = false
  var body: some View {
    let on = voice.listening || down
    Img.view("ui/mic").resizable().scaledToFit().frame(width: 40, height: 40)
      .colorMultiply(on ? .white : .white)
      .frame(width: 76, height: 76)
      .background(on ? C.red : Color.white, in: Circle())
      .shadow(color: on ? C.red.opacity(0.6) : .black.opacity(0.4), radius: on ? 16 : 10, y: 6)
      .scaleEffect(on ? 1.08 : 1)
      .opacity(bar.busy ? 0.4 : 1)
      .gesture(DragGesture(minimumDistance: 0)
        .onChanged { _ in if !down && !bar.busy { down = true; start() } }
        .onEnded { _ in down = false; voice.stopListening() })
      .accessibilityLabel(L("按住說話"))
      .accessibilityAddTraits(.isButton)
      .animation(.easeOut(duration: 0.15), value: on)
  }
  func start() {
    let base = bar.input
    voice.listen(lang: bar.lang, onText: { t in
      let joiner = base.isEmpty || base.hasSuffix(" ") || base.hasSuffix("，") ? "" : (bar.lang == .zh ? "，" : " ")
      bar.input = String((base + joiner + t).prefix(bar.meta.textMax))
    }, onEnd: { t in
      if t == nil { bar.showToast(L("麥克風沒有開權限，可以先用打字")) }
      else if !(t ?? "").isEmpty { bar.showToast(L("改好再按送出")) }
    })
  }
}

struct Bubble: View {
  let m: Msg
  var body: some View {
    switch m.who {
    case "sys":
      Text(m.text).font(.system(size: 12.5)).foregroundStyle(C.dim).multilineTextAlignment(.center).frame(maxWidth: .infinity)
    case "me":
      HStack { Spacer(minLength: 40); Text(m.text).font(.system(size: 14.5)).padding(.horizontal, 11).padding(.vertical, 7).background(C.teal, in: RoundedRectangle(cornerRadius: 14)).foregroundStyle(.white) }
    default:
      HStack { Text(m.text).font(.system(size: 14.5)).padding(.horizontal, 11).padding(.vertical, 7).background(.white, in: RoundedRectangle(cornerRadius: 14)).foregroundStyle(C.outline); Spacer(minLength: 40) }
    }
  }
}

/// 吧台場景：背景圖 cover 貼底；前景只露出吧台（下面 28.4%），Bartender 夾在中間
struct BarScene: View {
  @EnvironmentObject var bar: Bar
  @State private var bob = false
  var body: some View {
    GeometryReader { g in
      let w = g.size.width, h = g.size.height
      let btW = min(w * 0.62, 300)
      ZStack {
        backdrop(w, h)
        if let b = bar.who {
          Img.view("cast/" + b.image(bar.mood)).resizable().scaledToFit()
            .frame(width: btW, height: btW, alignment: .bottom)
            .shadow(color: .black.opacity(0.5), radius: 6, y: 4)
            .rotationEffect(.degrees(bar.shaking ? (bob ? -2.5 : 2.5) : 0), anchor: .bottom)
            .offset(y: bar.mood == "talk" && bob ? -3 : 0)
            .position(x: w / 2, y: h - h * 0.22 - btW / 2)
            .onTapGesture { bar.sheet = .about }
        }
        backdrop(w, h).mask(VStack(spacing: 0) { Color.clear; Color.black.frame(height: h * 0.284) }).allowsHitTesting(false)
        if let t = bar.bubble {
          Text(t).font(.system(size: 14)).foregroundStyle(C.outline).lineLimit(4)
            .padding(.horizontal, 11).padding(.vertical, 7)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.white, in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(C.outline, lineWidth: 2))
            .shadow(color: .black.opacity(0.35), radius: 6, y: 4)
            .padding(.horizontal, w * 0.03).padding(.top, 8)
            .frame(maxHeight: .infinity, alignment: .top)
            .transition(.opacity)
        }
        HStack(alignment: .bottom, spacing: 6) {
          obj("ui/menu", L("酒單")) { bar.sheet = .list }.accessibilityIdentifier("objMenu")
          obj("ui/cabinet", L("我家")) { bar.sheet = .cabinet }
          obj("ui/shaker", L("小抄")) { bar.sheet = .basics }
          Spacer()
          if let c = bar.visit?.current, let r = bar.list.first(where: { $0.id == c.id }), bar.making == nil {
            Button { bar.sheet = .recipe(c.id, c.tweak) } label: {
              VStack(spacing: -4) {
                GlassView(art: r.art).frame(width: 74, height: 92).shadow(color: .black.opacity(0.55), radius: 4, y: 3)
                Text(L("酒譜卡")).font(.system(size: 12, weight: .heavy)).foregroundStyle(Color(hex: "#24170a"))
                  .padding(.horizontal, 10).padding(.vertical, 2).background(C.hot2, in: Capsule())
              }
            }.buttonStyle(.plain).accessibilityIdentifier("glass").transition(.scale.combined(with: .opacity))
          }
        }
        .padding(8)
        .frame(maxHeight: .infinity, alignment: .bottom)
        if let mk = bar.making {
          VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) { ForEach(Array(mk.tools.enumerated()), id: \.offset) { i, t in Img.view("props/" + t).resizable().scaledToFit().frame(width: 42, height: 42).offset(y: bob && i % 2 == 0 ? -4 : 0) } }
            Text(mk.text).font(.system(size: 13, weight: .semibold)).lineLimit(1).minimumScaleFactor(0.7)
            GeometryReader { pg in Capsule().fill(C.line).overlay(alignment: .leading) { Capsule().fill(C.hot).frame(width: pg.size.width * mk.progress) } }.frame(height: 6)
          }
          .padding(.horizontal, 10).padding(.vertical, 8)
          .background(Color(hex: "#140e0a").opacity(0.9), in: RoundedRectangle(cornerRadius: 14))
          .overlay(RoundedRectangle(cornerRadius: 14).stroke(C.line))
          .padding(.horizontal, 8).padding(.bottom, 74)
          .frame(maxHeight: .infinity, alignment: .bottom)
        }
        if bar.busy && bar.making == nil {
          Text(bar.busyText).font(.system(size: 12, weight: .semibold)).padding(.horizontal, 10).padding(.vertical, 5)
            .background(.black.opacity(0.7), in: Capsule()).frame(maxHeight: .infinity, alignment: .center)
        }
      }
      .frame(width: w, height: h)
    }
    .background(Color(hex: "#1a1512"))
    .clipShape(RoundedRectangle(cornerRadius: 18))
    .overlay(RoundedRectangle(cornerRadius: 18).stroke(C.line))
    .animation(.easeInOut(duration: 0.25), value: bar.bubble)
    .animation(.spring(response: 0.45, dampingFraction: 0.6), value: bar.visit?.current?.id)
    .onAppear { withAnimation(.easeInOut(duration: 0.18).repeatForever(autoreverses: true)) { bob.toggle() } }
  }
  func backdrop(_ w: CGFloat, _ h: CGFloat) -> some View {
    Img.view("bar").resizable().scaledToFill().frame(width: w, height: h, alignment: .bottom).clipped()
  }
  func obj(_ icon: String, _ text: String, _ act: @escaping () -> Void) -> some View {
    Button(action: act) {
      VStack(spacing: 1) { Img.view(icon).resizable().scaledToFit().frame(width: 32, height: 32); Text(text).font(.system(size: 11, weight: .bold)).lineLimit(1).minimumScaleFactor(0.6) }
        .frame(width: 56, height: 58).foregroundStyle(.white)
        .background(Color(hex: "#140e0a").opacity(0.78), in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(.white.opacity(0.14)))
    }.buttonStyle(.plain)
  }
}

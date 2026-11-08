import SwiftUI

@main
struct AceBartenderApp: App {
  @StateObject private var bar: Bar
  init() {
    let args = ProcessInfo.processInfo.arguments
    if let i = args.firstIndex(of: "-shot"), i + 1 < args.count { Autotest.scene = args[i + 1] }
    if Autotest.scene != nil { Saves.wipeForTests() }
    if args.contains("-offline") { Net.shared.forcedOffline = true }
    let b = Bar(fast: Autotest.scene != nil)
    if let i = args.firstIndex(of: "-lang"), i + 1 < args.count, let l = Lang(rawValue: args[i + 1]) { b.setLang(l) }
    _bar = StateObject(wrappedValue: b)
  }
  var body: some Scene {
    WindowGroup {
      Root()
        .environmentObject(bar)
        .preferredColorScheme(.dark)
        .task { await bar.boot(); await Autotest.run(bar) }
    }
  }
}

struct Root: View {
  @EnvironmentObject var bar: Bar
  var body: some View {
    ZStack {
      C.bg.ignoresSafeArea()
      switch bar.screen {
      case .title: TitleView()
      case .bar: BarView()
      case .checkout: CheckoutView()
      }
      if let t = bar.toast {
        VStack { Spacer(); Text(t).font(.system(size: 14, weight: .semibold)).padding(.horizontal, 16).padding(.vertical, 10)
          .background(.black.opacity(0.85), in: Capsule()).foregroundStyle(.white).padding(.bottom, 110) }
          .transition(.opacity).allowsHitTesting(false)
      }
    }
    .sheet(item: $bar.sheet) { s in SheetHost(sheet: s).environmentObject(bar).presentationDragIndicator(.visible) }
    .animation(.easeInOut(duration: 0.2), value: bar.toast)
  }
}

struct SheetHost: View {
  @EnvironmentObject var bar: Bar
  let sheet: Bar.Sheet
  var body: some View {
    Group {
      switch sheet {
      case .recipe(let id, let tw): RecipeSheet(id: id, tweak: tw)
      case .list: MenuListSheet()
      case .book: BookSheet()
      case .cabinet: CabinetSheet()
      case .basics: BasicsSheet()
      case .pick: PickSheet()
      case .menu: MenuSheet()
      case .help: HelpSheet()
      case .about: AboutSheet()
      case .howto: HowToSheet()
      case .age: AgeSheet()
      case .lab: LabSheet()
      }
    }
    .preferredColorScheme(.dark)
  }
}

/// CI 截圖用：-shot <場景> -lang <語言> -offline。照劇本點到那個畫面就停住。
@MainActor
enum Autotest {
  static var scene: String?
  static func run(_ bar: Bar) async {
    guard let s = scene else { return }
    print("NATIVE autotest \(s) lang=\(bar.lang.rawValue)")
    func pause(_ sec: Double) async { try? await Task.sleep(nanoseconds: UInt64(sec * 1_000_000_000)) }
    switch s {
    case "title": break
    case "title-che": bar.settings.bartender = "che"
    case "age": bar.start()
    case "bar":
      bar.settings.bartender = "lan"; bar.ageOK(zero: false)
    case "served", "recipe", "list", "book", "checkout", "cabinet", "basics", "pick", "menu", "help", "about", "tweak", "infusion", "night":
      bar.settings.bartender = s == "infusion" ? "zhou" : s == "night" ? "che" : "mei"; bar.ageOK(zero: false)
      await pause(1)
      if s == "help" { await bar.send("我不想活了"); break }
      if s == "infusion" { await bar.send(L("你有什麼祕密配方？")) }
      else if s == "night" { await bar.send(L("想喝偏酸的")); await bar.send(L("想喝水果味的")); bar.order("negroni"); await pause(4) }
      else { bar.order(s == "tweak" ? "whiskey_sour" : "mojito"); await pause(4) }
      if s == "tweak" { await bar.send(L("少甜一點")) }
      await pause(1)
      switch s {
      case "recipe", "tweak", "infusion": if let c = bar.visit?.current { bar.sheet = .recipe(c.id, c.tweak) }
      case "list": bar.sheet = .list
      case "book": bar.toggleSave("mojito", tweak: nil); bar.toggleSave("negroni", tweak: nil); bar.markMade("mojito", tweak: nil); bar.sheet = .book
      case "cabinet": bar.setPantry(["gin", "rum", "citrus", "syrup", "soda"]); bar.sheet = .cabinet
      case "basics": bar.sheet = .basics
      case "pick": bar.pickSel = "zhou"; bar.sheet = .pick
      case "menu": bar.sheet = .menu
      case "about": bar.sheet = .about
      case "checkout", "night": bar.pay()
      default: break
      }
    default: print("NATIVE unknown scene \(s)")
    }
    print("NATIVE autotest ready \(s)")
  }
}

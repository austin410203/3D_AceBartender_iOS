import SwiftUI
import UIKit

/// 深色酒吧＋紙質酒譜卡（顏色照網頁 style.css）
enum C {
  static let bg = Color(hex: "#14110f"), bg2 = Color(hex: "#1d1815"), panel = Color(hex: "#2a2320"), line = Color(hex: "#3d332d")
  static let ink = Color(hex: "#f6efe4"), dim = Color(hex: "#b3a699"), hot = Color(hex: "#e0923a"), hot2 = Color(hex: "#f0b65c")
  static let ok = Color(hex: "#5cc29a"), warn = Color(hex: "#f2c14e"), teal = Color(hex: "#2d6a6a"), red = Color(hex: "#d9483b")
  static let paper = Color(hex: "#f8f2e4"), paperInk = Color(hex: "#2b2320"), paperDim = Color(hex: "#7b6d60"), outline = Color(hex: "#1a1512")
}

extension Color {
  init(hex: String) {
    var s = hex.trimmingCharacters(in: .whitespaces); if s.hasPrefix("#") { s.removeFirst() }
    var v: UInt64 = 0; Scanner(string: s).scanHexInt64(&v)
    self.init(.sRGB, red: Double((v >> 16) & 0xff) / 255, green: Double((v >> 8) & 0xff) / 255, blue: Double(v & 0xff) / 255, opacity: 1)
  }
}

/// App 內的圖（Images/ 資料夾，webp）
enum Img {
  private static var cache: [String: UIImage] = [:]
  static func ui(_ path: String) -> UIImage? {
    if let c = cache[path] { return c }
    guard let url = Bundle.main.url(forResource: path, withExtension: "webp", subdirectory: "Images"),
          let img = UIImage(contentsOfFile: url.path) else { return nil }
    cache[path] = img; return img
  }
  static func view(_ path: String) -> Image { ui(path).map { Image(uiImage: $0) } ?? Image(systemName: "photo") }
}

struct Primary: ButtonStyle {
  var big = false
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .font(.system(size: big ? 19 : 16, weight: .heavy))
      .foregroundStyle(Color(hex: "#24170a"))
      .frame(maxWidth: big ? .infinity : nil)
      .padding(.vertical, big ? 15 : 11).padding(.horizontal, 20)
      .background(LinearGradient(colors: [C.hot, C.hot2], startPoint: .topLeading, endPoint: .bottomTrailing), in: Capsule())
      .shadow(color: C.hot.opacity(0.3), radius: 9, y: 6)
      .scaleEffect(configuration.isPressed ? 0.97 : 1)
  }
}

struct Soft: ButtonStyle {
  var on = false
  var wide = false
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .font(.system(size: 14, weight: on ? .heavy : .regular))
      .lineLimit(2).minimumScaleFactor(0.7).multilineTextAlignment(.center)
      .foregroundStyle(on ? Color(hex: "#24170a") : C.ink)
      .frame(maxWidth: wide ? .infinity : nil)
      .padding(.vertical, 9).padding(.horizontal, 12)
      .background(on ? C.hot : C.panel, in: RoundedRectangle(cornerRadius: 12))
      .opacity(configuration.isPressed ? 0.75 : 1)
  }
}

struct Badge: View {
  let text: String
  var kind = ""
  var body: some View {
    Text(text).font(.system(size: 12, weight: .bold))
      .padding(.horizontal, 8).padding(.vertical, 3)
      .foregroundStyle(kind == "dim" ? C.paperDim : kind == "" ? C.paperInk : .white)
      .background(bg, in: Capsule())
  }
  var bg: Color {
    switch kind {
    case "cat": return Color(hex: "#7a3f12")
    case "official": return Color(hex: "#2f6b45")
    case "inspired": return Color(hex: "#8a5a12")
    case "orig": return Color(hex: "#5b4a8a")
    case "tweak": return C.teal
    case "dim": return Color(hex: "#e8dfcd")
    default: return Color(hex: "#efe4cf")
    }
  }
}

/// 烈度五格
struct StrengthDots: View {
  let n: Int
  var dark = true
  var body: some View {
    HStack(spacing: 3) {
      ForEach(1...5, id: \.self) { i in
        RoundedRectangle(cornerRadius: 2).fill(i <= n ? C.hot : (dark ? C.line : Color(hex: "#e2d6c1"))).frame(width: 12, height: 6)
      }
    }
  }
}

/// 簡單的流式排版（標籤一行放不下就換行）
struct Flow: Layout {
  var spacing: CGFloat = 6
  func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
    let w = proposal.width ?? 320
    var x: CGFloat = 0, y: CGFloat = 0, rowH: CGFloat = 0
    for v in subviews {
      let s = v.sizeThatFits(.unspecified)
      if x + s.width > w, x > 0 { x = 0; y += rowH + spacing; rowH = 0 }
      x += s.width + spacing; rowH = max(rowH, s.height)
    }
    return CGSize(width: w, height: y + rowH)
  }
  func placeSubviews(in b: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
    var x = b.minX, y = b.minY, rowH: CGFloat = 0
    for v in subviews {
      let s = v.sizeThatFits(.unspecified)
      if x + s.width > b.maxX, x > b.minX { x = b.minX; y += rowH + spacing; rowH = 0 }
      v.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(s))
      x += s.width + spacing; rowH = max(rowH, s.height)
    }
  }
}

/// 分享：系統分享面板（存到照片、傳給朋友、存成檔案都在裡面）
enum ShareSheet {
  @MainActor static func present(_ items: [Any]) {
    guard let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first,
          var top = scene.windows.first(where: { $0.isKeyWindow })?.rootViewController else { return }
    while let p = top.presentedViewController { top = p }
    let vc = UIActivityViewController(activityItems: items, applicationActivities: nil)
    if let pop = vc.popoverPresentationController { pop.sourceView = top.view; pop.sourceRect = CGRect(x: top.view.bounds.midX, y: top.view.bounds.midY, width: 1, height: 1) }
    top.present(vc, animated: true)
  }
  /// 文字存成 .txt 檔再分享
  @MainActor static func text(_ s: String, file: String) {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(file)
    try? s.data(using: .utf8)?.write(to: url)
    present([url])
  }
}

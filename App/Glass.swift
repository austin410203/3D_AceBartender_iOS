import SwiftUI

/// 杯子插圖（照網頁 glass.js 的 SVG：粗黑描邊＋扁平上色），viewBox 100×124。
/// 杯型、酒色、冰、氣泡、裝飾由酒譜決定，184 杯共用。
struct GlassView: View {
  let art: GlassArt
  var body: some View {
    Canvas { ctx, size in
      let k = min(size.width / 100, size.height / 124)
      let ox = (size.width - 100 * k) / 2, oy = (size.height - 124 * k) / 2
      ctx.translateBy(x: ox, y: oy); ctx.scaleBy(x: k, y: k)
      let s = GlassShape.shapes[art.glass] ?? GlassShape.shapes["rocks"]!
      let body = SVGPath.parse(s.body), liq = SVGPath.parse(s.liq)
      let ink = C.outline
      ctx.fill(body, with: .color(.white.opacity(0.22)))
      ctx.fill(liq, with: .color(Color(hex: art.color)))
      if art.ice {
        for (x, y, w) in s.ice {
          let r = Path(roundedRect: CGRect(x: x, y: y, width: w, height: w), cornerRadius: 3)
          ctx.fill(r, with: .color(.white.opacity(0.42)))
          ctx.stroke(r, with: .color(.white), lineWidth: 1.4)
        }
      }
      if art.fizzy {
        for i in 0..<5 {
          let cx = 40 + Double(i) * 5 + Double(i % 2) * 3, cy = s.top + 12 + Double((i * 13) % 34)
          ctx.fill(Path(ellipseIn: CGRect(x: cx - 1.8, y: cy - 1.8, width: 3.6, height: 3.6)), with: .color(.white.opacity(0.8)))
        }
      }
      ctx.stroke(body, with: .color(ink), style: StrokeStyle(lineWidth: 3.6, lineJoin: .round))
      // 反光
      var shine = Path()
      switch art.glass {
      case "martini": shine.move(to: CGPoint(x: 26, y: 37)); shine.addLine(to: CGPoint(x: 40, y: 53))
      case "coupe": shine.move(to: CGPoint(x: 26, y: 44)); shine.addQuadCurve(to: CGPoint(x: 38, y: 58), control: CGPoint(x: 30, y: 54))
      default: shine.move(to: CGPoint(x: 30, y: s.top + 8)); shine.addLine(to: CGPoint(x: 32, y: s.top + 34))
      }
      ctx.stroke(shine, with: .color(.white.opacity(0.75)), style: StrokeStyle(lineWidth: 3, lineCap: .round))
      garnish(ctx, top: s.top, ink: ink)
    }
    .aspectRatio(100.0 / 124.0, contentMode: .fit)
    .accessibilityHidden(true)
  }

  private func garnish(_ ctx: GraphicsContext, top: Double, ink: Color) {
    let line = StrokeStyle(lineWidth: 2)
    switch art.garnish {
    case "herb":
      var p = Path(); p.move(to: CGPoint(x: 66, y: top - 2))
      p.addQuadCurve(to: CGPoint(x: 84, y: top - 20), control: CGPoint(x: 74, y: top - 20))
      p.addQuadCurve(to: CGPoint(x: 68, y: top), control: CGPoint(x: 84, y: top - 6)); p.closeSubpath()
      ctx.fill(p, with: .color(Color(hex: "#5fae4e"))); ctx.stroke(p, with: .color(ink), style: line)
    case "cherry":
      let p = Path(ellipseIn: CGRect(x: 64, y: top - 10, width: 12, height: 12))
      ctx.fill(p, with: .color(Color(hex: "#b3202e"))); ctx.stroke(p, with: .color(ink), style: line)
    case "olive":
      let p = Path(ellipseIn: CGRect(x: 59, y: top - 8, width: 14, height: 10))
      ctx.fill(p, with: .color(Color(hex: "#8fa33a"))); ctx.stroke(p, with: .color(ink), style: line)
    case "orange":
      var p = Path(); p.move(to: CGPoint(x: 60, y: top + 2))
      p.addArc(center: CGPoint(x: 72, y: top - 3), radius: 13, startAngle: .degrees(157), endAngle: .degrees(337), clockwise: false); p.closeSubpath()
      ctx.fill(p, with: .color(Color(hex: "#f09a2a"))); ctx.stroke(p, with: .color(ink), style: line)
    case "lemon", "lime", "grapefruit":
      let col = art.garnish == "lime" ? "#b9d65a" : art.garnish == "grapefruit" ? "#f4a08c" : "#f4e16a"
      let c = Path(ellipseIn: CGRect(x: 63, y: top - 13, width: 18, height: 18))
      ctx.fill(c, with: .color(Color(hex: col))); ctx.stroke(c, with: .color(ink), style: line)
      var x = Path(); x.move(to: CGPoint(x: 72, y: top - 13)); x.addLine(to: CGPoint(x: 72, y: top + 5))
      x.move(to: CGPoint(x: 63, y: top - 4)); x.addLine(to: CGPoint(x: 81, y: top - 4))
      ctx.stroke(x, with: .color(ink), lineWidth: 1.2)
    default: break
    }
  }
}

enum GlassShape {
  struct S { let body: String; let liq: String; let top: Double; let ice: [(Double, Double, Double)] }
  static let shapes: [String: S] = [
    "rocks": S(body: "M20 44 L24 112 Q24 116 28 116 L72 116 Q76 116 76 112 L80 44 Z", liq: "M23 66 L26 111 Q26 113 29 113 L71 113 Q74 113 74 111 L77 66 Z", top: 66, ice: [(34, 72, 18), (50, 84, 18)]),
    "highball": S(body: "M30 14 L33 112 Q33 116 37 116 L63 116 Q67 116 67 112 L70 14 Z", liq: "M31 32 L34 111 Q34 113 37 113 L63 113 Q66 113 66 111 L69 32 Z", top: 32, ice: [(37, 40, 15), (49, 58, 15), (38, 78, 15)]),
    "martini": S(body: "M12 26 L88 26 L54 66 L54 106 L72 112 L72 116 L28 116 L28 112 L46 106 L46 66 Z", liq: "M18 33 L82 33 L52 66 L48 66 Z", top: 33, ice: []),
    "coupe": S(body: "M14 30 Q14 66 46 70 L46 106 L28 112 L28 116 L72 116 L72 112 L54 106 L54 70 Q86 66 86 30 Z", liq: "M18 38 Q20 62 50 65 Q80 62 82 38 Z", top: 38, ice: []),
    "flute": S(body: "M36 10 Q32 56 46 76 L46 106 L30 112 L30 116 L70 116 L70 112 L54 106 L54 76 Q68 56 64 10 Z", liq: "M36 22 Q35 54 48 72 L52 72 Q65 54 64 22 Z", top: 22, ice: []),
    "wine": S(body: "M24 16 Q18 66 46 76 L46 106 L28 112 L28 116 L72 116 L72 112 L54 106 L54 76 Q82 66 76 16 Z", liq: "M23 38 Q24 66 48 72 L52 72 Q76 66 77 38 Z", top: 38, ice: [(36, 44, 13), (52, 50, 13)]),
    "mug": S(body: "M20 34 L22 112 Q22 116 26 116 L66 116 Q70 116 70 112 L72 34 Z M72 50 Q92 50 92 68 Q92 88 71 88 L71 78 Q82 78 82 68 Q82 60 72 60 Z", liq: "M23 50 L24 111 Q24 113 27 113 L65 113 Q68 113 68 111 L69 50 Z", top: 50, ice: []),
  ]
}

/// 只支援 glass.js 用到的絕對座標 M／L／Q／Z
enum SVGPath {
  enum Tok { case cmd(Character), num(Double) }
  static func tokens(_ d: String) -> [Tok] {
    var out: [Tok] = [], buf = ""
    func flush() { if let v = Double(buf) { out.append(.num(v)) }; buf = "" }
    for ch in d {
      if ch.isLetter { flush(); out.append(.cmd(ch)) }
      else if ch == " " || ch == "," { flush() }
      else if ch == "-" && !buf.isEmpty { flush(); buf = "-" }
      else { buf.append(ch) }
    }
    flush()
    return out
  }
  static func parse(_ d: String) -> Path {
    var p = Path(), cmd: Character = "M", nums: [Double] = []
    func run() {
      switch cmd {
      case "M": var j = 0; while j + 1 < nums.count { if j == 0 { p.move(to: CGPoint(x: nums[j], y: nums[j + 1])) } else { p.addLine(to: CGPoint(x: nums[j], y: nums[j + 1])) }; j += 2 }
      case "L": var j = 0; while j + 1 < nums.count { p.addLine(to: CGPoint(x: nums[j], y: nums[j + 1])); j += 2 }
      case "Q": var j = 0; while j + 3 < nums.count { p.addQuadCurve(to: CGPoint(x: nums[j + 2], y: nums[j + 3]), control: CGPoint(x: nums[j], y: nums[j + 1])); j += 4 }
      case "Z": p.closeSubpath()
      default: break
      }
      nums = []
    }
    for t in tokens(d) {
      switch t {
      case .cmd(let c): run(); cmd = c; if c == "Z" { run() }
      case .num(let v): nums.append(v)
      }
    }
    run()
    return p
  }
}

import SwiftUI

struct SymbolTile: View {
    let id: String
    var highlighted: Bool = false
    var tense: Bool = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.white, Color(red: 0.86, green: 0.89, blue: 0.94)],
                        startPoint: .top, endPoint: .bottom
                    )
                )
            Image("sym-\(id)")
                .resizable()
                .scaledToFit()
                .padding(2)
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.55), Color.white.opacity(0.05), .clear],
                        startPoint: .top, endPoint: .center
                    )
                )
                .allowsHitTesting(false)
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .stroke(highlighted ? Color(red: 1, green: 0.78, blue: 0.1) : Color(white: 0.62), lineWidth: highlighted ? 3 : 1)
        }
        .shadow(color: highlighted ? Color.yellow.opacity(0.9) : Color.black.opacity(0.18), radius: highlighted ? 7 : 1, y: 1)
        .scaleEffect(highlighted ? 1.03 : 1)
        .accessibilityLabel(SymbolName.of(id))
    }
}

struct SymbolGlyph: View {
    let id: String

    var body: some View {
        switch id {
        case "cherry": CherryGlyph()
        case "lemon": FruitOval(colors: [Color(red: 1, green: 0.92, blue: 0.35), Color(red: 0.92, green: 0.72, blue: 0.05)], leaf: true)
        case "plum": FruitOval(colors: [Color(red: 0.72, green: 0.28, blue: 0.72), Color(red: 0.36, green: 0.08, blue: 0.42)], leaf: true)
        case "grape": GrapeGlyph()
        case "melon": MelonGlyph()
        case "bell": BellGlyph()
        case "bar": BarGlyph()
        case "seven": SevenGlyph()
        case "book": BookGlyph()
        case "pharaoh": PharaohGlyph()
        case "ankh": AnkhGlyph()
        case "scarab": ScarabGlyph()
        case "eye": SphinxEyeGlyph()
        case "ace": RankGlyph(text: "A", tint: GK.gold)
        case "king": RankGlyph(text: "K", tint: Color(red: 0.95, green: 0.55, blue: 0.25))
        case "queen": RankGlyph(text: "D", tint: Color(red: 0.85, green: 0.45, blue: 0.85))
        case "jack": RankGlyph(text: "B", tint: Color(red: 0.45, green: 0.75, blue: 0.95))
        case "ten": RankGlyph(text: "10", tint: GK.ivory)
        case "joker": JokerGlyph()
        case "star": StarGlyph()
        default:
            Text("?")
                .foregroundStyle(GK.ivory)
        }
    }
}

private struct CherryGlyph: View {
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            ZStack {
                stem(in: geo.size)
                cherry(at: CGPoint(x: w * 0.36, y: h * 0.64), diameter: w * 0.42)
                cherry(at: CGPoint(x: w * 0.66, y: h * 0.60), diameter: w * 0.40)
                Ellipse()
                    .fill(Color(red: 0.25, green: 0.72, blue: 0.28))
                    .frame(width: w * 0.28, height: h * 0.16)
                    .rotationEffect(.degrees(-28))
                    .position(x: w * 0.70, y: h * 0.18)
            }
        }
    }

    private func cherry(at point: CGPoint, diameter: CGFloat) -> some View {
        Circle()
            .fill(LinearGradient(
                colors: [Color(red: 1, green: 0.38, blue: 0.42), Color(red: 0.62, green: 0.02, blue: 0.08)],
                startPoint: .top, endPoint: .bottom
            ))
            .frame(width: diameter, height: diameter)
            .overlay(alignment: .topLeading) {
                Circle().fill(Color.white.opacity(0.45)).frame(width: diameter * 0.22).padding(diameter * 0.16)
            }
            .position(point)
    }

    private func stem(in size: CGSize) -> some View {
        Path { path in
            path.move(to: CGPoint(x: size.width * 0.40, y: size.height * 0.48))
            path.addQuadCurve(
                to: CGPoint(x: size.width * 0.56, y: size.height * 0.16),
                control: CGPoint(x: size.width * 0.28, y: size.height * 0.20)
            )
            path.move(to: CGPoint(x: size.width * 0.62, y: size.height * 0.44))
            path.addQuadCurve(
                to: CGPoint(x: size.width * 0.56, y: size.height * 0.16),
                control: CGPoint(x: size.width * 0.78, y: size.height * 0.24)
            )
        }
        .stroke(Color(red: 0.18, green: 0.42, blue: 0.14), style: StrokeStyle(lineWidth: size.width * 0.045, lineCap: .round))
    }
}

private struct FruitOval: View {
    var colors: [Color]
    var leaf: Bool

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            ZStack {
                Ellipse()
                    .fill(LinearGradient(colors: colors, startPoint: .top, endPoint: .bottom))
                    .frame(width: w * 0.72, height: h * 0.62)
                    .position(x: w * 0.5, y: h * 0.58)
                Ellipse()
                    .fill(Color.white.opacity(0.35))
                    .frame(width: w * 0.16, height: h * 0.10)
                    .position(x: w * 0.38, y: h * 0.46)
                if leaf {
                    Ellipse()
                        .fill(Color(red: 0.30, green: 0.70, blue: 0.28))
                        .frame(width: w * 0.30, height: h * 0.16)
                        .rotationEffect(.degrees(-40))
                        .position(x: w * 0.62, y: h * 0.22)
                }
            }
        }
    }
}

private struct GrapeGlyph: View {
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let spots: [CGPoint] = [
                CGPoint(x: 0.50, y: 0.34),
                CGPoint(x: 0.36, y: 0.48), CGPoint(x: 0.64, y: 0.48),
                CGPoint(x: 0.28, y: 0.64), CGPoint(x: 0.50, y: 0.64), CGPoint(x: 0.72, y: 0.64),
                CGPoint(x: 0.40, y: 0.80), CGPoint(x: 0.60, y: 0.80)
            ]
            ZStack {
                Ellipse()
                    .fill(Color(red: 0.28, green: 0.62, blue: 0.24))
                    .frame(width: w * 0.26, height: h * 0.14)
                    .rotationEffect(.degrees(30))
                    .position(x: w * 0.62, y: h * 0.16)
                ForEach(0..<spots.count, id: \.self) { index in
                    Circle()
                        .fill(LinearGradient(
                            colors: [Color(red: 0.72, green: 0.42, blue: 0.95), Color(red: 0.32, green: 0.08, blue: 0.55)],
                            startPoint: .top, endPoint: .bottom
                        ))
                        .frame(width: w * 0.26, height: w * 0.26)
                        .position(x: spots[index].x * w, y: spots[index].y * h)
                }
            }
        }
    }
}

private struct MelonGlyph: View {
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        colors: [Color(red: 0.45, green: 0.85, blue: 0.40), Color(red: 0.10, green: 0.45, blue: 0.18)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ))
                    .padding(w * 0.08)
                Path { path in
                    path.move(to: CGPoint(x: w * 0.22, y: h * 0.30))
                    path.addQuadCurve(to: CGPoint(x: w * 0.78, y: h * 0.38), control: CGPoint(x: w * 0.5, y: h * 0.18))
                    path.move(to: CGPoint(x: w * 0.20, y: h * 0.55))
                    path.addQuadCurve(to: CGPoint(x: w * 0.80, y: h * 0.60), control: CGPoint(x: w * 0.5, y: h * 0.42))
                }
                .stroke(Color(red: 0.75, green: 0.95, blue: 0.55), style: StrokeStyle(lineWidth: 2, lineCap: .round))
            }
        }
    }
}

private struct BellGlyph: View {
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            ZStack {
                BellShape()
                    .fill(GK.goldFill)
                    .frame(width: w * 0.78, height: h * 0.72)
                    .position(x: w * 0.5, y: h * 0.42)
                Capsule()
                    .fill(GK.goldDeep)
                    .frame(width: w * 0.86, height: h * 0.10)
                    .position(x: w * 0.5, y: h * 0.74)
                Circle()
                    .fill(GK.goldDark)
                    .frame(width: w * 0.16)
                    .position(x: w * 0.5, y: h * 0.88)
            }
        }
    }
}

private struct BellShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        path.move(to: CGPoint(x: w * 0.50, y: h * 0.02))
        path.addQuadCurve(to: CGPoint(x: w * 0.12, y: h * 0.78), control: CGPoint(x: w * 0.02, y: h * 0.28))
        path.addLine(to: CGPoint(x: w * 0.88, y: h * 0.78))
        path.addQuadCurve(to: CGPoint(x: w * 0.50, y: h * 0.02), control: CGPoint(x: w * 0.98, y: h * 0.28))
        path.closeSubpath()
        return path
    }
}

private struct BarGlyph: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.black.opacity(0.75))
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(GK.gold, lineWidth: 2)
                )
                .padding(.horizontal, 2)
                .padding(.vertical, 10)
            Text("BAR")
                .font(.system(size: 18, weight: .black, design: .rounded))
                .foregroundStyle(GK.goldFill)
                .minimumScaleFactor(0.5)
        }
    }
}

private struct SevenGlyph: View {
    var body: some View {
        Text("7")
            .font(.system(size: 42, weight: .black, design: .rounded))
            .foregroundStyle(
                LinearGradient(
                    colors: [Color(red: 1, green: 0.35, blue: 0.32), Color(red: 0.72, green: 0.02, blue: 0.08)],
                    startPoint: .top, endPoint: .bottom
                )
            )
            .shadow(color: GK.gold, radius: 0, x: 0, y: 0)
            .shadow(color: GK.gold.opacity(0.9), radius: 1.5)
            .minimumScaleFactor(0.3)
            .lineLimit(1)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct BookGlyph: View {
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            ZStack {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(GK.ivory)
                    .frame(width: w * 0.18, height: h * 0.72)
                    .position(x: w * 0.78, y: h * 0.52)
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(LinearGradient(
                        colors: [Color(red: 0.55, green: 0.08, blue: 0.12), Color(red: 0.28, green: 0.03, blue: 0.06)],
                        startPoint: .top, endPoint: .bottom
                    ))
                    .frame(width: w * 0.62, height: h * 0.78)
                    .overlay(
                        RoundedRectangle(cornerRadius: 5).stroke(GK.gold, lineWidth: 1.5)
                    )
                    .position(x: w * 0.42, y: h * 0.50)
                CrownShape()
                    .fill(GK.gold)
                    .frame(width: w * 0.28, height: h * 0.22)
                    .position(x: w * 0.42, y: h * 0.46)
            }
        }
    }
}

private struct PharaohGlyph: View {
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            ZStack {
                Path { path in
                    path.move(to: CGPoint(x: w * 0.18, y: h * 0.95))
                    path.addLine(to: CGPoint(x: w * 0.28, y: h * 0.18))
                    path.addLine(to: CGPoint(x: w * 0.50, y: h * 0.04))
                    path.addLine(to: CGPoint(x: w * 0.72, y: h * 0.18))
                    path.addLine(to: CGPoint(x: w * 0.82, y: h * 0.95))
                    path.closeSubpath()
                }
                .fill(GK.goldFill)
                ForEach(0..<3, id: \.self) { stripe in
                    Capsule()
                        .fill(Color(red: 0.35, green: 0.12, blue: 0.08))
                        .frame(width: w * 0.06, height: h * 0.42)
                        .position(x: w * (0.36 + CGFloat(stripe) * 0.14), y: h * 0.32)
                }
                Ellipse()
                    .fill(Color(red: 0.93, green: 0.76, blue: 0.52))
                    .frame(width: w * 0.38, height: h * 0.42)
                    .position(x: w * 0.5, y: h * 0.62)
                HStack(spacing: w * 0.08) {
                    Capsule().fill(Color.black).frame(width: w * 0.08, height: h * 0.05)
                    Capsule().fill(Color.black).frame(width: w * 0.08, height: h * 0.05)
                }
                .position(x: w * 0.5, y: h * 0.58)
            }
        }
    }
}

private struct AnkhGlyph: View {
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            ZStack {
                Circle()
                    .stroke(GK.gold, lineWidth: w * 0.09)
                    .frame(width: w * 0.42, height: w * 0.42)
                    .position(x: w * 0.5, y: h * 0.24)
                Capsule()
                    .fill(GK.goldFill)
                    .frame(width: w * 0.12, height: h * 0.62)
                    .position(x: w * 0.5, y: h * 0.62)
                Capsule()
                    .fill(GK.goldFill)
                    .frame(width: w * 0.62, height: h * 0.10)
                    .position(x: w * 0.5, y: h * 0.48)
            }
        }
    }
}

private struct ScarabGlyph: View {
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            ZStack {
                Ellipse()
                    .fill(Color(red: 0.10, green: 0.55, blue: 0.52))
                    .frame(width: w * 0.34, height: h * 0.46)
                    .rotationEffect(.degrees(-28))
                    .position(x: w * 0.32, y: h * 0.48)
                Ellipse()
                    .fill(Color(red: 0.12, green: 0.62, blue: 0.55))
                    .frame(width: w * 0.34, height: h * 0.46)
                    .rotationEffect(.degrees(28))
                    .position(x: w * 0.68, y: h * 0.48)
                Ellipse()
                    .fill(GK.goldFill)
                    .frame(width: w * 0.22, height: h * 0.55)
                    .position(x: w * 0.5, y: h * 0.55)
                Circle()
                    .fill(GK.goldDeep)
                    .frame(width: w * 0.22)
                    .position(x: w * 0.5, y: h * 0.22)
            }
        }
    }
}

private struct SphinxEyeGlyph: View {
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            ZStack {
                CrownShape()
                    .fill(GK.gold)
                    .frame(width: w * 0.36, height: h * 0.22)
                    .position(x: w * 0.5, y: h * 0.16)
                Path { path in
                    path.move(to: CGPoint(x: w * 0.08, y: h * 0.55))
                    path.addQuadCurve(to: CGPoint(x: w * 0.92, y: h * 0.55), control: CGPoint(x: w * 0.5, y: h * 0.22))
                    path.addQuadCurve(to: CGPoint(x: w * 0.08, y: h * 0.55), control: CGPoint(x: w * 0.5, y: h * 0.90))
                }
                .fill(GK.ivory)
                Circle()
                    .fill(LinearGradient(colors: [GK.gold, Color(red: 0.45, green: 0.22, blue: 0.05)], startPoint: .top, endPoint: .bottom))
                    .frame(width: w * 0.28)
                    .position(x: w * 0.5, y: h * 0.55)
                Circle()
                    .fill(Color.black)
                    .frame(width: w * 0.12)
                    .position(x: w * 0.5, y: h * 0.55)
            }
        }
    }
}

private struct RankGlyph: View {
    var text: String
    var tint: Color

    var body: some View {
        Text(text)
            .font(.system(size: text.count > 1 ? 28 : 36, weight: .black, design: .serif))
            .foregroundStyle(tint)
            .shadow(color: tint.opacity(0.8), radius: 4)
            .minimumScaleFactor(0.4)
    }
}

private struct JokerGlyph: View {
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            ZStack {
                JesterHat()
                    .fill(LinearGradient(
                        colors: [Color(red: 0.55, green: 0.15, blue: 0.75), Color(red: 0.15, green: 0.55, blue: 0.35), GK.gold],
                        startPoint: .leading, endPoint: .trailing
                    ))
                    .frame(width: w * 0.92, height: h * 0.48)
                    .position(x: w * 0.5, y: h * 0.28)
                Circle().fill(GK.gold).frame(width: w * 0.10).position(x: w * 0.16, y: h * 0.16)
                Circle().fill(Color(red: 0.9, green: 0.2, blue: 0.3)).frame(width: w * 0.10).position(x: w * 0.50, y: h * 0.08)
                Circle().fill(Color(red: 0.2, green: 0.75, blue: 0.45)).frame(width: w * 0.10).position(x: w * 0.84, y: h * 0.16)
                Circle()
                    .fill(Color(red: 0.98, green: 0.86, blue: 0.72))
                    .frame(width: w * 0.42, height: w * 0.42)
                    .position(x: w * 0.5, y: h * 0.64)
                HStack(spacing: w * 0.08) {
                    Circle().fill(Color.black).frame(width: w * 0.05)
                    Circle().fill(Color.black).frame(width: w * 0.05)
                }
                .position(x: w * 0.5, y: h * 0.60)
                Capsule()
                    .fill(GK.crimson)
                    .frame(width: w * 0.16, height: h * 0.045)
                    .position(x: w * 0.5, y: h * 0.72)
            }
        }
    }
}

private struct JesterHat: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        path.move(to: CGPoint(x: w * 0.08, y: h * 0.85))
        path.addLine(to: CGPoint(x: w * 0.18, y: h * 0.15))
        path.addQuadCurve(to: CGPoint(x: w * 0.38, y: h * 0.55), control: CGPoint(x: w * 0.22, y: h * 0.45))
        path.addLine(to: CGPoint(x: w * 0.50, y: h * 0.02))
        path.addLine(to: CGPoint(x: w * 0.62, y: h * 0.55))
        path.addQuadCurve(to: CGPoint(x: w * 0.82, y: h * 0.15), control: CGPoint(x: w * 0.78, y: h * 0.45))
        path.addLine(to: CGPoint(x: w * 0.92, y: h * 0.85))
        path.closeSubpath()
        return path
    }
}

struct StarShape: Shape {
    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let outer = min(rect.width, rect.height) / 2
        let inner = outer * 0.42
        var path = Path()
        for index in 0..<10 {
            let angle = (Double(index) * .pi / 5) - .pi / 2
            let radius = index.isMultiple(of: 2) ? outer : inner
            let point = CGPoint(
                x: center.x + CGFloat(cos(angle)) * radius,
                y: center.y + CGFloat(sin(angle)) * radius
            )
            if index == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        path.closeSubpath()
        return path
    }
}

private struct StarGlyph: View {
    var body: some View {
        StarShape()
            .fill(GK.goldFill)
            .shadow(color: GK.gold.opacity(0.8), radius: 4)
            .padding(2)
    }
}

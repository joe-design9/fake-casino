import SwiftUI

// MARK: - Hex colors

extension Color {
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)
        let r, g, b: Double
        if cleaned.count == 6 {
            r = Double((value >> 16) & 0xFF) / 255
            g = Double((value >> 8) & 0xFF) / 255
            b = Double(value & 0xFF) / 255
        } else {
            r = 1; g = 1; b = 1
        }
        self.init(red: r, green: g, blue: b)
    }
}

extension MachinePalette {
    var gradientColors: [Color] { colors.map { Color(hex: $0) } }
    var accentColor: Color { Color(hex: accent) }

    var linearGradient: LinearGradient {
        LinearGradient(colors: gradientColors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

// MARK: - Symbol artwork

/// Renders one symbol's artwork: SF Symbol glyph, serif letter, or a drawn vector shape.
struct SymbolArtView: View {
    let art: SymbolArt
    let tint: Color
    var size: CGFloat = 34

    var body: some View {
        Group {
            switch art {
            case .sf(let name):
                Image(systemName: name)
                    .font(.system(size: size * 0.92, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [tint.opacity(0.75), tint, tint.opacity(0.85)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .shadow(color: tint.opacity(0.55), radius: size * 0.14, y: 1)
            case .letter(let text):
                Text(text)
                    .font(.system(size: size * 1.02, weight: .black, design: .serif))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.white, tint.opacity(0.9)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .shadow(color: .black.opacity(0.35), radius: 2, y: 1)
            case .shape(let kind):
                DrawnShapeView(kind: kind, tint: tint, size: size)
            }
        }
        .frame(width: size * 1.15, height: size * 1.15)
    }
}

// MARK: - Drawn vector shapes (no emoji, no image assets)

struct DrawnShapeView: View {
    let kind: ShapeKind
    let tint: Color
    let size: CGFloat

    var body: some View {
        Group {
            switch kind {
            case .cherry: cherry
            case .grape: grape
            case .lemon: lemon
            case .donut: donut
            case .candy: candy
            case .lollipop: lollipop
            case .horseshoe: horseshoe
            case .gem: gem
            case .coin: coin
            case .seven: seven
            case .bar: bar
            }
        }
        .frame(width: size * 1.15, height: size * 1.15)
    }

    private func grad(_ colors: [Color]) -> LinearGradient {
        LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    private var cherry: some View {
        ZStack {
            Path { path in
                path.move(to: CGPoint(x: size * 0.62, y: size * 0.10))
                path.addQuadCurve(
                    to: CGPoint(x: size * 0.30, y: size * 0.55),
                    control: CGPoint(x: size * 0.42, y: size * 0.30)
                )
                path.move(to: CGPoint(x: size * 0.62, y: size * 0.10))
                path.addQuadCurve(
                    to: CGPoint(x: size * 0.74, y: size * 0.48),
                    control: CGPoint(x: size * 0.78, y: size * 0.28)
                )
            }
            .stroke(Color(red: 0.35, green: 0.55, blue: 0.25), lineWidth: size * 0.06)
            Circle()
                .fill(grad([Color(red: 1.0, green: 0.42, blue: 0.45), Color(red: 0.78, green: 0.08, blue: 0.18)]))
                .frame(width: size * 0.52, height: size * 0.52)
                .offset(x: -size * 0.16, y: size * 0.17)
            Circle()
                .fill(grad([Color(red: 1.0, green: 0.50, blue: 0.52), Color(red: 0.85, green: 0.12, blue: 0.22)]))
                .frame(width: size * 0.46, height: size * 0.46)
                .offset(x: size * 0.20, y: size * 0.22)
            Ellipse()
                .fill(Color(red: 0.40, green: 0.70, blue: 0.30))
                .frame(width: size * 0.34, height: size * 0.16)
                .rotationEffect(.degrees(-24))
                .offset(x: size * 0.10, y: -size * 0.34)
        }
    }

    private var grape: some View {
        ZStack {
            let positions: [(CGFloat, CGFloat)] = [
                (0, -0.22), (-0.19, -0.05), (0.19, -0.05),
                (-0.10, 0.13), (0.10, 0.13), (0, 0.30)
            ]
            ForEach(Array(positions.enumerated()), id: \.offset) { _, pos in
                Circle()
                    .fill(grad([Color(red: 0.72, green: 0.45, blue: 0.95), Color(red: 0.42, green: 0.16, blue: 0.72)]))
                    .frame(width: size * 0.34, height: size * 0.34)
                    .offset(x: pos.0 * size, y: pos.1 * size)
            }
            Ellipse()
                .fill(Color(red: 0.40, green: 0.70, blue: 0.30))
                .frame(width: size * 0.34, height: size * 0.15)
                .rotationEffect(.degrees(20))
                .offset(x: size * 0.12, y: -size * 0.40)
        }
    }

    private var lemon: some View {
        ZStack {
            Ellipse()
                .fill(grad([Color(red: 1.0, green: 0.92, blue: 0.40), Color(red: 0.95, green: 0.75, blue: 0.10)]))
                .frame(width: size * 0.88, height: size * 0.58)
                .rotationEffect(.degrees(-28))
            Ellipse()
                .fill(Color.white.opacity(0.35))
                .frame(width: size * 0.40, height: size * 0.18)
                .rotationEffect(.degrees(-28))
                .offset(x: -size * 0.10, y: -size * 0.10)
        }
    }

    private var donut: some View {
        ZStack {
            Circle()
                .fill(grad([Color(red: 0.98, green: 0.78, blue: 0.52), Color(red: 0.85, green: 0.58, blue: 0.30)]))
                .frame(width: size * 0.92, height: size * 0.92)
            Circle()
                .stroke(tint, lineWidth: size * 0.20)
                .frame(width: size * 0.68, height: size * 0.68)
            // sprinkles
            ForEach(0..<7, id: \.self) { i in
                Capsule()
                    .fill([Color.white, Color.yellow, Color.cyan, Color.green][i % 4])
                    .frame(width: size * 0.11, height: size * 0.035)
                    .rotationEffect(.degrees(Double(i) * 47))
                    .offset(
                        x: size * 0.24 * cos(Double(i) * 2.4),
                        y: size * 0.24 * sin(Double(i) * 2.4)
                    )
            }
            Circle()
                .fill(Color(red: 0.10, green: 0.05, blue: 0.16))
                .frame(width: size * 0.26, height: size * 0.26)
        }
    }

    private var candy: some View {
        ZStack {
            Path { path in
                path.move(to: CGPoint(x: size * 0.30, y: size * 0.5))
                path.addLine(to: CGPoint(x: size * 0.02, y: size * 0.26))
                path.addLine(to: CGPoint(x: size * 0.02, y: size * 0.74))
                path.closeSubpath()
                path.move(to: CGPoint(x: size * 0.70, y: size * 0.5))
                path.addLine(to: CGPoint(x: size * 0.98, y: size * 0.26))
                path.addLine(to: CGPoint(x: size * 0.98, y: size * 0.74))
                path.closeSubpath()
            }
            .fill(tint.opacity(0.75))
            Circle()
                .fill(grad([tint.opacity(0.65), tint]))
                .frame(width: size * 0.58, height: size * 0.58)
            Circle()
                .stroke(Color.white.opacity(0.65), lineWidth: size * 0.045)
                .frame(width: size * 0.34, height: size * 0.34)
        }
    }

    private var lollipop: some View {
        ZStack {
            Rectangle()
                .fill(Color.white.opacity(0.85))
                .frame(width: size * 0.07, height: size * 0.5)
                .offset(y: size * 0.26)
            Circle()
                .fill(grad([tint.opacity(0.6), tint]))
                .frame(width: size * 0.62, height: size * 0.62)
                .offset(y: -size * 0.14)
            Circle()
                .stroke(Color.white.opacity(0.7), lineWidth: size * 0.05)
                .frame(width: size * 0.36, height: size * 0.36)
                .offset(y: -size * 0.14)
            Circle()
                .fill(Color.white.opacity(0.8))
                .frame(width: size * 0.13, height: size * 0.13)
                .offset(y: -size * 0.14)
        }
    }

    private var horseshoe: some View {
        ZStack {
            Circle()
                .trim(from: 0.06, to: 0.94)
                .stroke(
                    grad([Color(red: 0.92, green: 0.93, blue: 0.97), Color(red: 0.55, green: 0.58, blue: 0.66)]),
                    style: StrokeStyle(lineWidth: size * 0.17, lineCap: .round)
                )
                .frame(width: size * 0.74, height: size * 0.74)
                .rotationEffect(.degrees(90))
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(Color(red: 0.30, green: 0.32, blue: 0.38))
                    .frame(width: size * 0.07, height: size * 0.07)
                    .offset(
                        x: size * 0.37 * cos(Double(i) * 1.1 + 2.2),
                        y: size * 0.37 * sin(Double(i) * 1.1 + 2.2)
                    )
            }
        }
    }

    private var gem: some View {
        ZStack {
            Path { path in
                let w = size * 0.46
                let cx = size * 0.5
                path.move(to: CGPoint(x: cx - w, y: size * 0.34))
                path.addLine(to: CGPoint(x: cx + w, y: size * 0.34))
                path.addLine(to: CGPoint(x: cx, y: size * 0.82))
                path.closeSubpath()
                path.move(to: CGPoint(x: cx - w, y: size * 0.34))
                path.addLine(to: CGPoint(x: cx - w * 0.55, y: size * 0.12))
                path.addLine(to: CGPoint(x: cx + w * 0.55, y: size * 0.12))
                path.addLine(to: CGPoint(x: cx + w, y: size * 0.34))
                path.closeSubpath()
            }
            .fill(grad([tint.opacity(0.55), tint, tint.opacity(0.8)]))
            Path { path in
                path.move(to: CGPoint(x: size * 0.04 + size * 0.0, y: size * 0.34))
                path.addLine(to: CGPoint(x: size * 0.96, y: size * 0.34))
                path.move(to: CGPoint(x: size * 0.5, y: size * 0.34))
                path.addLine(to: CGPoint(x: size * 0.5, y: size * 0.82))
            }
            .stroke(Color.white.opacity(0.5), lineWidth: size * 0.03)
        }
    }

    private var coin: some View {
        ZStack {
            Circle()
                .fill(grad([Color(red: 1.0, green: 0.88, blue: 0.45), Color(red: 0.92, green: 0.62, blue: 0.12)]))
                .frame(width: size * 0.86, height: size * 0.86)
            Circle()
                .strokeBorder(Color(red: 0.72, green: 0.45, blue: 0.05), lineWidth: size * 0.05)
                .frame(width: size * 0.68, height: size * 0.68)
            Image(systemName: "star.fill")
                .font(.system(size: size * 0.34, weight: .bold))
                .foregroundStyle(Color(red: 0.62, green: 0.38, blue: 0.03))
        }
    }

    private var seven: some View {
        Text("7")
            .font(.system(size: size * 1.05, weight: .black, design: .serif))
            .foregroundStyle(
                grad([Color(red: 1.0, green: 0.45, blue: 0.42), Color(red: 0.85, green: 0.08, blue: 0.12)])
            )
            .shadow(color: Color.red.opacity(0.5), radius: size * 0.10, y: 1)
    }

    private var bar: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.10, style: .continuous)
                .fill(Color(red: 0.08, green: 0.08, blue: 0.10))
                .frame(width: size * 0.98, height: size * 0.52)
            RoundedRectangle(cornerRadius: size * 0.10, style: .continuous)
                .strokeBorder(Color.white.opacity(0.75), lineWidth: size * 0.035)
                .frame(width: size * 0.98, height: size * 0.52)
            Text("BAR")
                .font(.system(size: size * 0.30, weight: .black, design: .serif))
                .tracking(size * 0.04)
                .foregroundStyle(.white)
        }
    }
}

// MARK: - Patterned art backdrop for tiles & reel frames

/// Layered gradient + radial glow + subtle dot pattern, drawn from a palette.
struct PaletteArtwork: View {
    let palette: MachinePalette
    var glowOpacity: Double = 0.55

    var body: some View {
        ZStack {
            palette.linearGradient
            RadialGradient(
                colors: [palette.accentColor.opacity(glowOpacity), .clear],
                center: .topTrailing,
                startRadius: 4,
                endRadius: 190
            )
            Canvas { context, size in
                let step: CGFloat = 16
                var y: CGFloat = 8
                while y < size.height {
                    var x: CGFloat = 8
                    while x < size.width {
                        let rect = CGRect(x: x, y: y, width: 2.2, height: 2.2)
                        context.fill(Path(ellipseIn: rect), with: .color(.white.opacity(0.10)))
                        x += step
                    }
                    y += step
                }
            }
        }
    }
}

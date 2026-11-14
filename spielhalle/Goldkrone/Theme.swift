import SwiftUI

enum GK {
    static let ink = Color(red: 0.025, green: 0.04, blue: 0.075)
    static let navy = Color(red: 0.07, green: 0.10, blue: 0.16)
    static let panel = Color(red: 0.11, green: 0.14, blue: 0.22)
    static let gold = Color(red: 0.98, green: 0.82, blue: 0.42)
    static let goldDeep = Color(red: 0.78, green: 0.54, blue: 0.16)
    static let goldDark = Color(red: 0.40, green: 0.28, blue: 0.08)
    static let crimson = Color(red: 0.80, green: 0.07, blue: 0.13)
    static let ledAmber = Color(red: 1.0, green: 0.78, blue: 0.28)
    static let ledGreen = Color(red: 0.55, green: 1.0, blue: 0.65)
    static let ivory = Color(red: 0.97, green: 0.94, blue: 0.88)
    static let felt = Color(red: 0.05, green: 0.16, blue: 0.12)

    static let goldFill = LinearGradient(
        colors: [Color(red: 1.0, green: 0.90, blue: 0.55), Color(red: 0.86, green: 0.62, blue: 0.18), Color(red: 0.55, green: 0.36, blue: 0.08)],
        startPoint: .top, endPoint: .bottom
    )
    static let redFill = LinearGradient(
        colors: [Color(red: 0.95, green: 0.22, blue: 0.24), Color(red: 0.62, green: 0.04, blue: 0.10), Color(red: 0.36, green: 0.02, blue: 0.06)],
        startPoint: .top, endPoint: .bottom
    )
    static let navyFill = LinearGradient(
        colors: [Color(red: 0.20, green: 0.26, blue: 0.38), Color(red: 0.08, green: 0.11, blue: 0.18)],
        startPoint: .top, endPoint: .bottom
    )
}

enum KT {
    static func string(_ value: Int) -> String {
        let negative = value < 0
        var digits = String(abs(value))
        var grouped = ""
        while digits.count > 3 {
            let tail = digits.suffix(3)
            grouped = "." + tail + grouped
            digits.removeLast(3)
        }
        grouped = digits + grouped
        return negative ? "-" + grouped : grouped
    }
}

struct ArcadeBackground: View {
    var body: some View {
        ZStack {
            GK.ink
            RadialGradient(
                colors: [Color(red: 0.28, green: 0.16, blue: 0.04).opacity(0.85), .clear],
                center: .top, startRadius: 10, endRadius: 460
            )
            RadialGradient(
                colors: [GK.crimson.opacity(0.22), .clear],
                center: .bottom, startRadius: 10, endRadius: 380
            )
            LinearGradient(
                colors: [Color.white.opacity(0.04), .clear, Color.black.opacity(0.35)],
                startPoint: .top, endPoint: .bottom
            )
        }
        .ignoresSafeArea()
    }
}

struct CrownShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        var p = Path()
        p.move(to: CGPoint(x: w * 0.12, y: h * 0.78))
        p.addLine(to: CGPoint(x: w * 0.22, y: h * 0.34))
        p.addLine(to: CGPoint(x: w * 0.36, y: h * 0.56))
        p.addLine(to: CGPoint(x: w * 0.50, y: h * 0.12))
        p.addLine(to: CGPoint(x: w * 0.64, y: h * 0.56))
        p.addLine(to: CGPoint(x: w * 0.78, y: h * 0.34))
        p.addLine(to: CGPoint(x: w * 0.88, y: h * 0.78))
        p.addLine(to: CGPoint(x: w * 0.80, y: h * 0.90))
        p.addLine(to: CGPoint(x: w * 0.20, y: h * 0.90))
        p.closeSubpath()
        return p
    }
}

struct CrownMark: View {
    var size: CGFloat = 46

    var body: some View {
        ZStack {
            CrownShape()
                .fill(GK.goldFill)
                .frame(width: size, height: size * 0.82)
                .shadow(color: GK.gold.opacity(0.65), radius: size * 0.12)
            CrownShape()
                .stroke(GK.goldDark, lineWidth: max(1, size * 0.025))
                .frame(width: size, height: size * 0.82)
            HStack(spacing: size * 0.16) {
                Circle().fill(Color(red: 0.75, green: 0.08, blue: 0.12)).frame(width: size * 0.09)
                Circle().fill(Color(red: 0.25, green: 0.75, blue: 0.85)).frame(width: size * 0.11)
                Circle().fill(Color(red: 0.75, green: 0.08, blue: 0.12)).frame(width: size * 0.09)
            }
            .offset(y: size * 0.20)
        }
        .frame(width: size, height: size)
        .accessibilityLabel("Goldkrone")
    }
}

struct PlayMoneyFooter: View {
    var body: some View {
        Text("Nur Spielgeld – keine echten Gewinne")
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .foregroundStyle(GK.ivory.opacity(0.82))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(Color.black.opacity(0.45))
            .accessibilityLabel("Nur Spielgeld, keine echten Gewinne")
    }
}

struct LEDReadout: View {
    let title: String
    let value: String
    var accent: Color = GK.ledAmber

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 9, weight: .heavy, design: .rounded))
                .tracking(1.1)
                .foregroundStyle(accent.opacity(0.75))
            Text(value)
                .font(.system(size: 15, weight: .bold, design: .monospaced))
                .foregroundStyle(accent)
                .shadow(color: accent.opacity(0.85), radius: 6)
                .lineLimit(1)
                .minimumScaleFactor(0.45)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.black.opacity(0.88))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(accent.opacity(0.45), lineWidth: 1)
                )
        )
    }
}

struct ArcadeButton: View {
    let title: String
    var subtitle: String? = nil
    var fill: LinearGradient = GK.navyFill
    var foreground: Color = GK.ivory
    var disabled: Bool = false
    let action: () -> Void

    var body: some View {
        Button {
            guard !disabled else { return }
            Haptics.tap()
            SoundEngine.shared.click()
            action()
        } label: {
            VStack(spacing: 1) {
                Text(title)
                    .font(.system(size: 17, weight: .heavy, design: .rounded))
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .opacity(0.85)
                }
            }
            .foregroundStyle(foreground.opacity(disabled ? 0.38 : 1))
            .frame(maxWidth: .infinity)
            .padding(.vertical, subtitle == nil ? 13 : 9)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(fill)
                    .opacity(disabled ? 0.4 : 1)
                    .overlay(alignment: .top) {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(LinearGradient(colors: [Color.white.opacity(0.32), .clear], startPoint: .top, endPoint: .center))
                            .frame(height: 22)
                            .allowsHitTesting(false)
                    }
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color.black.opacity(0.65), lineWidth: 2)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.white.opacity(0.28), lineWidth: 1)
                            .padding(2)
                    )
            )
            .shadow(color: disabled ? .clear : Color.black.opacity(0.45), radius: 4, y: 3)
        }
        .buttonStyle(.plain)
        .disabled(disabled)
    }
}

struct Panel<Content: View>: View {
    var content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }

    var body: some View {
        content
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(GK.navy.opacity(0.94))
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(GK.goldFill, lineWidth: 1.5)
                    )
            )
            .shadow(color: Color.black.opacity(0.5), radius: 18, y: 8)
    }
}

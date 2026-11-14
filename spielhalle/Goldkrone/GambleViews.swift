import SwiftUI

struct CoinBurst: View {
    var frozen: Bool = false

    var body: some View {
        TimelineView(.animation(minimumInterval: frozen ? 10 : 1.0 / 30.0, paused: false)) { timeline in
            let time = frozen ? 0.55 : timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 1.6) / 1.6
            Canvas { context, size in
                let origin = CGPoint(x: size.width / 2, y: size.height * 0.42)
                for index in 0..<26 {
                    let angle = Double(index) / 26.0 * Double.pi * 2 + Double(index) * 0.2
                    let distance = CGFloat(0.15 + time * 0.85) * min(size.width, size.height) * (0.28 + CGFloat(index % 4) * 0.06)
                    let center = CGPoint(
                        x: origin.x + CGFloat(cos(angle)) * distance,
                        y: origin.y + CGFloat(sin(angle)) * distance * 0.72 + CGFloat(time) * 30
                    )
                    let radius: CGFloat = index % 3 == 0 ? 7 : 5
                    let rect = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
                    context.fill(Path(ellipseIn: rect), with: .color(index % 2 == 0 ? GK.gold : Color(red: 1, green: 0.55, blue: 0.15)))
                    let shine = CGRect(x: center.x - radius * 0.35, y: center.y - radius * 0.45, width: radius * 0.5, height: radius * 0.35)
                    context.fill(Path(ellipseIn: shine), with: .color(.white.opacity(0.8)))
                }
            }
        }
        .allowsHitTesting(false)
    }
}

struct CelebrationOverlay: View {
    let mega: Bool
    let amount: Int
    var frozenCoins: Bool = false
    let onCollect: () -> Void
    let onRisk: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.72).ignoresSafeArea()
            RadialGradient(colors: [GK.gold.opacity(0.35), .clear], center: .center, startRadius: 10, endRadius: 280)
                .ignoresSafeArea()
            CoinBurst(frozen: frozenCoins)
            VStack(spacing: 14) {
                CrownMark(size: mega ? 78 : 64)
                Text(mega ? "MEGA GEWINN" : "GROSSER GEWINN")
                    .font(.system(size: mega ? 36 : 30, weight: .black, design: .serif))
                    .foregroundStyle(GK.goldFill)
                    .shadow(color: GK.gold.opacity(0.9), radius: 12)
                    .multilineTextAlignment(.center)
                Text("\(KT.string(amount)) KT")
                    .font(.system(size: 34, weight: .bold, design: .monospaced))
                    .foregroundStyle(GK.ledAmber)
                    .shadow(color: GK.ledAmber.opacity(0.8), radius: 8)
                Text("Nur Spielgeld")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(GK.ivory.opacity(0.7))
                HStack(spacing: 10) {
                    ArcadeButton(title: "EINSAMMELN", fill: GK.goldFill, foreground: .black, action: onCollect)
                    ArcadeButton(title: "RISIKO", fill: GK.redFill, action: onRisk)
                }
                .padding(.horizontal, 24)
            }
            .padding(.horizontal, 18)
        }
    }
}

struct ChooseGambleOverlay: View {
    let amount: Int
    let onLadder: () -> Void
    let onCards: () -> Void
    let onCollect: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.72).ignoresSafeArea()
            Panel {
                VStack(spacing: 14) {
                    Text("RISIKO")
                        .font(.system(size: 28, weight: .black, design: .serif))
                        .foregroundStyle(GK.gold)
                    Text("\(KT.string(amount)) KT stehen auf dem Spiel. Du kannst jederzeit einsammeln.")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(GK.ivory.opacity(0.85))
                        .multilineTextAlignment(.center)
                    ArcadeButton(title: "RISIKOLEITER", subtitle: "Verdoppeln oder verlieren", fill: GK.redFill, action: onLadder)
                    ArcadeButton(title: "KARTENRISIKO", subtitle: "Rot oder Schwarz", fill: GK.navyFill, action: onCards)
                    ArcadeButton(title: "EINSAMMELN", fill: GK.goldFill, foreground: .black, action: onCollect)
                }
            }
            .padding(22)
        }
    }
}

struct LadderOverlay: View {
    let base: Int
    let level: Int
    let busy: Bool
    let onClimb: () -> Void
    let onTake: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.78).ignoresSafeArea()
            VStack(spacing: 12) {
                Text("RISIKOLEITER")
                    .font(.system(size: 26, weight: .black, design: .serif))
                    .foregroundStyle(GK.gold)
                Text("Die Lampe springt zwischen der nächsten Stufe und Verlust. Chance etwa 50 zu 50.")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(GK.ivory.opacity(0.75))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                TimelineView(.animation(minimumInterval: 0.12, paused: false)) { context in
                    let flicker = Int(context.date.timeIntervalSinceReferenceDate * 8) % 2 == 0
                    VStack(spacing: 6) {
                        ForEach((0...LadderMath.maxLevel).reversed(), id: \.self) { step in
                            ladderLamp(step: step, flicker: flicker)
                        }
                        lossLamp(active: level < LadderMath.maxLevel && !flicker)
                    }
                }
                .padding(.vertical, 4)
                HStack(spacing: 10) {
                    ArcadeButton(title: "ANNEHMEN", fill: GK.goldFill, foreground: .black, disabled: busy, action: onTake)
                    ArcadeButton(
                        title: "RISIKO",
                        fill: GK.redFill,
                        disabled: busy || level >= LadderMath.maxLevel,
                        action: onClimb
                    )
                }
            }
            .padding(18)
        }
    }

    private func ladderLamp(step: Int, flicker: Bool) -> some View {
        let amount = LadderMath.amount(base: base, level: step)
        let current = step == level
        let next = step == level + 1 && level < LadderMath.maxLevel
        let lit = current || (next && flicker)
        return Text("\(KT.string(amount)) KT")
            .font(.system(size: 16, weight: .bold, design: .monospaced))
            .foregroundStyle(lit ? Color.black : GK.ivory.opacity(0.35))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(lit ? GK.gold : Color.white.opacity(0.05))
                    .shadow(color: lit ? GK.gold.opacity(0.8) : .clear, radius: lit ? 8 : 0)
            )
            .padding(.horizontal, 36)
    }

    private func lossLamp(active: Bool) -> some View {
        Text("VERLUST")
            .font(.system(size: 16, weight: .heavy, design: .rounded))
            .foregroundStyle(active ? .white : GK.ivory.opacity(0.3))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(active ? GK.crimson : Color.white.opacity(0.05))
                    .shadow(color: active ? GK.crimson.opacity(0.9) : .clear, radius: active ? 8 : 0)
            )
            .padding(.horizontal, 36)
    }
}

struct CardGambleOverlay: View {
    let amount: Int
    let history: [PlayingCard]
    let revealed: PlayingCard?
    let busy: Bool
    let onRed: () -> Void
    let onBlack: () -> Void
    let onTake: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.78).ignoresSafeArea()
            VStack(spacing: 14) {
                Text("KARTENRISIKO")
                    .font(.system(size: 26, weight: .black, design: .serif))
                    .foregroundStyle(GK.gold)
                Text("\(KT.string(amount)) KT")
                    .font(.system(size: 22, weight: .bold, design: .monospaced))
                    .foregroundStyle(GK.ledAmber)
                    .shadow(color: GK.ledAmber.opacity(0.7), radius: 6)
                PlayingCardView(card: revealed)
                    .frame(width: 150, height: 210)
                Text("Letzte Karten")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(GK.ivory.opacity(0.6))
                HStack(spacing: 6) {
                    ForEach(history.suffix(6)) { card in
                        MiniCard(card: card)
                    }
                    if history.isEmpty {
                        Text("Noch keine Karte")
                            .font(.caption)
                            .foregroundStyle(GK.ivory.opacity(0.5))
                    }
                }
                .frame(height: 64)
                HStack(spacing: 10) {
                    ArcadeButton(title: "ROT", fill: GK.redFill, disabled: busy || revealed != nil, action: onRed)
                    ArcadeButton(title: "SCHWARZ", fill: GK.navyFill, disabled: busy || revealed != nil, action: onBlack)
                }
                ArcadeButton(title: "EINSAMMELN", fill: GK.goldFill, foreground: .black, disabled: busy, action: onTake)
            }
            .padding(18)
        }
    }
}

struct PlayingCardView: View {
    var card: PlayingCard?

    var body: some View {
        ZStack {
            if let card {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(GK.ivory)
                VStack {
                    HStack {
                        Text("\(card.rankLabel)\(card.suitSymbol)")
                            .font(.system(size: 18, weight: .heavy, design: .serif))
                        Spacer()
                    }
                    Spacer()
                    Text(card.suitSymbol)
                        .font(.system(size: 54))
                    Spacer()
                    HStack {
                        Spacer()
                        Text("\(card.rankLabel)\(card.suitSymbol)")
                            .font(.system(size: 18, weight: .heavy, design: .serif))
                            .rotationEffect(.degrees(180))
                    }
                }
                .foregroundStyle(card.isRed ? GK.crimson : Color.black)
                .padding(10)
            } else {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(LinearGradient(
                        colors: [Color(red: 0.45, green: 0.05, blue: 0.10), Color(red: 0.18, green: 0.02, blue: 0.05)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ))
                CrownMark(size: 64)
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(GK.gold, lineWidth: 3)
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.black.opacity(0.4), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.45), radius: 10, y: 6)
    }
}

private struct MiniCard: View {
    let card: PlayingCard

    var body: some View {
        VStack(spacing: 0) {
            Text(card.rankLabel)
                .font(.system(size: 12, weight: .heavy, design: .serif))
            Text(card.suitSymbol)
                .font(.system(size: 12))
        }
        .foregroundStyle(card.isRed ? GK.crimson : Color.black)
        .frame(width: 36, height: 52)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(GK.ivory)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(GK.gold.opacity(0.7), lineWidth: 1))
        )
    }
}

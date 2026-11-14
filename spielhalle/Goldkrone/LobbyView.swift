import SwiftUI

struct LobbyView: View {
    @EnvironmentObject private var wallet: WalletStore
    let onPlay: (GameKind) -> Void
    let onStats: () -> Void
    let onHint: () -> Void
    @State private var toast: String?

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 14) {
                    header
                    balancePill
                    bonusCard
                    ForEach(GameKind.allCases) { game in
                        GameTile(game: game) { onPlay(game) }
                    }
                    toggleRow
                    if let toast {
                        Text(toast)
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(GK.ledGreen)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 20)
            }
            PlayMoneyFooter()
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            CrownMark(size: 58)
            VStack(alignment: .leading, spacing: 2) {
                Text("GOLDKRONE")
                    .font(.system(size: 28, weight: .black, design: .serif))
                    .foregroundStyle(GK.goldFill)
                    .shadow(color: GK.gold.opacity(0.45), radius: 6)
                Text("SPIELHALLE")
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                    .tracking(3.4)
                    .foregroundStyle(GK.ivory.opacity(0.8))
            }
            Spacer()
        }
        .padding(.top, 6)
    }

    private var balancePill: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("GUTHABEN")
                    .font(.system(size: 10, weight: .heavy, design: .rounded))
                    .tracking(1.2)
                    .foregroundStyle(GK.ledAmber.opacity(0.75))
                Text("\(KT.string(wallet.balance)) KT")
                    .font(.system(size: 26, weight: .bold, design: .monospaced))
                    .foregroundStyle(GK.ledAmber)
                    .shadow(color: GK.ledAmber.opacity(0.7), radius: 6)
            }
            Spacer()
            Text("Kronentaler")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(GK.ivory.opacity(0.7))
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.black.opacity(0.55))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(GK.gold.opacity(0.7), lineWidth: 1.2)
                )
        )
    }

    private var bonusCard: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text("TAGESBONUS")
                    .font(.system(size: 12, weight: .heavy, design: .rounded))
                    .foregroundStyle(GK.gold)
                if wallet.canClaimDailyBonus {
                    Text("+\(KT.string(wallet.upcomingBonus)) KT")
                        .font(.system(size: 18, weight: .bold, design: .monospaced))
                        .foregroundStyle(GK.ledGreen)
                    Text(wallet.streak > 0 ? "Serie: \(wallet.streak) Tage" : "Hol dir dein Spielgeld")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(GK.ivory.opacity(0.7))
                } else {
                    Text("Schon abgeholt")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(GK.ivory)
                    Text("Serie: \(wallet.streak) · morgen wieder")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(GK.ivory.opacity(0.7))
                }
            }
            Spacer()
            if wallet.canClaimDailyBonus {
                Button {
                    let amount = wallet.claimDailyBonus()
                    if amount > 0 {
                        toast = "+\(KT.string(amount)) KT Tagesbonus"
                        SoundEngine.shared.bonus()
                        Haptics.win()
                    }
                } label: {
                    Text("ABHOLEN")
                        .font(.system(size: 13, weight: .heavy, design: .rounded))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(Capsule().fill(GK.goldFill))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(GK.panel.opacity(0.9))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(GK.gold.opacity(0.35), lineWidth: 1))
        )
    }

    private var toggleRow: some View {
        HStack(spacing: 8) {
            iconButton(system: "chart.bar.fill", label: "Statistik", active: true, action: onStats)
            iconButton(system: wallet.soundOn ? "speaker.wave.2.fill" : "speaker.slash.fill", label: "Ton", active: wallet.soundOn) {
                wallet.soundOn.toggle()
            }
            iconButton(system: "iphone.radiowaves.left.and.right", label: "Haptik", active: wallet.hapticsOn) {
                wallet.hapticsOn.toggle()
            }
            iconButton(system: "info.circle.fill", label: "Hinweis", active: true, action: onHint)
            if wallet.canRefill {
                iconButton(system: "plus.circle.fill", label: "Auffüllen", active: true) {
                    wallet.refill()
                    toast = "+\(KT.string(WalletStore.refillAmount)) KT aufgefüllt"
                    SoundEngine.shared.bonus()
                }
            }
        }
    }

    private func iconButton(system: String, label: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: system)
                    .font(.system(size: 16, weight: .semibold))
                Text(label)
                    .font(.system(size: 10, weight: .bold, design: .rounded))
            }
            .foregroundStyle(active ? GK.gold : GK.ivory.opacity(0.45))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.black.opacity(0.35))
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

private struct GameTile: View {
    let game: GameKind
    let action: () -> Void
    @State private var glow = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                HStack(spacing: 4) {
                    ForEach(previewSymbols, id: \.self) { symbol in
                        SymbolTile(id: symbol, highlighted: glow && symbol == previewSymbols[0])
                            .frame(width: 40, height: 40)
                    }
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(game.title)
                        .font(.system(size: 17, weight: .black, design: .serif))
                        .foregroundStyle(GK.ivory)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Text(game.subtitle)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(GK.gold.opacity(0.9))
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                }
                .layoutPriority(1)
                Spacer()
                Text("SPIELEN")
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(GK.goldFill))
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(
                        LinearGradient(colors: [accent.opacity(0.55), Color.black.opacity(0.55)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(GK.gold.opacity(glow ? 0.95 : 0.35), lineWidth: 1.6)
                    )
                    .shadow(color: accent.opacity(glow ? 0.55 : 0.15), radius: glow ? 14 : 4)
            )
        }
        .buttonStyle(.plain)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.3).repeatForever(autoreverses: true)) {
                glow = true
            }
        }
        .accessibilityLabel("\(game.title) spielen")
    }

    private var previewSymbols: [String] {
        switch game {
        case .fruchtfeuer: return ["cherry", "seven", "bell"]
        case .sphinx: return ["book", "pharaoh", "eye"]
        case .joker: return ["joker", "star", "seven"]
        }
    }

    private var accent: Color {
        switch game {
        case .fruchtfeuer: return Color(red: 0.85, green: 0.25, blue: 0.12)
        case .sphinx: return GK.goldDeep
        case .joker: return Color(red: 0.55, green: 0.25, blue: 0.85)
        }
    }
}

struct DisclaimerView: View {
    let onAccept: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.82).ignoresSafeArea()
            Panel {
                VStack(spacing: 14) {
                    CrownMark(size: 64)
                    Text("GOLDKRONE")
                        .font(.system(size: 26, weight: .black, design: .serif))
                        .foregroundStyle(GK.goldFill)
                    Text("Nur Spielgeld. Keine Echtgeld-Einsätze, keine Auszahlungen, keine Käufe. Kronentaler haben keinen realen Wert.")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(GK.ivory)
                        .multilineTextAlignment(.center)
                    Text("Diese Spielhalle ist ein Unterhaltungsspiel. Es gibt keine Gewinne in echtem Geld, keine Einzahlungen und nichts zu kaufen.")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(GK.ivory.opacity(0.75))
                        .multilineTextAlignment(.center)
                    ArcadeButton(title: "VERSTANDEN — NUR SPIELGELD", fill: GK.goldFill, foreground: .black, action: onAccept)
                    Text("Nur Spielgeld – keine echten Gewinne")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(GK.ivory.opacity(0.6))
                }
            }
            .padding(20)
        }
    }
}

struct StatsPanel: View {
    @EnvironmentObject private var wallet: WalletStore
    let onClose: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.72).ignoresSafeArea()
            Panel {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Statistik")
                            .font(.system(size: 22, weight: .black, design: .serif))
                            .foregroundStyle(GK.gold)
                        Spacer()
                        Button("Schließen", action: onClose)
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(GK.ivory)
                    }
                    stat("Drehungen", KT.string(wallet.totalSpins))
                    stat("Einsatz gesamt", "\(KT.string(wallet.totalBet)) KT")
                    stat("Gewinn gesamt", "\(KT.string(wallet.totalWon)) KT")
                    stat("Größter Gewinn", "\(KT.string(wallet.biggestWin)) KT")
                    stat("Quote", percent(wallet.overallRTP))
                    Divider().overlay(GK.gold.opacity(0.4))
                    ForEach(GameKind.allCases) { game in
                        let record = wallet.record(for: game)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(game.title)
                                .font(.system(size: 14, weight: .heavy, design: .rounded))
                                .foregroundStyle(GK.ivory)
                            Text("\(record.spins) Drehungen · Quote \(percent(record.rtp)) · Max \(KT.string(record.biggest)) KT")
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                .foregroundStyle(GK.ivory.opacity(0.7))
                        }
                    }
                    Text("Die Quote ist dein Spielgeld-Verlauf, kein Versprechen.")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(GK.ivory.opacity(0.55))
                }
            }
            .padding(18)
        }
    }

    private func stat(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(GK.ivory.opacity(0.75))
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundStyle(GK.ledAmber)
        }
        .font(.system(size: 14, weight: .medium, design: .rounded))
    }

    private func percent(_ value: Double) -> String {
        if value == 0 { return "—" }
        return String(format: "%.1f %%", value * 100)
    }
}

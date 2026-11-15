import SwiftUI

struct SlotGameView: View {
    @EnvironmentObject private var wallet: WalletStore
    @StateObject private var session: SlotSession
    let onExit: () -> Void
    private let scripted: Bool
    private let autoSpin: Bool
    @State private var didAutoSpin = false

    init(game: GameKind, shot: Screenshot?, onExit: @escaping () -> Void) {
        _session = StateObject(wrappedValue: SlotSession(game: game, shot: shot, wallet: WalletStore.shared))
        self.onExit = onExit
        self.scripted = shot != nil
        self.autoSpin = shot == .spin
    }

    var body: some View {
        GeometryReader { geo in
            let landscape = geo.size.width > geo.size.height + 40
            let reelHeight = landscape
                ? min(geo.size.height - 150, geo.size.width * 0.42)
                : min(geo.size.width / 1.15, geo.size.height * 0.42)
            ZStack {
                ArcadeBackground()
                Group {
                    if landscape {
                        HStack(alignment: .top, spacing: 10) {
                            VStack(spacing: 8) {
                                header
                                ledRow
                                if session.freeSpinTotal > 0 { freeSpinBanner }
                                bezel.frame(height: max(160, reelHeight))
                                statusLine
                            }
                            controls.frame(width: min(300, geo.size.width * 0.32))
                        }
                    } else {
                        VStack(spacing: 8) {
                            header
                            ledRow
                            if session.freeSpinTotal > 0 { freeSpinBanner }
                            bezel.frame(height: max(170, reelHeight))
                            statusLine
                            controls
                            Spacer(minLength: 0)
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.top, 6)
                .padding(.bottom, 36)

                overlayLayer

                VStack {
                    Spacer()
                    PlayMoneyFooter()
                }
            }
        }
        .onAppear {
            guard autoSpin, !didAutoSpin else { return }
            didAutoSpin = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                session.spinTapped()
            }
        }
        .onDisappear {
            if !scripted { session.shutdown() }
        }
    }

    private var statusLine: some View {
        Text(session.statusText)
            .font(.system(size: 14, weight: .bold, design: .rounded))
            .foregroundStyle(GK.gold)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .frame(maxWidth: .infinity)
    }

    private var header: some View {
        HStack(spacing: 10) {
            Button(action: onExit) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(GK.gold)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(Color.black.opacity(0.35)))
            }
            .accessibilityLabel("Zurück zur Halle")
            .accessibilityIdentifier("back-button")
            VStack(alignment: .leading, spacing: 0) {
                Text(session.game.title)
                    .font(.system(size: 18, weight: .black, design: .serif))
                    .foregroundStyle(GK.ivory)
                Text("\(session.game.lineCount) Linien · \(KT.string(session.lineBet)) KT / Linie")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(GK.ivory.opacity(0.65))
            }
            Text("Stufe \(wallet.level)")
                .font(.system(size: 11, weight: .heavy, design: .rounded))
                .foregroundStyle(.black)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Capsule().fill(GK.goldFill))
            Spacer()
            Button {
                session.overlay = .paytable
            } label: {
                Image(systemName: "list.number")
                    .foregroundStyle(GK.gold)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(Color.black.opacity(0.35)))
            }
            .accessibilityLabel("Gewinntabelle")
        }
    }

    private var ledRow: some View {
        HStack(spacing: 6) {
            LEDReadout(title: "GEWINN", value: KT.string(session.shownWin), accent: GK.ledGreen)
            LEDReadout(title: "EINSATZ", value: KT.string(session.totalBet))
            LEDReadout(title: "GUTHABEN", value: KT.string(wallet.balance), accent: GK.ledAmber)
        }
    }

    private var freeSpinBanner: some View {
        HStack(spacing: 8) {
            if let special = session.specialSymbol {
                SymbolTile(id: special, highlighted: true)
                    .frame(width: 28, height: 28)
                Text(SymbolName.of(special))
                    .font(.system(size: 12, weight: .heavy, design: .rounded))
            }
            Text("FREISPIEL \(max(session.freeSpinNumber, 1))/\(session.freeSpinTotal)")
                .font(.system(size: 13, weight: .heavy, design: .rounded))
                .foregroundStyle(Color.black)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Capsule().fill(GK.goldFill))
    }

    private var bezel: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color(white: 0.96), Color(white: 0.78), Color(white: 0.92)],
                        startPoint: .top, endPoint: .bottom
                    )
                )
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color(white: 0.35), lineWidth: 3)
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.8), lineWidth: 2)
                .padding(4)
            VStack {
                lampRow
                Spacer()
                lampRow
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 4)
            ReelBoard(
                columns: session.grid,
                pool: session.game.pool,
                lines: session.game.lines,
                spinning: session.spinning,
                spinID: session.spinID,
                turbo: session.turbo,
                quickStopToken: session.quickStopToken,
                anticipateFrom: session.anticipateFrom,
                highlighted: session.highlighted,
                winLines: session.lineWins,
                forcedReels: session.forcedReels,
                onReelStop: { session.reelDidStop($0) }
            )
            .padding(.horizontal, 14)
            .padding(.vertical, 16)
        }
    }

    private var lampRow: some View {
        HStack(spacing: 0) {
            ForEach(0..<12, id: \.self) { index in
                Circle()
                    .fill(index.isMultiple(of: 2) ? GK.gold : GK.crimson)
                    .frame(width: 6, height: 6)
                    .shadow(color: (index.isMultiple(of: 2) ? GK.gold : GK.crimson).opacity(0.9), radius: 3)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var controls: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Button {
                    session.overlay = .stake
                } label: {
                    VStack(spacing: 0) {
                        Text("EINSATZ")
                            .font(.system(size: 9, weight: .heavy, design: .rounded))
                            .foregroundStyle(GK.gold.opacity(0.8))
                        Text("\(KT.string(session.totalBet)) KT")
                            .font(.system(size: 16, weight: .bold, design: .monospaced))
                            .foregroundStyle(GK.ledAmber)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.black.opacity(0.45))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(GK.gold.opacity(0.7), lineWidth: 1))
                    )
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("stake-button")
                ArcadeButton(
                    title: session.turbo ? "TURBO" : "TURBO",
                    fill: session.turbo ? GK.goldFill : GK.navyFill,
                    foreground: session.turbo ? .black : GK.ivory
                ) { session.toggleTurbo() }
                .frame(width: 92)
            }
            HStack(spacing: 8) {
                ArcadeButton(
                    title: session.spinning ? "STOP" : "START",
                    fill: GK.goldFill,
                    foreground: .black,
                    disabled: !session.canSpin && !session.spinning,
                    identifier: "start-button"
                ) { session.primaryButton() }
                ArcadeButton(
                    title: "RISIKO",
                    fill: GK.redFill,
                    disabled: !session.risikoEnabled,
                    identifier: "risiko-button"
                ) { session.openChooser() }
                .shadow(color: session.risikoEnabled ? GK.crimson.opacity(0.7) : .clear, radius: 8)
            }
            HStack(spacing: 8) {
                if session.phase == .presenting && session.pendingWin > 0 {
                    ArcadeButton(title: "EINSAMMELN", fill: GK.navyFill, identifier: "collect-button") { session.takeWin() }
                }
                if let left = session.autoplayLeft {
                    ArcadeButton(title: "STOP \(left)", fill: GK.redFill, identifier: "auto-button") { session.stopAutoplayNow() }
                } else {
                    ArcadeButton(title: "AUTO", disabled: !session.canSpin, identifier: "auto-button") { session.overlay = .autoMenu }
                }
            }
        }
    }

    @ViewBuilder
    private var overlayLayer: some View {
        switch session.overlay {
        case .none:
            EmptyView()
        case .choose:
            ChooseGambleOverlay(
                amount: session.pendingWin,
                onLadder: { session.openLadder() },
                onCards: { session.openCards() },
                onCollect: { session.takeWin() }
            )
        case .ladder:
            LadderOverlay(
                base: max(session.ladderBase, 1),
                level: session.ladderLevel,
                busy: session.gambleBusy,
                onClimb: { session.climbLadder() },
                onTake: { session.takeWin() }
            )
        case .cards:
            CardGambleOverlay(
                amount: session.pendingWin,
                history: session.cardHistory,
                revealed: session.revealedCard,
                busy: session.gambleBusy,
                onRed: { session.guessCard(red: true) },
                onBlack: { session.guessCard(red: false) },
                onTake: { session.takeWin() }
            )
        case .celebration(let mega):
            CelebrationOverlay(
                mega: mega,
                amount: session.shownWin,
                frozenCoins: scripted,
                onCollect: { session.collectFromCelebration() },
                onRisk: { session.openChooser() }
            )
        case .paytable:
            PaytableOverlay(game: session.game) { session.overlay = .none }
        case .stake:
            StakePicker(current: session.totalBet) { amount in
                session.selectBet(amount)
            } onClose: {
                session.overlay = .none
            }
        case .autoMenu:
            AutoMenuOverlay(
                onPick: { count in session.startAutoplay(count) },
                onClose: { session.overlay = .none }
            )
        case .refill:
            RefillOverlay(
                onRefill: { session.refill() },
                onClose: { session.overlay = .none }
            )
        }
    }
}

private struct PaytableOverlay: View {
    let game: GameKind
    let onClose: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.72).ignoresSafeArea()
            Panel {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Gewinntabelle")
                            .font(.system(size: 22, weight: .black, design: .serif))
                            .foregroundStyle(GK.gold)
                        Spacer()
                        Button("Schließen", action: onClose)
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(GK.ivory)
                    }
                    Text(game.title)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(GK.ivory.opacity(0.7))
                    ScrollView {
                        VStack(spacing: 8) {
                            ForEach(game.payRows) { row in
                                HStack(spacing: 10) {
                                    SymbolTile(id: row.symbol)
                                        .frame(width: 44, height: 44)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(SymbolName.of(row.symbol))
                                            .font(.system(size: 14, weight: .heavy, design: .rounded))
                                            .foregroundStyle(GK.ivory)
                                        Text(row.detail)
                                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                                            .foregroundStyle(GK.ledAmber)
                                    }
                                    Spacer(minLength: 0)
                                }
                            }
                            Text(game.payNote)
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundStyle(GK.ivory.opacity(0.8))
                                .padding(.top, 6)
                        }
                    }
                    .frame(maxHeight: 380)
                }
            }
            .padding(16)
        }
    }
}

private struct StakePicker: View {
    let current: Int
    let onPick: (Int) -> Void
    let onClose: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.72).ignoresSafeArea()
            Panel {
                VStack(spacing: 8) {
                    Text("EINSATZ WÄHLEN")
                        .font(.system(size: 22, weight: .black, design: .serif))
                        .foregroundStyle(GK.gold)
                    Text("Nur Spielgeld. Höherer Einsatz, höhere Kronentaler-Gewinne.")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(GK.ivory.opacity(0.75))
                        .multilineTextAlignment(.center)
                    ForEach(WalletStore.betSteps, id: \.self) { step in
                        ArcadeButton(
                            title: "\(KT.string(step)) KT",
                            fill: step == current ? GK.goldFill : GK.navyFill,
                            foreground: step == current ? .black : GK.ivory,
                            identifier: "stake-\(step)"
                        ) { onPick(step) }
                    }
                    ArcadeButton(title: "SCHLIESSEN", fill: GK.redFill, action: onClose)
                }
            }
            .padding(18)
        }
    }
}

private struct AutoMenuOverlay: View {
    let onPick: (Int) -> Void
    let onClose: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.72).ignoresSafeArea()
            Panel {
                VStack(spacing: 10) {
                    Text("AUTOPLAY")
                        .font(.system(size: 22, weight: .black, design: .serif))
                        .foregroundStyle(GK.gold)
                    Text("Stoppt bei Freispielen, großem Gewinn ab 15× und wenn das Guthaben nicht reicht.")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(GK.ivory.opacity(0.8))
                        .multilineTextAlignment(.center)
                    ForEach([10, 25, 50, 100], id: \.self) { count in
                        ArcadeButton(title: "\(count) DREHUNGEN", fill: GK.navyFill) { onPick(count) }
                    }
                    ArcadeButton(title: "ABBRECHEN", fill: GK.goldFill, foreground: .black, action: onClose)
                }
            }
            .padding(22)
        }
    }
}

private struct RefillOverlay: View {
    let onRefill: () -> Void
    let onClose: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.75).ignoresSafeArea()
            Panel {
                VStack(spacing: 12) {
                    CrownMark(size: 52)
                    Text("Spielgeld aufgebraucht")
                        .font(.system(size: 20, weight: .black, design: .serif))
                        .foregroundStyle(GK.gold)
                    Text("Kronentaler haben keinen Wert. Du bekommst \(KT.string(WalletStore.refillAmount)) KT gratis, damit du weiterspielen kannst.")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(GK.ivory.opacity(0.85))
                        .multilineTextAlignment(.center)
                    ArcadeButton(title: "GRATIS AUFFÜLLEN", fill: GK.goldFill, foreground: .black, action: onRefill)
                    Button("Später", action: onClose)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(GK.ivory.opacity(0.7))
                }
            }
            .padding(22)
        }
    }
}

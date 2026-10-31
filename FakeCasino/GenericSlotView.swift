import SwiftUI

/// Pulsing scale effect for winning symbols.
struct WinPulse: ViewModifier {
    let active: Bool
    @State private var on = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(active && on ? 1.13 : 1.0)
            .onChange(of: active) { _, newValue in
                if newValue {
                    withAnimation(.easeInOut(duration: 0.38).repeatForever(autoreverses: true)) {
                        on = true
                    }
                } else {
                    withAnimation(.easeOut(duration: 0.15)) { on = false }
                }
            }
    }
}

extension View {
    func winPulse(active: Bool) -> some View {
        modifier(WinPulse(active: active))
    }
}

// MARK: - View model

@MainActor
final class GenericSlotViewModel: ObservableObject {
    let config: SlotMachineConfig
    let betOptions = [1, 2, 5, 10, 25, 50]
    @Published var betIndex = 2

    var betPerLine: Int { betOptions[betIndex] }
    var totalBet: Int { betPerLine * config.lineCount }
    var betLocked: Bool { isSpinning || freeSpinsRemaining > 0 }

    @Published var targetGrid: [[String]]
    @Published var spinID = 0
    @Published var reelDurations: [Double] = []
    @Published var anticipationReels: Set<Int> = []
    @Published var isSpinning = false
    @Published var highlight: Set<GridPosition> = []
    @Published var displayedWin = 0
    @Published var message: String
    @Published var freeSpinsRemaining = 0
    @Published var freeSpinsTotalWin = 0
    @Published var lastMultiplier: Int?
    @Published var celebrationTier: WinTier?
    @Published var celebrationAmount = 0

    private var pendingResult: GenericSpinResult?
    private var celebrationToken = 0
    private var rng = SystemRandomNumberGenerator()

    init(config: SlotMachineConfig) {
        self.config = config
        self.targetGrid = GenericSlotEngine.randomGrid(config: config)
        self.message = "Bereit für \(config.name)?"
    }

    func increaseBet() {
        if betIndex < betOptions.count - 1 { betIndex += 1 }
    }

    func decreaseBet() {
        if betIndex > 0 { betIndex -= 1 }
    }

    func fillerSymbol() -> String {
        GenericSlotEngine.randomSymbol(config: config, using: &rng)
    }

    func spin(wallet: WalletStore) {
        guard !isSpinning else { return }
        let isFreeSpin = freeSpinsRemaining > 0
        if isFreeSpin {
            freeSpinsRemaining -= 1
        } else {
            guard wallet.placeBet(totalBet) else {
                message = "Nicht genug Coins – hol dir den Gratis-Refill!"
                return
            }
        }
        wallet.recordSpin()
        let result = GenericSlotEngine.spin(config: config, betPerLine: betPerLine, totalBet: totalBet)
        pendingResult = result
        targetGrid = result.grid
        highlight = []
        displayedWin = 0
        lastMultiplier = nil
        celebrationTier = nil
        isSpinning = true
        message = isFreeSpin ? "Freispiel läuft …" : "Die Walzen drehen …"

        // Anticipation: two scatters in the first two reels -> the rest spins longer.
        var durations = (0..<config.reels).map { 0.95 + Double($0) * 0.30 }
        anticipationReels = []
        if config.scatterSymbol != nil, config.reels == 5,
           config.freeSpinsAwarded > 0 || !config.scatterPays.isEmpty {
            let scatterID = config.scatterSymbol?.id
            let early = (0..<2).reduce(0) { partial, reel in
                partial + result.grid[reel].filter { $0 == scatterID }.count
            }
            if early == 2 {
                anticipationReels = Set(2..<config.reels)
                for reel in 2..<config.reels {
                    durations[reel] += 0.85
                }
            }
        }
        reelDurations = durations
        spinID += 1
    }

    /// Called by the reel view once every reel has landed.
    func finishSpin(wallet: WalletStore) {
        guard let result = pendingResult else {
            isSpinning = false
            return
        }
        pendingResult = nil

        var win = result.rawTotal
        // Free-spin multiplier (feature spins are those started while spins remained).
        if startedAsFreeSpin, config.freeSpinMultiplier > 1 {
            win *= config.freeSpinMultiplier
        }
        // Random win multiplier (never combined with a free-spin feature per catalog).
        var appliedMultiplier: Int?
        if win > 0, config.randomMultiplierChance > 0,
           Double.random(in: 0..<1, using: &rng) < config.randomMultiplierChance {
            let multiplier = Int.random(in: 2...config.randomMultiplierMax, using: &rng)
            win *= multiplier
            appliedMultiplier = multiplier
        }
        lastMultiplier = appliedMultiplier

        var highlights = Set<GridPosition>()
        for lineWin in result.lineWins {
            for position in lineWin.positions {
                highlights.insert(position)
            }
        }

        // Free-spin trigger / retrigger
        var triggered = false
        if result.scatterCount >= 3, config.freeSpinsAwarded > 0 {
            triggered = true
            freeSpinsRemaining += config.freeSpinsAwarded
            if let scatterID = config.scatterSymbol?.id {
                for reel in 0..<config.reels {
                    for row in 0..<3 where result.grid[reel][row] == scatterID {
                        highlights.insert(GridPosition(reel: reel, row: row))
                    }
                }
            }
        } else if result.scatterWin > 0, let scatterID = config.scatterSymbol?.id {
            for reel in 0..<config.reels {
                for row in 0..<3 where result.grid[reel][row] == scatterID {
                    highlights.insert(GridPosition(reel: reel, row: row))
                }
            }
        }

        if win > 0 {
            wallet.addWin(win)
            if startedAsFreeSpin {
                freeSpinsTotalWin += win
            }
        }
        highlight = highlights
        displayedWin = win
        isSpinning = false

        if triggered {
            message = startedAsFreeSpin
                ? "Retrigger! +\(config.freeSpinsAwarded) Freispiele!"
                : "\(result.scatterCount)× Scatter! \(config.freeSpinsAwarded) Freispiele gewonnen!"
        } else if startedAsFreeSpin && freeSpinsRemaining == 0 {
            message = "Freispiele vorbei – Gesamtgewinn: \(freeSpinsTotalWin.grouped) Coins"
            freeSpinsTotalWin = 0
        } else if win > 0 {
            if let appliedMultiplier {
                message = "Multiplikator ×\(appliedMultiplier)! Gewinn: \(win.grouped) Coins!"
            } else {
                message = "Gewinn: \(win.grouped) Coins!"
            }
        } else {
            message = startedAsFreeSpin ? "Freispiel ohne Gewinn." : "Kein Gewinn – nochmal drehen!"
        }
        startedAsFreeSpin = false

        if let tier = WinTier.tier(win: win, totalBet: totalBet) {
            celebrationTier = tier
            celebrationAmount = win
            Haptics.win(big: true)
            celebrationToken += 1
            let token = celebrationToken
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 2_800_000_000)
                if token == celebrationToken {
                    celebrationTier = nil
                }
            }
        } else if win > 0 {
            Haptics.win(big: false)
        }
    }

    private var startedAsFreeSpin = false

    func noteSpinStarted(isFreeSpin: Bool) {
        startedAsFreeSpin = isFreeSpin
    }

    func dismissCelebration() {
        celebrationToken += 1
        celebrationTier = nil
    }
}

// MARK: - Screen

struct GenericSlotView: View {
    let config: SlotMachineConfig
    @EnvironmentObject private var wallet: WalletStore
    @StateObject private var vm: GenericSlotViewModel
    @State private var reelWidth: CGFloat = 360
    @State private var showInfo = false

    init(config: SlotMachineConfig) {
        self.config = config
        _vm = StateObject(wrappedValue: GenericSlotViewModel(config: config))
    }

    private var cellHeight: CGFloat {
        let columns = CGFloat(config.reels)
        let available = reelWidth - 20 - (columns - 1) * 6
        let width = available / columns
        return config.reels == 3 ? min(width, 118) : min(width * 1.02, 96)
    }

    var body: some View {
        ZStack {
            CasinoBackground()
            ScrollView {
                VStack(spacing: 14) {
                    if vm.freeSpinsRemaining > 0 {
                        freeSpinBanner
                    }
                    reelFrame
                    winDisplay
                    BetSelector(
                        betPerLine: vm.betPerLine,
                        totalBet: vm.totalBet,
                        locked: vm.betLocked,
                        onDecrease: vm.decreaseBet,
                        onIncrease: vm.increaseBet
                    )
                    SpinButton(
                        title: vm.isSpinning
                            ? "DREHT …"
                            : (vm.freeSpinsRemaining > 0 ? "FREISPIEL DREHEN (\(vm.freeSpinsRemaining))" : "DREHEN"),
                        enabled: !vm.isSpinning,
                        action: spin
                    )
                    RefillButton()
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 32)
            }
            if let tier = vm.celebrationTier {
                BigWinOverlay(tier: tier, amount: vm.celebrationAmount) {
                    vm.dismissCelebration()
                }
            }
        }
        .navigationTitle(config.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showInfo = true
                } label: {
                    Image(systemName: "info.circle")
                }
            }
        }
        .sheet(isPresented: $showInfo) {
            GenericPaytableSheet(config: config)
        }
    }

    private func spin() {
        vm.noteSpinStarted(isFreeSpin: vm.freeSpinsRemaining > 0)
        vm.spin(wallet: wallet)
    }

    private var freeSpinBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "sparkles")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(config.palette.accentColor)
            VStack(alignment: .leading, spacing: 2) {
                Text("FREISPIELE: noch \(vm.freeSpinsRemaining)")
                    .font(.system(.subheadline, design: .default).weight(.bold))
                    .foregroundStyle(.white)
                Text(config.freeSpinMultiplier > 1
                    ? "Alle Gewinne ×\(config.freeSpinMultiplier) · bisher gewonnen: \(vm.freeSpinsTotalWin.grouped)"
                    : "Bisher gewonnen: \(vm.freeSpinsTotalWin.grouped)")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.8))
            }
            Spacer()
        }
        .padding(12)
        .glassPanel(cornerRadius: 16)
    }

    private var reelFrame: some View {
        ZStack {
            PaletteArtwork(palette: config.palette, glowOpacity: 0.35)
            StripReelView(
                columns: vm.targetGrid,
                rows: 3,
                spinID: vm.spinID,
                reelDurations: vm.reelDurations,
                anticipationReels: vm.anticipationReels,
                highlighted: vm.highlight,
                cellSize: cellHeight,
                filler: { vm.fillerSymbol() },
                onReelStop: { _ in Haptics.reelStop() },
                onFinished: { vm.finishSpin(wallet: wallet) }
            ) { id, _, isHighlighted in
                cellView(id: id, isHighlighted: isHighlighted)
            }
            .padding(10)
        }
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(Color.white.opacity(0.14), lineWidth: 1)
        )
        .onGeometryChange(for: CGFloat.self) { proxy in
            proxy.size.width
        } action: { newWidth in
            reelWidth = newWidth
        }
    }

    private func cellView(id: String, isHighlighted: Bool) -> some View {
        let symbol = config.symbol(id: id)
        let tint = symbol.map { Color(hex: $0.tint) } ?? .white
        return ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.13), Color.black.opacity(0.18)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            if let symbol {
                SymbolArtView(art: symbol.art, tint: tint, size: cellHeight * 0.52)
                    .winPulse(active: isHighlighted)
            }
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(
                    isHighlighted ? Color(red: 0.98, green: 0.82, blue: 0.35) : Color.white.opacity(0.10),
                    lineWidth: isHighlighted ? 2 : 1
                )
        }
        .shadow(color: isHighlighted ? Color(red: 0.98, green: 0.82, blue: 0.35).opacity(0.55) : .clear, radius: 9)
    }

    private var winDisplay: some View {
        VStack(spacing: 5) {
            HStack(spacing: 8) {
                CoinIcon(size: 24)
                CountUpText(
                    value: vm.displayedWin,
                    font: .system(size: 26, weight: .black),
                    color: Color(red: 1.0, green: 0.85, blue: 0.35)
                )
                if let multiplier = vm.lastMultiplier {
                    Text("×\(multiplier)")
                        .font(.system(.subheadline, design: .default).weight(.black))
                        .foregroundStyle(Color(red: 0.22, green: 0.13, blue: 0.01))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(Color(red: 0.98, green: 0.82, blue: 0.35)))
                }
            }
            .frame(height: 30)
            Text(vm.message)
                .font(.system(.subheadline, design: .default).weight(.semibold))
                .foregroundStyle(.white.opacity(0.9))
                .multilineTextAlignment(.center)
                .frame(minHeight: 20)
        }
    }
}

// MARK: - Paytable sheet

struct GenericPaytableSheet: View {
    let config: SlotMachineConfig
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                CasinoBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        ForEach(sortedSymbols) { symbol in
                            symbolRow(symbol)
                        }
                        Divider().overlay(Color.white.opacity(0.25))
                        rulesText
                        Text("Nur Spielgeld – kein Echtgeld. Keine Käufe, keine Auszahlungen.")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Color(red: 0.98, green: 0.85, blue: 0.55))
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Auszahlung & Regeln")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fertig") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private var sortedSymbols: [SlotSymbolConfig] {
        config.symbols.sorted { lhs, rhs in
            (lhs.pays[5] ?? lhs.pays[3] ?? 0) > (rhs.pays[5] ?? rhs.pays[3] ?? 0)
        }
    }

    private func symbolRow(_ symbol: SlotSymbolConfig) -> some View {
        HStack(spacing: 12) {
            SymbolArtView(art: symbol.art, tint: Color(hex: symbol.tint), size: 26)
                .frame(width: 40, height: 40)
            VStack(alignment: .leading, spacing: 1) {
                Text(symbol.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                if symbol.isWild {
                    Text("Wild – ersetzt alle Symbole außer Scatter")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.65))
                } else if symbol.isScatter {
                    Text("Scatter – zählt überall")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.65))
                }
            }
            Spacer()
            paysText(for: symbol)
                .font(.subheadline)
                .monospacedDigit()
                .foregroundStyle(.white.opacity(0.9))
        }
    }

    private func paysText(for symbol: SlotSymbolConfig) -> Text {
        if config.reels == 3 {
            return Text("3× \(symbol.pays[3] ?? 0)")
        }
        var parts: [String] = []
        for count in [2, 3, 4, 5] {
            if let value = symbol.pays[count], value > 0 {
                parts.append("\(count)× \(value)")
            }
        }
        return Text(parts.isEmpty ? "–" : parts.joined(separator: " · "))
    }

    private var rulesText: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(config.lineCount) Linien · Auszahlung von links nach rechts · nur der höchste Gewinn pro Linie zählt. Beträge sind Vielfache des Linien-Einsatzes.")
            if let wild = config.wildSymbol {
                Text("\(wild.name) ist Wild und ersetzt alle Symbole außer Scatter.")
            }
            if let scatter = config.scatterSymbol {
                if !config.scatterPays.isEmpty {
                    let parts = [3, 4, 5].compactMap { count -> String? in
                        guard let value = config.scatterPays[count] else { return nil }
                        return "\(count)× \(value)×"
                    }
                    Text("\(scatter.name) (Scatter) zahlt überall: \(parts.joined(separator: " · ")) des Gesamteinsatzes.")
                }
                if config.freeSpinsAwarded > 0 {
                    Text("3+ Scatter starten \(config.freeSpinsAwarded) Freispiele"
                        + (config.freeSpinMultiplier > 1 ? " – alle Gewinne in den Freispielen zählen ×\(config.freeSpinMultiplier)." : ".")
                        + " Weitere Scatter in den Freispielen geben erneut \(config.freeSpinsAwarded) Freispiele dazu.")
                }
            }
            if config.randomMultiplierChance > 0 {
                Text("Zufalls-Multiplikator: Jeder Gewinn wird mit \(Int(config.randomMultiplierChance * 100)) % Wahrscheinlichkeit mit einem zufälligen Faktor zwischen 2× und \(config.randomMultiplierMax)× vervielfacht.")
            }
        }
        .font(.caption)
        .foregroundStyle(.white.opacity(0.78))
    }
}

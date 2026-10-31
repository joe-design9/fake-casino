import SwiftUI

// MARK: - Symbol rendering

/// Mochi Millions symbols: SF Symbols + drawn coin/gem shapes.
struct MochiSymbolView: View {
    let symbol: MochiSymbol
    var size: CGFloat = 34

    var body: some View {
        switch symbol {
        case .teddy:
            Image(systemName: "teddybear.fill")
                .font(.system(size: size * 0.95, weight: .semibold))
                .foregroundStyle(Color(red: 0.85, green: 0.62, blue: 0.42))
        case .diamond:
            DrawnShapeView(kind: .gem, tint: Color(red: 0.45, green: 0.85, blue: 1.0), size: size)
        case .star:
            Image(systemName: "star.fill")
                .font(.system(size: size * 0.92, weight: .semibold))
                .foregroundStyle(Color(red: 1.0, green: 0.82, blue: 0.30))
        case .heart:
            Image(systemName: "heart.fill")
                .font(.system(size: size * 0.92, weight: .semibold))
                .foregroundStyle(Color(red: 1.0, green: 0.40, blue: 0.55))
        case .coin:
            DrawnShapeView(kind: .coin, tint: Color(red: 1.0, green: 0.80, blue: 0.30), size: size)
        case .bell:
            Image(systemName: "bell.fill")
                .font(.system(size: size * 0.92, weight: .semibold))
                .foregroundStyle(Color(red: 1.0, green: 0.70, blue: 0.35))
        }
    }
}

// MARK: - View model

@MainActor
final class MochiMillionsViewModel: ObservableObject {
    let lineCount = 5
    let betOptions = [1, 2, 5, 10, 25, 50]
    @Published var betIndex = 2

    var betPerLine: Int { betOptions[betIndex] }
    var totalBet: Int { betPerLine * lineCount }

    @Published var targetGrid: [[MochiSymbol]]
    @Published var spinID = 0
    @Published var reelDurations: [Double] = []
    @Published var isSpinning = false
    @Published var highlight: Set<GridPosition> = []
    @Published var displayedWin = 0
    @Published var message = "Drei Walzen, purer Klassiker."
    @Published var celebrationTier: WinTier?
    @Published var celebrationAmount = 0

    private var pendingResult: MochiSpinResult?
    private var celebrationToken = 0
    private var rng = SystemRandomNumberGenerator()

    init() {
        targetGrid = MochiMillionsEngine.randomGrid()
    }

    func increaseBet() {
        if betIndex < betOptions.count - 1 { betIndex += 1 }
    }

    func decreaseBet() {
        if betIndex > 0 { betIndex -= 1 }
    }

    func fillerSymbol() -> MochiSymbol {
        MochiSymbol.random(using: &rng)
    }

    func spin(wallet: WalletStore) {
        guard !isSpinning else { return }
        guard wallet.placeBet(totalBet) else {
            message = "Nicht genug Coins – hol dir den Gratis-Refill!"
            return
        }
        wallet.recordSpin()
        let result = MochiMillionsEngine.spin(betPerLine: betPerLine)
        pendingResult = result
        targetGrid = result.grid
        highlight = []
        displayedWin = 0
        celebrationTier = nil
        isSpinning = true
        message = "Die Walzen drehen …"
        reelDurations = (0..<3).map { 0.85 + Double($0) * 0.30 }
        spinID += 1
    }

    func finishSpin(wallet: WalletStore) {
        guard let result = pendingResult else {
            isSpinning = false
            return
        }
        pendingResult = nil
        var highlights = Set<GridPosition>()
        for lineWin in result.lineWins {
            for position in lineWin.positions {
                highlights.insert(position)
            }
        }
        let win = result.totalWin
        if win > 0 {
            wallet.addWin(win)
        }
        highlight = highlights
        displayedWin = win
        isSpinning = false
        message = win > 0 ? "Gewinn: \(win.grouped) Coins!" : "Kein Gewinn – nochmal drehen!"

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

    func dismissCelebration() {
        celebrationToken += 1
        celebrationTier = nil
    }
}

// MARK: - Screen

struct MochiMillionsView: View {
    @EnvironmentObject private var wallet: WalletStore
    @StateObject private var vm = MochiMillionsViewModel()
    @State private var reelWidth: CGFloat = 360
    @State private var showInfo = false

    private let palette = MachinePalette(
        ["#2A0E16", "#7F1D2D", "#A62B3F"], accent: "#FB7185"
    )

    private var cellHeight: CGFloat {
        let available = reelWidth - 20 - 2 * 6
        return min(available / 3, 118)
    }

    var body: some View {
        ZStack {
            CasinoBackground()
            ScrollView {
                VStack(spacing: 14) {
                    reelFrame
                    winDisplay
                    BetSelector(
                        betPerLine: vm.betPerLine,
                        totalBet: vm.totalBet,
                        locked: vm.isSpinning,
                        onDecrease: vm.decreaseBet,
                        onIncrease: vm.increaseBet
                    )
                    SpinButton(
                        title: vm.isSpinning ? "DREHT …" : "DREHEN",
                        enabled: !vm.isSpinning,
                        action: { vm.spin(wallet: wallet) }
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
        .navigationTitle("Mochi Millions")
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
            MochiPaytableSheet()
        }
    }

    private var reelFrame: some View {
        ZStack {
            PaletteArtwork(palette: palette, glowOpacity: 0.35)
            StripReelView(
                columns: vm.targetGrid,
                rows: 3,
                spinID: vm.spinID,
                reelDurations: vm.reelDurations,
                anticipationReels: [],
                highlighted: vm.highlight,
                cellSize: cellHeight,
                filler: { vm.fillerSymbol() },
                onReelStop: { _ in Haptics.reelStop() },
                onFinished: { vm.finishSpin(wallet: wallet) }
            ) { symbol, _, isHighlighted in
                cellView(symbol: symbol, isHighlighted: isHighlighted)
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

    private func cellView(symbol: MochiSymbol, isHighlighted: Bool) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.13), Color.black.opacity(0.18)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            MochiSymbolView(symbol: symbol, size: cellHeight * 0.52)
                .winPulse(active: isHighlighted)
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

private struct MochiPaytableSheet: View {
    @Environment(\.dismiss) private var dismiss

    private let rows: [(MochiSymbol, String)] = [
        (.teddy, "100×"),
        (.diamond, "50×"),
        (.star, "25×"),
        (.heart, "15×"),
        (.coin, "10×"),
        (.bell, "8×"),
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                CasinoBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(rows, id: \.0) { row in
                            HStack(spacing: 12) {
                                MochiSymbolView(symbol: row.0, size: 26)
                                    .frame(width: 40, height: 40)
                                Text(row.0.displayName)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.white)
                                Spacer()
                                Text(row.1)
                                    .font(.subheadline)
                                    .monospacedDigit()
                                    .foregroundStyle(.white.opacity(0.9))
                            }
                        }
                        Divider().overlay(Color.white.opacity(0.25))
                        Text("3 Gleiche auf einer Linie zahlen das angegebene Vielfache des Linien-Einsatzes. 5 Linien über 3 Walzen (3 Reihen, 2 Diagonalen).\n\nJuwelen-Mix: Diamant, Stern und Herz in beliebiger Kombination auf einer Linie zahlen 4× den Linien-Einsatz.")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.78))
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
}

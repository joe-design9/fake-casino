import SwiftUI

// MARK: - View model

@MainActor
final class MochiMillionsViewModel: ObservableObject {
    let betOptions = [1, 2, 5, 10, 25, 50]
    @Published var betIndex = 2

    var betPerLine: Int { betOptions[betIndex] }
    var totalBet: Int { betPerLine * SlotMath.threeReelLines.count }

    @Published var displayGrid: [[MochiSymbol]] = MochiMillionsEngine.randomGrid()
    @Published var isSpinning = false
    @Published var displayedWin = 0
    @Published var highlight: Set<String> = []
    @Published var message = "Drei Walzen, ein Traum: Mochi Millions!"

    private var rng = SystemRandomNumberGenerator()

    func increaseBet() {
        if betIndex < betOptions.count - 1 { betIndex += 1 }
    }

    func decreaseBet() {
        if betIndex > 0 { betIndex -= 1 }
    }

    func spin(wallet: WalletStore) {
        guard !isSpinning else { return }
        guard wallet.placeBet(totalBet) else {
            message = "Nicht genug Coins – hol dir den Gratis-Refill!"
            return
        }
        wallet.recordSpin()
        isSpinning = true
        displayedWin = 0
        highlight = []
        message = "Die Walzen drehen …"

        let result = MochiMillionsEngine.spin(betPerLine: betPerLine)
        Task { await animate(to: result, wallet: wallet) }
    }

    private func animate(to result: MochiSpinResult, wallet: WalletStore) async {
        var spinning = [Bool](repeating: true, count: 3)
        var elapsed = 0
        while spinning.contains(true) {
            try? await Task.sleep(nanoseconds: 70_000_000)
            elapsed += 70
            var grid = displayGrid
            for reel in 0..<3 where spinning[reel] {
                if elapsed >= 450 + reel * 350 {
                    spinning[reel] = false
                    grid[reel] = result.grid[reel]
                } else {
                    grid[reel] = (0..<3).map { _ in MochiSymbol.random(using: &rng) }
                }
            }
            displayGrid = grid
        }

        var highlights = Set<String>()
        for win in result.lineWins {
            for position in win.positions {
                highlights.insert("\(position.reel)-\(position.row)")
            }
        }
        highlight = highlights
        isSpinning = false

        if result.totalWin > 0 {
            wallet.addWin(result.totalWin)
            message = "Gewinn: \(result.totalWin.grouped) Coins!"
            let target = result.totalWin
            Task { await animateWinCounter(to: target) }
        } else {
            displayedWin = 0
            message = "Knapp daneben – der Teddy wartet schon."
        }
    }

    private func animateWinCounter(to target: Int) async {
        let steps = 24
        for step in 1...steps {
            displayedWin = target * step / steps
            try? await Task.sleep(nanoseconds: 30_000_000)
        }
        displayedWin = target
    }
}

// MARK: - Symbol artwork

struct MochiSymbolView: View {
    let symbol: MochiSymbol

    var body: some View {
        switch symbol {
        case .teddy:
            Image(systemName: "teddybear.fill")
                .font(.system(size: 34))
                .foregroundStyle(Color(red: 0.95, green: 0.55, blue: 0.65))
        case .diamond:
            Image(systemName: "suit.diamond.fill")
                .font(.system(size: 30))
                .foregroundStyle(.cyan)
        case .star:
            Image(systemName: "star.fill")
                .font(.system(size: 30))
                .foregroundStyle(.yellow)
        case .heart:
            Image(systemName: "suit.heart.fill")
                .font(.system(size: 30))
                .foregroundStyle(.red)
        case .coin:
            CoinIcon(size: 32)
        case .bell:
            Image(systemName: "bell.fill")
                .font(.system(size: 30))
                .foregroundStyle(Color(red: 1.0, green: 0.78, blue: 0.25))
        }
    }
}

// MARK: - Screen

struct MochiMillionsView: View {
    @EnvironmentObject private var wallet: WalletStore
    @StateObject private var vm = MochiMillionsViewModel()

    var body: some View {
        ZStack {
            CasinoBackground()
            ScrollView {
                VStack(spacing: 16) {
                    headerRow
                    gridView
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
                    paytableSection
                }
                .padding()
            }
        }
    }

    private var headerRow: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Mochi Millions")
                    .font(.system(.title2, design: .rounded).weight(.black))
                    .foregroundStyle(.white)
                Text("Der 3-Walzen-Klassiker")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
            }
            Spacer()
            BalancePill()
        }
    }

    private var gridView: some View {
        HStack(spacing: 8) {
            ForEach(0..<3, id: \.self) { reel in
                VStack(spacing: 8) {
                    ForEach(0..<3, id: \.self) { row in
                        tile(reel: reel, row: row)
                    }
                }
            }
        }
        .padding(12)
        .glassPanel()
    }

    private func tile(reel: Int, row: Int) -> some View {
        let isHighlighted = vm.highlight.contains("\(reel)-\(row)")
        return ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.10))
            MochiSymbolView(symbol: vm.displayGrid[reel][row])
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(
                    isHighlighted ? Color.yellow : Color.white.opacity(0.18),
                    lineWidth: isHighlighted ? 2.5 : 1
                )
        }
        .frame(maxWidth: .infinity)
        .frame(height: 78)
        .shadow(color: isHighlighted ? Color.yellow.opacity(0.6) : .clear, radius: 8)
    }

    private var winDisplay: some View {
        VStack(spacing: 4) {
            if vm.displayedWin > 0 {
                HStack(spacing: 8) {
                    CoinIcon(size: 26)
                    Text("+\(vm.displayedWin.grouped)")
                        .font(.system(size: 28, weight: .black, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(Color(red: 1.0, green: 0.85, blue: 0.35))
                }
            }
            Text(vm.message)
                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                .foregroundStyle(.white.opacity(0.9))
                .multilineTextAlignment(.center)
                .frame(minHeight: 20)
        }
    }

    private var paytableSection: some View {
        DisclosureGroup {
            VStack(alignment: .leading, spacing: 8) {
                ForEach([MochiSymbol.teddy, .diamond, .star, .heart, .coin, .bell], id: \.self) { symbol in
                    HStack(spacing: 10) {
                        MochiSymbolView(symbol: symbol)
                            .frame(width: 30, height: 30)
                            .scaleEffect(0.75)
                        Text(symbol.displayName)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                        Spacer()
                        Text("3× \(MochiSymbol.paytable[symbol] ?? 0)")
                            .font(.subheadline)
                            .monospacedDigit()
                            .foregroundStyle(.white.opacity(0.85))
                    }
                }
                Text("Juwelen-Mix: Diamant, Stern und Herz in beliebiger Mischung auf einer Linie zahlen "
                    + "\(MochiSymbol.jewelMixPayout)× den Linien-Einsatz. Auszahlungen pro Linien-Einsatz. "
                    + "Nur Spielgeld – kein Echtgeld.")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.75))
            }
            .padding(.top, 8)
        } label: {
            Text("Auszahlung & Regeln")
                .font(.system(.headline, design: .rounded).weight(.bold))
                .foregroundStyle(.white)
        }
        .tint(.white)
        .padding()
        .glassPanel()
    }
}

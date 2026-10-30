import SwiftUI

// MARK: - View model

@MainActor
final class BookOfMuseViewModel: ObservableObject {
    let betOptions = [1, 2, 5, 10, 25, 50]
    @Published var betIndex = 2

    var betPerLine: Int { betOptions[betIndex] }
    var totalBet: Int { betPerLine * SlotMath.fiveReelLines.count }
    var betLocked: Bool { isSpinning || specialSymbol != nil }

    @Published var displayGrid: [[BookSymbol]] = BookOfMuseEngine.randomGrid()
    @Published var isSpinning = false
    @Published var displayedWin = 0
    @Published var highlight: Set<String> = []
    @Published var message = "Bereit? Das Buch wartet auf dich."
    @Published var freeSpinsRemaining = 0
    @Published var freeSpinsTotalWin = 0
    @Published var specialSymbol: BookSymbol? = nil
    @Published var expandedReels: Set<Int> = []

    private var rng = SystemRandomNumberGenerator()

    func increaseBet() {
        if betIndex < betOptions.count - 1 { betIndex += 1 }
    }

    func decreaseBet() {
        if betIndex > 0 { betIndex -= 1 }
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
        isSpinning = true
        displayedWin = 0
        highlight = []
        expandedReels = []
        message = isFreeSpin ? "Freispiel läuft …" : "Die Walzen drehen …"

        let result = BookOfMuseEngine.spin(betPerLine: betPerLine, totalBet: totalBet)
        Task { await animate(to: result, wallet: wallet, wasFreeSpin: isFreeSpin) }
    }

    /// Staggered reel animation: reels stop one after another, the rest keep flickering.
    private func animate(to result: BookSpinResult, wallet: WalletStore, wasFreeSpin: Bool) async {
        var spinning = [Bool](repeating: true, count: 5)
        var elapsed = 0
        while spinning.contains(true) {
            try? await Task.sleep(nanoseconds: 70_000_000)
            elapsed += 70
            var grid = displayGrid
            for reel in 0..<5 where spinning[reel] {
                if elapsed >= 450 + reel * 300 {
                    spinning[reel] = false
                    grid[reel] = result.grid[reel]
                } else {
                    grid[reel] = (0..<3).map { _ in BookSymbol.random(using: &rng) }
                }
            }
            displayGrid = grid
        }
        settle(result: result, wallet: wallet, wasFreeSpin: wasFreeSpin)
    }

    private func settle(result: BookSpinResult, wallet: WalletStore, wasFreeSpin: Bool) {
        var total = result.lineWinTotal + result.scatterWin

        var highlights = Set<String>()
        for win in result.lineWins {
            for position in win.positions {
                highlights.insert("\(position.reel)-\(position.row)")
            }
        }
        if result.scatterCount >= 3 {
            for reel in 0..<5 {
                for row in 0..<3 where result.grid[reel][row] == .book {
                    highlights.insert("\(reel)-\(row)")
                }
            }
        }

        // Free-spin expanding symbol
        if wasFreeSpin, let special = specialSymbol {
            let expansion = BookOfMuseEngine.expandingWin(
                grid: result.grid,
                special: special,
                betPerLine: betPerLine
            )
            if expansion.amount > 0 {
                total += expansion.amount
                expandedReels = expansion.reels
                for reel in expansion.reels {
                    for row in 0..<3 {
                        highlights.insert("\(reel)-\(row)")
                    }
                }
            }
        }

        // Free-spin trigger / retrigger
        var triggered = false
        if result.scatterCount >= 3 {
            triggered = true
            if specialSymbol == nil {
                specialSymbol = BookSymbol.freeSpinCandidates.randomElement()
            }
            freeSpinsRemaining += BookOfMuseEngine.freeSpinsAwarded
        }

        if total > 0 {
            wallet.addWin(total)
            if wasFreeSpin {
                freeSpinsTotalWin += total
            }
        }

        highlight = highlights
        isSpinning = false

        if triggered {
            if wasFreeSpin {
                message = "Retrigger! +\(BookOfMuseEngine.freeSpinsAwarded) Freispiele!"
            } else {
                message = "\(result.scatterCount)× Buch! \(BookOfMuseEngine.freeSpinsAwarded) Freispiele – "
                    + "Spezialsymbol: \(specialSymbol?.displayName ?? "")"
            }
        } else if wasFreeSpin && freeSpinsRemaining == 0 {
            message = "Freispiele vorbei – Gesamtgewinn: \(freeSpinsTotalWin.grouped) Coins"
            specialSymbol = nil
            freeSpinsTotalWin = 0
        } else if total > 0 {
            message = "Gewinn: \(total.grouped) Coins!"
        } else {
            message = wasFreeSpin ? "Freispiel ohne Gewinn." : "Kein Gewinn – nochmal drehen!"
        }

        if total > 0 {
            Task { await animateWinCounter(to: total) }
        } else {
            displayedWin = 0
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

// MARK: - Symbol artwork (SF Symbols + text glyphs only)

struct BookSymbolView: View {
    let symbol: BookSymbol

    var body: some View {
        switch symbol {
        case .book:
            Image(systemName: "book.fill")
                .font(.system(size: 30))
                .foregroundStyle(.orange)
        case .muse:
            Image(systemName: "sparkles")
                .font(.system(size: 30))
                .foregroundStyle(.yellow)
        case .crown:
            Image(systemName: "crown.fill")
                .font(.system(size: 28))
                .foregroundStyle(Color(red: 1.0, green: 0.78, blue: 0.25))
        case .gem:
            Image(systemName: "suit.diamond.fill")
                .font(.system(size: 28))
                .foregroundStyle(.teal)
        case .scarab:
            Image(systemName: "ladybug.fill")
                .font(.system(size: 28))
                .foregroundStyle(Color(red: 0.85, green: 0.30, blue: 0.30))
        case .ace:
            letterGlyph("A", color: .white)
        case .king:
            letterGlyph("K", color: .white)
        case .queen:
            letterGlyph("Q", color: .white)
        case .jack:
            letterGlyph("J", color: .white)
        }
    }

    private func letterGlyph(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 30, weight: .black, design: .serif))
            .foregroundStyle(color)
    }
}

// MARK: - Screen

struct BookOfMuseView: View {
    @EnvironmentObject private var wallet: WalletStore
    @StateObject private var vm = BookOfMuseViewModel()

    var body: some View {
        ZStack {
            CasinoBackground()
            ScrollView {
                VStack(spacing: 16) {
                    headerRow
                    if let special = vm.specialSymbol {
                        freeSpinBanner(special: special)
                    }
                    gridView
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
                Text("Book of Muse")
                    .font(.system(.title2, design: .rounded).weight(.black))
                    .foregroundStyle(.white)
                Text("Das Buch ist Wild & Scatter")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
            }
            Spacer()
            BalancePill()
        }
    }

    private func freeSpinBanner(special: BookSymbol) -> some View {
        HStack(spacing: 10) {
            BookSymbolView(symbol: special)
                .frame(width: 34, height: 34)
            VStack(alignment: .leading, spacing: 2) {
                Text("FREISPIELE: noch \(vm.freeSpinsRemaining)")
                    .font(.system(.subheadline, design: .rounded).weight(.black))
                    .foregroundStyle(.white)
                Text("Spezialsymbol \(special.displayName) expandiert · bisher gewonnen: \(vm.freeSpinsTotalWin.grouped)")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.8))
            }
            Spacer()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.orange.opacity(0.35))
        )
        .glassPanel(cornerRadius: 16)
    }

    private var gridView: some View {
        HStack(spacing: 6) {
            ForEach(0..<5, id: \.self) { reel in
                VStack(spacing: 6) {
                    ForEach(0..<3, id: \.self) { row in
                        tile(reel: reel, row: row)
                    }
                }
            }
        }
        .padding(10)
        .glassPanel()
    }

    private func tile(reel: Int, row: Int) -> some View {
        let isHighlighted = vm.highlight.contains("\(reel)-\(row)")
        let isExpanded = vm.expandedReels.contains(reel)
        return ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(isExpanded ? 0.22 : 0.10))
            BookSymbolView(symbol: vm.displayGrid[reel][row])
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(
                    isHighlighted ? Color.yellow : Color.white.opacity(0.18),
                    lineWidth: isHighlighted ? 2.5 : 1
                )
        }
        .frame(maxWidth: .infinity)
        .frame(height: 64)
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
                ForEach([BookSymbol.muse, .crown, .gem, .scarab, .ace, .king, .queen, .jack], id: \.self) { symbol in
                    paytableRow(symbol: symbol)
                }
                Divider().overlay(Color.white.opacity(0.3))
                Text("Buch (Wild & Scatter): ersetzt alle Symbole. 3+ Bücher zahlen "
                    + "5× / 25× / 100× des Gesamteinsatzes und starten 10 Freispiele mit einem zufälligen "
                    + "Expandier-Symbol. Erscheint es in den Freispielen auf 3+ Walzen, füllt es die Walzen "
                    + "und zahlt wie ein Liniengewinn.")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.75))
                Text("Auszahlungen pro Linien-Einsatz. Nur Spielgeld – kein Echtgeld.")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white.opacity(0.85))
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

    private func paytableRow(symbol: BookSymbol) -> some View {
        let table = BookSymbol.paytable[symbol] ?? [:]
        return HStack(spacing: 10) {
            BookSymbolView(symbol: symbol)
                .frame(width: 30, height: 30)
                .scaleEffect(0.75)
            Text(symbol.displayName)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
            Spacer()
            Text("3× \(table[3] ?? 0) · 4× \(table[4] ?? 0) · 5× \(table[5] ?? 0)")
                .font(.subheadline)
                .monospacedDigit()
                .foregroundStyle(.white.opacity(0.85))
        }
    }
}

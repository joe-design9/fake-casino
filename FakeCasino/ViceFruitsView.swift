import SwiftUI

// MARK: - View model

@MainActor
final class ViceFruitsViewModel: ObservableObject {
    let betOptions = [1, 2, 5, 10, 25, 50]
    @Published var betIndex = 2

    var betPerLine: Int { betOptions[betIndex] }
    var totalBet: Int { betPerLine * SlotMath.fiveReelLines.count }

    @Published var displayGrid: [[FruitSymbol]] = ViceFruitsEngine.randomGrid()
    @Published var isSpinning = false
    @Published var displayedWin = 0
    @Published var highlight: Set<String> = []
    @Published var message = "Früchte fallen nicht vom Baum – dreh!"

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

        let result = ViceFruitsEngine.spin(betPerLine: betPerLine)
        Task { await animate(to: result, wallet: wallet) }
    }

    private func animate(to result: FruitSpinResult, wallet: WalletStore) async {
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
                    grid[reel] = (0..<3).map { _ in FruitSymbol.random(using: &rng) }
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
            message = "Kein Gewinn – die nächste Sieben wartet."
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

// MARK: - Symbol artwork (hand-drawn shapes + SF Symbols, no emojis)

struct FruitSymbolView: View {
    let symbol: FruitSymbol

    var body: some View {
        switch symbol {
        case .cherry:
            CherryShape()
        case .lemon:
            LemonShape()
        case .grape:
            GrapeShape()
        case .plum:
            PlumShape()
        case .bell:
            Image(systemName: "bell.fill")
                .font(.system(size: 30))
                .foregroundStyle(Color(red: 1.0, green: 0.78, blue: 0.25))
        case .diamond:
            Image(systemName: "suit.diamond.fill")
                .font(.system(size: 28))
                .foregroundStyle(.cyan)
        case .seven:
            Text("7")
                .font(.system(size: 38, weight: .black, design: .rounded))
                .foregroundStyle(.red)
        }
    }
}

private struct CherryShape: View {
    var body: some View {
        ZStack {
            Capsule()
                .fill(Color.green)
                .frame(width: 3, height: 22)
                .rotationEffect(.degrees(20))
                .offset(x: 5, y: -9)
            Image(systemName: "leaf.fill")
                .font(.system(size: 12))
                .foregroundStyle(.green)
                .offset(x: 11, y: -17)
            Circle()
                .fill(Color.red.gradient)
                .frame(width: 20, height: 20)
                .offset(x: -7, y: 9)
            Circle()
                .fill(Color.red.gradient)
                .frame(width: 17, height: 17)
                .offset(x: 9, y: 13)
        }
        .frame(width: 44, height: 44)
    }
}

private struct LemonShape: View {
    var body: some View {
        ZStack {
            Circle().fill(Color.yellow.gradient).frame(width: 9, height: 9).offset(x: -19, y: 0)
            Circle().fill(Color.yellow.gradient).frame(width: 9, height: 9).offset(x: 19, y: 0)
            Ellipse().fill(Color.yellow.gradient).frame(width: 38, height: 25)
            Ellipse().fill(Color.white.opacity(0.25)).frame(width: 20, height: 8).offset(y: -5)
        }
        .frame(width: 44, height: 44)
    }
}

private struct GrapeShape: View {
    var body: some View {
        VStack(spacing: 1) {
            Image(systemName: "leaf.fill")
                .font(.system(size: 10))
                .foregroundStyle(.green)
            dotRow(3)
            dotRow(2)
            dotRow(1)
        }
        .frame(width: 44, height: 44)
    }

    private func dotRow(_ count: Int) -> some View {
        HStack(spacing: 1) {
            ForEach(0..<count, id: \.self) { _ in
                Circle()
                    .fill(Color.purple.gradient)
                    .frame(width: 10, height: 10)
            }
        }
    }
}

private struct PlumShape: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(Color(red: 0.45, green: 0.25, blue: 0.75).gradient)
                .frame(width: 32, height: 32)
                .offset(y: 3)
            Image(systemName: "leaf.fill")
                .font(.system(size: 12))
                .foregroundStyle(.green)
                .offset(x: 5, y: -15)
        }
        .frame(width: 44, height: 44)
    }
}

// MARK: - Screen

struct ViceFruitsView: View {
    @EnvironmentObject private var wallet: WalletStore
    @StateObject private var vm = ViceFruitsViewModel()

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
                Text("Vice Fruits")
                    .font(.system(.title2, design: .rounded).weight(.black))
                    .foregroundStyle(.white)
                Text("Der fruchtige Klassiker")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
            }
            Spacer()
            BalancePill()
        }
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
        return ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.10))
            FruitSymbolView(symbol: vm.displayGrid[reel][row])
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
                ForEach([FruitSymbol.seven, .diamond, .bell, .grape, .plum, .lemon, .cherry], id: \.self) { symbol in
                    paytableRow(symbol: symbol)
                }
                Text("Kirschen zahlen schon ab 2 gleichen Symbolen auf einer Linie. "
                    + "Auszahlungen pro Linien-Einsatz. Nur Spielgeld – kein Echtgeld.")
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

    private func paytableRow(symbol: FruitSymbol) -> some View {
        let table = FruitSymbol.paytable[symbol] ?? [:]
        return HStack(spacing: 10) {
            FruitSymbolView(symbol: symbol)
                .frame(width: 30, height: 30)
                .scaleEffect(0.7)
            Text(symbol.displayName)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
            Spacer()
            Text(paytableText(table))
                .font(.subheadline)
                .monospacedDigit()
                .foregroundStyle(.white.opacity(0.85))
        }
    }

    private func paytableText(_ table: [Int: Int]) -> String {
        var parts: [String] = []
        if let two = table[2] { parts.append("2× \(two)") }
        parts.append("3× \(table[3] ?? 0)")
        parts.append("4× \(table[4] ?? 0)")
        parts.append("5× \(table[5] ?? 0)")
        return parts.joined(separator: " · ")
    }
}

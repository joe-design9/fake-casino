import SwiftUI

// MARK: - Symbol rendering

/// Draws the Book of Muse symbols (book via shapes, letters via serif glyphs).
struct BookSymbolView: View {
    let symbol: BookSymbol
    var size: CGFloat = 34

    var body: some View {
        switch symbol {
        case .book:
            BookGlyphView(size: size)
        case .muse:
            Image(systemName: "sparkles")
                .font(.system(size: size * 0.95, weight: .semibold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color(red: 0.78, green: 0.55, blue: 1.0), Color(red: 0.48, green: 0.22, blue: 0.95)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        case .crown:
            Image(systemName: "crown.fill")
                .font(.system(size: size * 0.9, weight: .semibold))
                .foregroundStyle(Color(red: 0.98, green: 0.80, blue: 0.30))
        case .gem:
            DrawnShapeView(kind: .gem, tint: Color(red: 1.0, green: 0.55, blue: 0.75), size: size)
        case .scarab:
            Image(systemName: "ladybug.fill")
                .font(.system(size: size * 0.9, weight: .semibold))
                .foregroundStyle(Color(red: 0.35, green: 0.85, blue: 0.75))
        case .ace, .king, .queen, .jack:
            Text(letter)
                .font(.system(size: size * 1.05, weight: .black, design: .serif))
                .foregroundStyle(letterColor)
        }
    }

    private var letter: String {
        switch symbol {
        case .ace: return "A"
        case .king: return "K"
        case .queen: return "Q"
        case .jack: return "J"
        default: return ""
        }
    }

    private var letterColor: Color {
        switch symbol {
        case .ace: return Color(red: 0.98, green: 0.82, blue: 0.35)
        case .king: return Color(red: 0.98, green: 0.75, blue: 0.45)
        case .queen: return Color(red: 0.88, green: 0.80, blue: 0.95)
        default: return Color(red: 0.80, green: 0.88, blue: 0.98)
        }
    }
}

/// An open book drawn from shapes: two pages, a spine and a star emblem.
struct BookGlyphView: View {
    var size: CGFloat = 34

    var body: some View {
        ZStack {
            HStack(spacing: 0) {
                PageShape(flip: false)
                    .fill(
                        LinearGradient(
                            colors: [Color(red: 0.85, green: 0.62, blue: 0.95), Color(red: 0.55, green: 0.30, blue: 0.85)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                PageShape(flip: true)
                    .fill(
                        LinearGradient(
                            colors: [Color(red: 0.80, green: 0.55, blue: 0.92), Color(red: 0.50, green: 0.25, blue: 0.80)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }
            .frame(width: size, height: size * 0.78)
            Rectangle()
                .fill(Color(red: 0.30, green: 0.12, blue: 0.55))
                .frame(width: max(2, size * 0.07), height: size * 0.78)
            Image(systemName: "star.fill")
                .font(.system(size: size * 0.30, weight: .bold))
                .foregroundStyle(Color(red: 1.0, green: 0.85, blue: 0.35))
        }
    }
}

private struct PageShape: Shape {
    let flip: Bool

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let inset = rect.height * 0.10
        if !flip {
            path.move(to: CGPoint(x: rect.maxX, y: rect.minY + inset))
            path.addQuadCurve(
                to: CGPoint(x: rect.minX, y: rect.minY),
                control: CGPoint(x: rect.midX, y: rect.minY + inset * 1.6)
            )
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.addQuadCurve(
                to: CGPoint(x: rect.maxX, y: rect.maxY - inset),
                control: CGPoint(x: rect.midX, y: rect.maxY - inset * 1.6)
            )
        } else {
            path.move(to: CGPoint(x: rect.minX, y: rect.minY + inset))
            path.addQuadCurve(
                to: CGPoint(x: rect.maxX, y: rect.minY),
                control: CGPoint(x: rect.midX, y: rect.minY + inset * 1.6)
            )
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.addQuadCurve(
                to: CGPoint(x: rect.minX, y: rect.maxY - inset),
                control: CGPoint(x: rect.midX, y: rect.maxY - inset * 1.6)
            )
        }
        path.closeSubpath()
        return path
    }
}

// MARK: - View model

@MainActor
final class BookOfMuseViewModel: ObservableObject {
    let lineCount = 10
    let betOptions = [1, 2, 5, 10, 25, 50]
    @Published var betIndex = 2

    var betPerLine: Int { betOptions[betIndex] }
    var totalBet: Int { betPerLine * lineCount }
    var betLocked: Bool { isSpinning || specialSymbol != nil }

    @Published var targetGrid: [[BookSymbol]]
    @Published var expandedColumns: [[BookSymbol]]?
    @Published var spinID = 0
    @Published var reelDurations: [Double] = []
    @Published var anticipationReels: Set<Int> = []
    @Published var isSpinning = false
    @Published var highlight: Set<GridPosition> = []
    @Published var displayedWin = 0
    @Published var message = "Das Buch wartet auf dich …"
    @Published var freeSpinsRemaining = 0
    @Published var freeSpinsTotalWin = 0
    @Published var specialSymbol: BookSymbol?
    @Published var celebrationTier: WinTier?
    @Published var celebrationAmount = 0

    private var pendingResult: BookSpinResult?
    private var celebrationToken = 0
    private var rng = SystemRandomNumberGenerator()

    init() {
        targetGrid = BookOfMuseEngine.randomGrid()
    }

    func increaseBet() {
        if betIndex < betOptions.count - 1 { betIndex += 1 }
    }

    func decreaseBet() {
        if betIndex > 0 { betIndex -= 1 }
    }

    func fillerSymbol() -> BookSymbol {
        BookSymbol.random(using: &rng)
    }

    func spin(wallet: WalletStore) {
        guard !isSpinning else { return }
        let isFreeSpin = specialSymbol != nil
        if isFreeSpin {
            freeSpinsRemaining -= 1
        } else {
            guard wallet.placeBet(totalBet) else {
                message = "Nicht genug Coins – hol dir den Gratis-Refill!"
                return
            }
        }
        wallet.recordSpin()
        let result = BookOfMuseEngine.spin(betPerLine: betPerLine, totalBet: totalBet)
        pendingResult = result
        targetGrid = result.grid
        expandedColumns = nil
        highlight = []
        displayedWin = 0
        celebrationTier = nil
        isSpinning = true
        message = isFreeSpin ? "Freispiel läuft …" : "Die Walzen drehen …"

        var durations = (0..<5).map { 0.95 + Double($0) * 0.30 }
        anticipationReels = []
        let earlyBooks = (0..<2).reduce(0) { partial, reel in
            partial + result.grid[reel].filter { $0 == .book }.count
        }
        if earlyBooks == 2 {
            anticipationReels = Set(2..<5)
            for reel in 2..<5 {
                durations[reel] += 0.85
            }
        }
        reelDurations = durations
        spinID += 1
    }

    func finishSpin(wallet: WalletStore) {
        guard let result = pendingResult else {
            isSpinning = false
            return
        }
        pendingResult = nil
        let wasInFreeSpins = specialSymbol != nil

        var win = result.lineWinTotal + result.scatterWin
        var highlights = Set<GridPosition>()
        for lineWin in result.lineWins {
            for position in lineWin.positions {
                highlights.insert(position)
            }
        }
        if result.scatterWin > 0 {
            for reel in 0..<5 {
                for row in 0..<3 where result.grid[reel][row] == .book {
                    highlights.insert(GridPosition(reel: reel, row: row))
                }
            }
        }

        // Expanding symbol during free spins.
        var expandingAmount = 0
        if let special = specialSymbol {
            let expanding = BookOfMuseEngine.expandingWin(
                grid: result.grid, special: special, betPerLine: betPerLine
            )
            if expanding.amount > 0 {
                expandingAmount = expanding.amount
                win += expanding.amount
                var expanded: [[BookSymbol]] = []
                for reel in 0..<5 {
                    if expanding.reels.contains(reel) {
                        expanded.append([special, special, special])
                        for row in 0..<3 {
                            highlights.insert(GridPosition(reel: reel, row: row))
                        }
                    } else {
                        expanded.append(result.grid[reel])
                    }
                }
                expandedColumns = expanded
            }
        }

        if win > 0 {
            wallet.addWin(win)
            if wasInFreeSpins {
                freeSpinsTotalWin += win
            }
        }

        let triggered = result.scatterCount >= 3
        if triggered {
            freeSpinsRemaining += BookOfMuseEngine.freeSpinsAwarded
            if specialSymbol == nil {
                specialSymbol = BookSymbol.freeSpinCandidates.randomElement()
                freeSpinsTotalWin = 0
            }
        }
        if wasInFreeSpins, !triggered, freeSpinsRemaining == 0 {
            specialSymbol = nil
        }

        highlight = highlights
        displayedWin = win
        isSpinning = false

        if triggered {
            if wasInFreeSpins {
                message = "Retrigger! +\(BookOfMuseEngine.freeSpinsAwarded) Freispiele!"
            } else if let special = specialSymbol {
                message = "\(BookOfMuseEngine.freeSpinsAwarded) Freispiele! Spezial-Symbol: \(special.displayName)"
            } else {
                message = "\(BookOfMuseEngine.freeSpinsAwarded) Freispiele gewonnen!"
            }
        } else if wasInFreeSpins, freeSpinsRemaining == 0, specialSymbol == nil {
            message = "Freispiele vorbei – Gesamtgewinn: \(freeSpinsTotalWin.grouped) Coins"
            freeSpinsTotalWin = 0
        } else if win > 0 {
            if expandingAmount > 0 {
                message = "Expanding Symbol! Gewinn: \(win.grouped) Coins!"
            } else {
                message = "Gewinn: \(win.grouped) Coins!"
            }
        } else {
            message = wasInFreeSpins ? "Freispiel ohne Gewinn." : "Kein Gewinn – das Buch schweigt …"
        }

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

struct BookOfMuseView: View {
    @EnvironmentObject private var wallet: WalletStore
    @StateObject private var vm = BookOfMuseViewModel()
    @State private var reelWidth: CGFloat = 360
    @State private var showInfo = false

    private let palette = MachinePalette(
        ["#241047", "#4C1D95", "#6D28D9"], accent: "#C084FC"
    )

    private var cellHeight: CGFloat {
        let available = reelWidth - 20 - 4 * 6
        return min(available / 5 * 1.02, 96)
    }

    var body: some View {
        ZStack {
            CasinoBackground()
            ScrollView {
                VStack(spacing: 14) {
                    if let special = vm.specialSymbol {
                        specialBanner(special)
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
                            : (vm.specialSymbol != nil ? "FREISPIEL DREHEN (\(vm.freeSpinsRemaining))" : "DREHEN"),
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
        .navigationTitle("Book of Muse")
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
            BookPaytableSheet()
        }
    }

    private func specialBanner(_ special: BookSymbol) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "sparkles")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Color(red: 0.85, green: 0.70, blue: 1.0))
            VStack(alignment: .leading, spacing: 2) {
                Text("FREISPIELE: noch \(vm.freeSpinsRemaining) · Spezial-Symbol: \(special.displayName)")
                    .font(.system(.subheadline, design: .default).weight(.bold))
                    .foregroundStyle(.white)
                Text("Bisher gewonnen: \(vm.freeSpinsTotalWin.grouped) Coins")
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
            PaletteArtwork(palette: palette, glowOpacity: 0.35)
            StripReelView(
                columns: vm.targetGrid,
                rows: 3,
                spinID: vm.spinID,
                reelDurations: vm.reelDurations,
                anticipationReels: vm.anticipationReels,
                highlighted: vm.highlight,
                overrideColumns: vm.expandedColumns,
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

    private func cellView(symbol: BookSymbol, isHighlighted: Bool) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.13), Color.black.opacity(0.18)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            BookSymbolView(symbol: symbol, size: cellHeight * 0.52)
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

private struct BookPaytableSheet: View {
    @Environment(\.dismiss) private var dismiss

    private let rows: [(BookSymbol, String)] = [
        (.book, "20 · 200 · 1.000 · Wild + Scatter"),
        (.muse, "10 · 50 · 250"),
        (.crown, "8 · 30 · 150"),
        (.gem, "5 · 20 · 100"),
        (.scarab, "5 · 15 · 75"),
        (.ace, "4 · 10 · 50"),
        (.king, "4 · 10 · 50"),
        (.queen, "3 · 8 · 40"),
        (.jack, "3 · 8 · 40"),
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                CasinoBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(rows, id: \.0) { row in
                            HStack(spacing: 12) {
                                BookSymbolView(symbol: row.0, size: 26)
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
                        Text("Auszahlungen für 3 / 4 / 5 Gleiche auf einer Linie, als Vielfaches des Linien-Einsatzes. 10 Linien, von links nach rechts, Buch zählt als Wild und Scatter.\n\nScatter: 3+ Bücher zahlen überall das 5× / 25× / 100× des Gesamteinsatzes und starten 10 Freispiele mit einem zufälligen Expanding-Spezial-Symbol. In den Freispielen füllt das Spezial-Symbol alle Walzen, auf denen es erscheint – ab 3 Walzen zahlt es wie ein Liniengewinn. Retrigger möglich: weitere 3+ Bücher geben +10 Freispiele.")
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

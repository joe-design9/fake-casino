import Combine
import Foundation

enum CabinetOverlay: Equatable {
    case none
    case choose
    case ladder
    case cards
    case celebration(mega: Bool)
    case paytable
    case stake
    case autoMenu
    case refill
}

@MainActor
final class SlotSession: ObservableObject {
    let game: GameKind
    private let wallet: WalletStore
    private let scripted: Bool

    @Published var grid: [[String]]
    @Published var spinning = false
    @Published var spinID = 0
    @Published var quickStopToken = 0
    @Published var turbo = false
    @Published var betIndex = 3
    @Published var phase: Phase = .idle
    @Published var lineWins: [LineWin] = []
    @Published var highlighted: Set<GridPosition> = []
    @Published var pendingWin = 0
    @Published var shownWin = 0
    @Published var statusText = "Viel Glück"
    @Published var overlay: CabinetOverlay = .none
    @Published var autoplayLeft: Int?
    @Published var anticipateFrom: Int?
    @Published var forcedReels: [Int: String] = [:]
    @Published var freeSpinNumber = 0
    @Published var freeSpinTotal = 0
    @Published var specialSymbol: String?
    @Published var ladderLevel = 0
    @Published var ladderBase = 0
    @Published var cardHistory: [PlayingCard] = []
    @Published var revealedCard: PlayingCard?
    @Published var gambleBusy = false
    @Published var toast: String?

    enum Phase {
        case idle
        case spinning
        case presenting
    }

    private var spinTask: Task<Void, Never>?
    private var stopWaiter: CheckedContinuation<Void, Never>?
    private var stoppedReels = 0
    private var featureTriggered = false
    private var stopAutoplay = false
    private var shoe = CardShoe()
    private var rng = SystemRandomNumberGenerator()

    var totalBet: Int { WalletStore.betSteps[betIndex] }
    var lineBet: Int { totalBet / game.lineCount }
    var canSpin: Bool { spinTask == nil && !gambleBusy }
    var risikoEnabled: Bool { phase == .presenting && pendingWin > 0 && spinTask == nil }

    init(game: GameKind, shot: Screenshot?, wallet: WalletStore) {
        self.game = game
        self.wallet = wallet
        self.scripted = shot != nil
        self.grid = (0..<game.reelCount).map { _ in ["cherry", "lemon", "plum"] }
        if LaunchFlags.uiTest { turbo = true }
        if let shot {
            apply(shot)
        }
    }

    func shutdown() {
        SoundEngine.shared.stopReelLoop()
        spinTask?.cancel()
        if let waiter = stopWaiter {
            stopWaiter = nil
            waiter.resume()
        }
        if phase == .presenting || overlay == .ladder || overlay == .cards || overlay == .choose {
            collect(keepOverlay: false)
        }
    }

    func selectBet(_ amount: Int) {
        guard canSpin else { return }
        if let index = WalletStore.betSteps.firstIndex(of: amount) {
            betIndex = index
        }
        overlay = .none
    }

    func shiftBet(_ delta: Int) {
        guard canSpin, overlay == .none || overlay == .paytable else { return }
        let next = min(WalletStore.betSteps.count - 1, max(0, betIndex + delta))
        guard next != betIndex else { return }
        betIndex = next
    }

    func toggleTurbo() {
        turbo.toggle()
    }

    func primaryButton() {
        if phase == .spinning {
            quickStopToken += 1
            return
        }
        spinTapped()
    }

    func spinTapped() {
        guard canSpin else { return }
        if phase == .presenting {
            collect(keepOverlay: false)
        }
        spinTask = Task {
            await playPaidSpin()
            spinTask = nil
        }
    }

    func startAutoplay(_ count: Int) {
        guard canSpin, count > 0 else { return }
        if phase == .presenting { collect(keepOverlay: false) }
        overlay = .none
        autoplayLeft = count
        stopAutoplay = false
        spinTask = Task {
            var remaining = count
            while remaining > 0 && !stopAutoplay {
                autoplayLeft = remaining
                await playPaidSpin()
                if stopAutoplay || Task.isCancelled { break }
                if wallet.balance < totalBet {
                    if wallet.canRefill { overlay = .refill }
                    else { statusText = "Guthaben reicht nicht" }
                    break
                }
                remaining -= 1
            }
            autoplayLeft = nil
            stopAutoplay = false
            spinTask = nil
        }
    }

    func stopAutoplayNow() {
        stopAutoplay = true
        autoplayLeft = nil
        statusText = "Autoplay gestoppt"
    }

    func openChooser() {
        guard risikoEnabled else { return }
        overlay = .choose
    }

    func openLadder() {
        guard pendingWin > 0 else { return }
        ladderBase = pendingWin
        ladderLevel = 0
        overlay = .ladder
        phase = .presenting
    }

    func openCards() {
        guard pendingWin > 0 else { return }
        revealedCard = nil
        overlay = .cards
        phase = .presenting
    }

    func takeWin() {
        collect(keepOverlay: false)
        statusText = "Gewinn eingesammelt"
    }

    func climbLadder() {
        guard overlay == .ladder, !gambleBusy, ladderLevel < LadderMath.maxLevel else { return }
        gambleBusy = true
        SoundEngine.shared.risk()
        Haptics.risk()
        Task {
            try? await Task.sleep(nanoseconds: 650_000_000)
            let success = Int.random(in: 0...1, using: &rng) == 1
            if success {
                ladderLevel += 1
                pendingWin = LadderMath.amount(base: ladderBase, level: ladderLevel)
                shownWin = pendingWin
                statusText = "Stufe \(ladderLevel) — \(KT.string(pendingWin)) KT"
                SoundEngine.shared.riskWin()
                Haptics.win()
            } else {
                pendingWin = 0
                shownWin = 0
                statusText = "Risiko verloren"
                SoundEngine.shared.riskLose()
                Haptics.lose()
                try? await Task.sleep(nanoseconds: 550_000_000)
                overlay = .none
                collect(keepOverlay: false)
            }
            gambleBusy = false
        }
    }

    func guessCard(red: Bool) {
        guard overlay == .cards, !gambleBusy, pendingWin > 0 else { return }
        gambleBusy = true
        let card = shoe.draw(&rng)
        revealedCard = card
        cardHistory.append(card)
        if cardHistory.count > 6 { cardHistory.removeFirst(cardHistory.count - 6) }
        let correct = card.isRed == red
        Task {
            try? await Task.sleep(nanoseconds: 700_000_000)
            if correct {
                let doubled = pendingWin.multipliedReportingOverflow(by: 2)
                pendingWin = doubled.overflow ? pendingWin : doubled.partialValue
                shownWin = pendingWin
                statusText = "Richtig — \(KT.string(pendingWin)) KT"
                SoundEngine.shared.riskWin()
                Haptics.win()
                try? await Task.sleep(nanoseconds: 350_000_000)
                revealedCard = nil
            } else {
                pendingWin = 0
                shownWin = 0
                statusText = "Falsche Farbe"
                SoundEngine.shared.riskLose()
                Haptics.lose()
                try? await Task.sleep(nanoseconds: 700_000_000)
                overlay = .none
                collect(keepOverlay: false)
            }
            gambleBusy = false
        }
    }

    func reelDidStop(_ reel: Int) {
        stoppedReels += 1
        if let start = anticipateFrom, reel + 1 >= start {
            SoundEngine.shared.tense()
        } else {
            SoundEngine.shared.stop()
        }
        Haptics.reel()
        if stoppedReels >= grid.count, let waiter = stopWaiter {
            stopWaiter = nil
            waiter.resume()
        }
    }

    func collectFromCelebration() {
        collect(keepOverlay: false)
    }

    func refill() {
        wallet.refill()
        overlay = .none
        toast = "+\(KT.string(WalletStore.refillAmount)) KT Spielgeld"
        SoundEngine.shared.bonus()
    }

    private func playPaidSpin() async {
        guard wallet.beginRound(game: game, bet: totalBet) else {
            overlay = wallet.canRefill ? .refill : .none
            statusText = wallet.canRefill ? "Spielgeld aufgebraucht" : "Einsatz zu hoch"
            stopAutoplay = true
            return
        }
        featureTriggered = false
        phase = .spinning
        lineWins = []
        highlighted = []
        forcedReels = [:]
        freeSpinNumber = 0
        freeSpinTotal = 0
        specialSymbol = nil
        shownWin = 0
        pendingWin = 0
        statusText = "Die Walzen laufen"
        SoundEngine.shared.startReelLoop()

        let round = game.spin(totalBet: totalBet, rng: &rng)
        await animate(to: round.grid, anticipate: game.anticipationReel(in: round.grid), forced: [:])
        if Task.isCancelled { wallet.finishRound(game: game, win: 0); return }

        lineWins = round.lineWins
        highlighted = Set(round.lineWins.flatMap(\.positions))
        if round.scatterCount >= 3 {
            for reel in round.grid.indices where round.grid[reel].contains(scatterKey) {
                for row in 0..<3 where round.grid[reel][row] == scatterKey {
                    highlighted.insert(GridPosition(reel: reel, row: row))
                }
            }
        }
        pendingWin = round.lineWins.reduce(0) { $0 + $1.amount } + round.scatterWin
        shownWin = pendingWin
        statusText = baseStatus(round)

        if !round.freeSpins.isEmpty {
            featureTriggered = true
            specialSymbol = round.specialSymbol
            freeSpinTotal = SphinxEngine.freeSpinAward
            statusText = "10 Freispiele — \(SymbolName.of(round.specialSymbol ?? ""))"
            SoundEngine.shared.bigWin()
            try? await Task.sleep(nanoseconds: turbo ? 500_000_000 : 900_000_000)
            var index = 0
            for step in round.freeSpins {
                if Task.isCancelled { break }
                index += 1
                freeSpinNumber = index
                if step.retriggered { freeSpinTotal += SphinxEngine.freeSpinAward }
                var forced: [Int: String] = [:]
                if step.expandWin > 0 {
                    for reel in step.expandedReels { forced[reel] = step.expandSymbol }
                }
                await animate(to: step.grid, anticipate: game.anticipationReel(in: step.grid), forced: forced)
                forcedReels = forced
                lineWins = step.lineWins
                var marks = Set(step.lineWins.flatMap(\.positions))
                for reel in step.expandedReels where step.expandWin > 0 {
                    for row in 0..<3 { marks.insert(GridPosition(reel: reel, row: row)) }
                }
                highlighted = marks
                pendingWin += step.totalWin
                shownWin = pendingWin
                if step.expandWin > 0 {
                    statusText = "\(SymbolName.of(step.expandSymbol)) auf \(step.expandedReels.count) Walzen"
                } else if step.retriggered {
                    statusText = "Noch einmal 10 Freispiele"
                } else {
                    statusText = "Freispiel \(index)/\(freeSpinTotal)"
                }
                if step.totalWin > 0 { SoundEngine.shared.win() }
            }
        }

        let multiple = totalBet > 0 ? Double(pendingWin) / Double(totalBet) : 0
        if multiple >= 50 {
            overlay = .celebration(mega: true)
            SoundEngine.shared.mega()
            Haptics.mega()
        } else if multiple >= 15 {
            overlay = .celebration(mega: false)
            SoundEngine.shared.bigWin()
            Haptics.big()
        } else if pendingWin > 0 {
            SoundEngine.shared.win()
            Haptics.win()
        }

        if autoplayLeft != nil {
        let pause: UInt64 = LaunchFlags.uiTest ? 60_000_000 : (multiple >= 15 ? 1_500_000_000 : 650_000_000)
        try? await Task.sleep(nanoseconds: LaunchFlags.uiTest ? pause : (turbo ? pause / 2 : pause))
            if featureTriggered || multiple >= 15 { stopAutoplay = true }
            collect(keepOverlay: false)
        } else if pendingWin > 0 {
            phase = .presenting
        } else {
            collect(keepOverlay: false)
            statusText = "Kein Gewinn"
        }
    }

    private func animate(to next: [[String]], anticipate: Int?, forced: [Int: String]) async {
        grid = next
        anticipateFrom = anticipate
        forcedReels = [:]
        stoppedReels = 0
        spinning = true
        spinID += 1
        let needed = max(1, grid.count)
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            if stoppedReels >= needed {
                continuation.resume()
            } else {
                stopWaiter = continuation
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 12_000_000_000)
                    if let waiter = self.stopWaiter {
                        self.stopWaiter = nil
                        waiter.resume()
                    }
                }
            }
        }
        spinning = false
        SoundEngine.shared.stopReelLoop()
        if !forced.isEmpty {
            forcedReels = forced
        }
        anticipateFrom = nil
    }

    private func collect(keepOverlay: Bool) {
        let win = pendingWin
        pendingWin = 0
        wallet.finishRound(game: game, win: win)
        phase = .idle
        if !keepOverlay { overlay = .none }
        highlighted = []
        lineWins = []
        forcedReels = [:]
    }

    private var scatterKey: String {
        switch game {
        case .fruchtfeuer: return "seven"
        case .sphinx: return "book"
        case .joker: return "star"
        }
    }

    private func baseStatus(_ round: RoundResult) -> String {
        if game == .sphinx && round.scatterCount >= 3 {
            return "\(round.scatterCount)× Buch"
        }
        if game == .joker && round.scatterCount >= 3, let best = round.lineWins.max(by: { $0.amount < $1.amount }) {
            return "\(best.count)× \(SymbolName.of(best.symbolID)) und \(round.scatterCount)× Stern"
        }
        if game == .joker && round.scatterCount >= 3 {
            return "\(round.scatterCount)× Stern"
        }
        if let best = round.lineWins.max(by: { $0.amount < $1.amount }) {
            return "\(best.count)× \(SymbolName.of(best.symbolID)) · Linie \(best.lineIndex + 1)"
        }
        return "Kein Gewinn"
    }

    private func apply(_ shot: Screenshot) {
        betIndex = 3
        switch shot {
        case .lobby, .spin:
            break
        case .fruitWin:
            grid = [
                ["cherry", "bell", "lemon"],
                ["lemon", "bell", "orange"],
                ["plum", "bell", "cherry"]
            ]
            let evaluated = FruchtfeuerEngine.evaluate(grid: grid, totalBet: totalBet)
            lineWins = evaluated.lineWins
            highlighted = Set(evaluated.lineWins.flatMap(\.positions))
            pendingWin = evaluated.total
            shownWin = evaluated.total
            phase = .presenting
            statusText = "3× Glocke · Linie 1"
        case .bookFreespins:
            grid = [
                ["eye", "eye", "eye"],
                ["book", "queen", "ace"],
                ["eye", "eye", "eye"],
                ["jack", "ankh", "king"],
                ["eye", "eye", "eye"]
            ]
            forcedReels = [0: "eye", 2: "eye", 4: "eye"]
            specialSymbol = "eye"
            freeSpinNumber = 4
            freeSpinTotal = 10
            pendingWin = 1_100
            shownWin = 1_100
            phase = .presenting
            highlighted = Set((0..<3).flatMap { row in [0, 2, 4].map { GridPosition(reel: $0, row: row) } })
            statusText = "Auge expandiert · 3 Walzen"
        case .joker:
            grid = [
                ["star", "joker", "cherry"],
                ["grape", "seven", "star"],
                ["melon", "seven", "bell"],
                ["star", "bell", "grape"],
                ["cherry", "grape", "melon"]
            ]
            let evaluated = JokerEngine.evaluate(grid: grid, totalBet: totalBet)
            lineWins = evaluated.lineWins
            highlighted = Set(evaluated.lineWins.flatMap(\.positions))
            for reel in grid.indices {
                for row in 0..<3 where grid[reel][row] == "star" {
                    highlighted.insert(GridPosition(reel: reel, row: row))
                }
            }
            pendingWin = evaluated.total
            shownWin = evaluated.total
            phase = .presenting
            statusText = "3× Sieben und 3× Stern"
        case .risikoleiter:
            apply(.fruitWin)
            ladderBase = pendingWin == 0 ? 700 : pendingWin
            ladderLevel = 0
            overlay = .ladder
        case .kartenrisiko:
            apply(.fruitWin)
            cardHistory = [
                PlayingCard(rank: 13, suit: 0),
                PlayingCard(rank: 7, suit: 2),
                PlayingCard(rank: 1, suit: 1),
                PlayingCard(rank: 3, suit: 3),
                PlayingCard(rank: 9, suit: 0),
                PlayingCard(rank: 12, suit: 2)
            ]
            revealedCard = nil
            overlay = .cards
        case .megawin:
            grid = [
                ["cherry", "seven", "lemon"],
                ["orange", "seven", "plum"],
                ["lemon", "seven", "bell"]
            ]
            lineWins = [LineWin(lineIndex: 0, rows: [1, 1, 1], count: 3, symbolID: "seven", amount: 5_000)]
            highlighted = Set((0..<3).map { GridPosition(reel: $0, row: 1) })
            pendingWin = 5_000
            shownWin = 5_000
            phase = .presenting
            statusText = "5× Sieben · Linie 1"
            overlay = .celebration(mega: true)
        }
    }
}

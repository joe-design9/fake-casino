import Foundation

struct GridPosition: Hashable {
    var reel: Int
    var row: Int
}

struct LineWin: Equatable {
    var lineIndex: Int
    var rows: [Int]
    var count: Int
    var symbolID: String
    var amount: Int

    var positions: [GridPosition] {
        (0..<count).map { GridPosition(reel: $0, row: rows[$0]) }
    }
}

struct FreeSpinStep {
    var grid: [[String]]
    var lineWins: [LineWin]
    var scatterCount: Int
    var scatterWin: Int
    var expandedReels: [Int]
    var expandSymbol: String
    var expandWin: Int
    var retriggered: Bool
    var totalWin: Int
}

struct RoundResult {
    var grid: [[String]]
    var lineWins: [LineWin]
    var scatterCount: Int
    var scatterWin: Int
    var freeSpins: [FreeSpinStep]
    var specialSymbol: String?
    var totalWin: Int
}

struct PayRow: Identifiable {
    var id: String { symbol }
    var symbol: String
    var detail: String
}

enum SymbolName {
    static func of(_ id: String) -> String {
        switch id {
        case "cherry": return "Kirsche"
        case "lemon": return "Zitrone"
        case "plum": return "Pflaume"
        case "grape": return "Traube"
        case "melon": return "Melone"
        case "bell": return "Glocke"
        case "bar": return "BAR"
        case "seven": return "Sieben"
        case "book": return "Buch"
        case "pharaoh": return "Pharao"
        case "ankh": return "Ankh"
        case "scarab": return "Skarabäus"
        case "eye": return "Auge"
        case "ace": return "Ass"
        case "king": return "König"
        case "queen": return "Dame"
        case "jack": return "Bube"
        case "ten": return "Zehn"
        case "joker": return "Joker"
        case "star": return "Stern"
        default: return id
        }
    }
}

/// SplitMix64. Used by the RTP test and by screenshot-stable shuffles — never by live spins.
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed == 0 ? 0xA5A5_5A5A_C3C3_3C3C : seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}

enum RNGDraw {
    static func index<R: RandomNumberGenerator>(_ rng: inout R, upper: Int) -> Int {
        precondition(upper > 0)
        return Int(rng.next() % UInt64(upper))
    }

    static func pick<R: RandomNumberGenerator>(_ rng: inout R, weights: [(String, Int)]) -> String {
        let total = weights.reduce(0) { $0 + $1.1 }
        var roll = index(&rng, upper: total)
        for (symbol, weight) in weights {
            if roll < weight { return symbol }
            roll -= weight
        }
        return weights[weights.count - 1].0
    }

    static func grid<R: RandomNumberGenerator>(_ rng: inout R, weights: [(String, Int)]) -> [[String]] {
        (0..<5).map { _ in (0..<3).map { _ in pick(&rng, weights: weights) } }
    }
}

enum Paylines {
    static let ten: [[Int]] = [
        [1, 1, 1, 1, 1],
        [0, 0, 0, 0, 0],
        [2, 2, 2, 2, 2],
        [0, 1, 2, 1, 0],
        [2, 1, 0, 1, 2],
        [0, 0, 1, 0, 0],
        [2, 2, 1, 2, 2],
        [1, 0, 0, 0, 1],
        [1, 2, 2, 2, 1],
        [1, 0, 1, 0, 1]
    ]
    static var five: [[Int]] { Array(ten.prefix(5)) }
}

enum LineEvaluator {
    /// Left-to-right match of the first symbol. No wilds.
    static func plain(grid: [[String]], lines: [[Int]], pay: [String: [Int: Int]], lineBet: Int) -> [LineWin] {
        var wins: [LineWin] = []
        for (index, rows) in lines.enumerated() {
            let first = grid[0][rows[0]]
            var count = 0
            for reel in 0..<rows.count {
                if grid[reel][rows[reel]] == first {
                    count += 1
                } else {
                    break
                }
            }
            let multiplier = pay[first]?[count] ?? 0
            if multiplier > 0 {
                wins.append(LineWin(lineIndex: index, rows: rows, count: count, symbolID: first, amount: multiplier * lineBet))
            }
        }
        return wins
    }

    /// Best-paying left-to-right symbol. `wild` substitutes for every paying symbol except itself.
    static func wild(
        grid: [[String]],
        lines: [[Int]],
        pay: [String: [Int: Int]],
        order: [String],
        wild: String,
        lineBet: Int,
        skip: String? = nil
    ) -> [LineWin] {
        var wins: [LineWin] = []
        for (index, rows) in lines.enumerated() {
            let cells = rows.enumerated().map { grid[$0.offset][$0.element] }
            var best: (symbol: String, count: Int, multiplier: Int)?
            for symbol in order where symbol != skip {
                var count = 0
                if symbol == wild {
                    for cell in cells {
                        if cell == wild { count += 1 } else { break }
                    }
                } else {
                    for cell in cells {
                        if cell == symbol || cell == wild { count += 1 } else { break }
                    }
                }
                let multiplier = pay[symbol]?[count] ?? 0
                if multiplier > 0, best == nil || multiplier > best!.multiplier {
                    best = (symbol, count, multiplier)
                }
            }
            if let best {
                wins.append(LineWin(
                    lineIndex: index,
                    rows: rows,
                    count: best.count,
                    symbolID: best.symbol,
                    amount: best.multiplier * lineBet
                ))
            }
        }
        return wins
    }
}

enum LadderMath {
    static let maxLevel = 5

    static func amount(base: Int, level: Int) -> Int {
        guard base > 0, level > 0 else { return max(0, base) }
        var value = base
        for _ in 0..<min(level, maxLevel) {
            let next = value.multipliedReportingOverflow(by: 2)
            if next.overflow { return value }
            value = next.partialValue
        }
        return value
    }
}

struct PlayingCard: Identifiable, Equatable {
    let id: UUID
    let rank: Int
    let suit: Int

    init(rank: Int, suit: Int, id: UUID = UUID()) {
        self.id = id
        self.rank = rank
        self.suit = suit
    }

    var isRed: Bool { suit < 2 }

    var rankLabel: String {
        switch rank {
        case 1: return "A"
        case 11: return "J"
        case 12: return "Q"
        case 13: return "K"
        default: return "\(rank)"
        }
    }

    var suitSymbol: String { ["♥", "♦", "♣", "♠"][suit] }
}

struct CardShoe {
    private var cards: [PlayingCard] = []

    mutating func draw<R: RandomNumberGenerator>(_ rng: inout R) -> PlayingCard {
        if cards.isEmpty { refill(&rng) }
        return cards.removeLast()
    }

    private mutating func refill<R: RandomNumberGenerator>(_ rng: inout R) {
        var deck: [PlayingCard] = []
        for suit in 0..<4 {
            for rank in 1...13 {
                deck.append(PlayingCard(rank: rank, suit: suit))
            }
        }
        for index in stride(from: deck.count - 1, through: 1, by: -1) {
            let swap = RNGDraw.index(&rng, upper: index + 1)
            deck.swapAt(index, swap)
        }
        cards = deck
    }
}

enum GameKind: String, CaseIterable, Identifiable, Sendable {
    case fruchtfeuer
    case sphinx
    case joker

    var id: String { rawValue }

    var title: String {
        switch self {
        case .fruchtfeuer: return "Fruchtfeuer"
        case .sphinx: return "Buch der Sphinx"
        case .joker: return "Joker Sterne"
        }
    }

    var subtitle: String {
        switch self {
        case .fruchtfeuer: return "10 Linien · Kirsche ab 2"
        case .sphinx: return "Buch-Wild · 10 Freispiele"
        case .joker: return "5 Linien · Joker-Wild"
        }
    }

    var lineCount: Int { self == .joker ? 5 : 10 }

    var pool: [String] {
        switch self {
        case .fruchtfeuer: return FruchtfeuerEngine.order
        case .sphinx: return SphinxEngine.order
        case .joker: return JokerEngine.order
        }
    }

    var payRows: [PayRow] {
        switch self {
        case .fruchtfeuer: return FruchtfeuerEngine.payRows
        case .sphinx: return SphinxEngine.payRows
        case .joker: return JokerEngine.payRows
        }
    }

    var payNote: String {
        switch self {
        case .fruchtfeuer:
            return "Gewinne laufen von links und gelten je Linie. Die Kirsche zahlt schon ab zwei Symbolen. Zahlen sind Vielfache des Linieneinsatzes."
        case .sphinx:
            return "Das Buch ist Wild und Scatter. Drei oder mehr Bücher zahlen den Scatter (× Gesamteinsatz: 3 / 14 / 55 / 140) und starten 10 Freispiele mit einem zufälligen Expandier-Symbol. Im Freispiel zahlt das Symbol auf allen Linien, sobald es auf genug Walzen liegt, und kann neu ausgelöst werden."
        case .joker:
            return "Der Joker ersetzt jedes Symbol außer dem Stern. Sterne zahlen überall (× Gesamteinsatz: 3→2, 4→8, 5→20, 6→50, 7+→100). Übrige Zahlen sind Vielfache des Linieneinsatzes."
        }
    }

    func spin<R: RandomNumberGenerator>(totalBet: Int, rng: inout R) -> RoundResult {
        switch self {
        case .fruchtfeuer: return FruchtfeuerEngine.spin(totalBet: totalBet, rng: &rng)
        case .sphinx: return SphinxEngine.spin(totalBet: totalBet, rng: &rng)
        case .joker: return JokerEngine.spin(totalBet: totalBet, rng: &rng)
        }
    }

    /// Reel index from which stops should hesitate, once two teaser symbols are already placed.
    func anticipationReel(in grid: [[String]]) -> Int? {
        let key: String
        switch self {
        case .fruchtfeuer: key = "seven"
        case .sphinx: key = "book"
        case .joker: key = "star"
        }
        var seen = 0
        for reel in grid.indices {
            if grid[reel].contains(key) { seen += 1 }
            if seen >= 2, reel + 1 < grid.count { return reel + 1 }
        }
        return nil
    }
}

enum FruchtfeuerEngine {
    static let order = ["seven", "bar", "bell", "melon", "grape", "plum", "lemon", "cherry"]
    static let weights: [(String, Int)] = [
        ("seven", 3), ("bar", 4), ("bell", 6), ("melon", 8),
        ("grape", 9), ("plum", 11), ("lemon", 13), ("cherry", 12)
    ]
    /// Multiples of the line bet. Tuned for ~94.5% RTP and ~31% hits.
    static let pay: [String: [Int: Int]] = [
        "seven": [3: 280, 4: 700, 5: 2100],
        "bar": [3: 140, 4: 350, 5: 1050],
        "bell": [3: 70, 4: 175, 5: 530],
        "melon": [3: 42, 4: 105, 5: 320],
        "grape": [3: 28, 4: 70, 5: 210],
        "plum": [3: 21, 4: 53, 5: 160],
        "lemon": [3: 14, 4: 35, 5: 105],
        "cherry": [2: 7, 3: 18, 4: 42, 5: 105]
    ]

    static var payRows: [PayRow] {
        order.reversed().map { symbol in
            PayRow(symbol: symbol, detail: payLine(pay[symbol] ?? [:]))
        }
    }

    static func evaluate(grid: [[String]], totalBet: Int) -> (lineWins: [LineWin], total: Int) {
        let lineBet = totalBet / 10
        let wins = LineEvaluator.plain(grid: grid, lines: Paylines.ten, pay: pay, lineBet: lineBet)
        return (wins, wins.reduce(0) { $0 + $1.amount })
    }

    static func spin<R: RandomNumberGenerator>(totalBet: Int, rng: inout R) -> RoundResult {
        let grid = RNGDraw.grid(&rng, weights: weights)
        let evaluated = evaluate(grid: grid, totalBet: totalBet)
        return RoundResult(
            grid: grid, lineWins: evaluated.lineWins, scatterCount: 0, scatterWin: 0,
            freeSpins: [], specialSymbol: nil, totalWin: evaluated.total
        )
    }
}

enum JokerEngine {
    static let order = ["joker", "star", "seven", "bell", "melon", "grape", "cherry"]
    static let weights: [(String, Int)] = [
        ("joker", 2), ("star", 2), ("seven", 4), ("bell", 7),
        ("melon", 10), ("grape", 13), ("cherry", 8)
    ]
    static let pay: [String: [Int: Int]] = [
        "joker": [3: 30, 4: 100, 5: 400],
        "seven": [3: 20, 4: 60, 5: 200],
        "bell": [3: 12, 4: 30, 5: 100],
        "melon": [3: 8, 4: 20, 5: 60],
        "grape": [3: 5, 4: 12, 5: 40],
        "cherry": [3: 5, 4: 12, 5: 30]
    ]
    static let lineOrder = ["joker", "seven", "bell", "melon", "grape", "cherry"]

    static var payRows: [PayRow] {
        var rows = lineOrder.map { PayRow(symbol: $0, detail: payLine(pay[$0] ?? [:])) }
        rows.insert(PayRow(symbol: "star", detail: "3→2×  4→8×  5→20×  6→50×  7+→100× Einsatz"), at: 1)
        return rows
    }

    static func starMultiplier(_ count: Int) -> Int {
        switch count {
        case 3: return 2
        case 4: return 8
        case 5: return 20
        case 6: return 50
        case 7...: return 100
        default: return 0
        }
    }

    static func evaluate(grid: [[String]], totalBet: Int) -> (lineWins: [LineWin], stars: Int, scatterWin: Int, total: Int) {
        let lineBet = totalBet / 5
        let wins = LineEvaluator.wild(
            grid: grid, lines: Paylines.five, pay: pay, order: lineOrder,
            wild: "joker", lineBet: lineBet
        )
        let stars = grid.reduce(0) { $0 + $1.filter { $0 == "star" }.count }
        let scatter = starMultiplier(stars) * totalBet
        let lineTotal = wins.reduce(0) { $0 + $1.amount }
        return (wins, stars, scatter, lineTotal + scatter)
    }

    static func spin<R: RandomNumberGenerator>(totalBet: Int, rng: inout R) -> RoundResult {
        let grid = RNGDraw.grid(&rng, weights: weights)
        let evaluated = evaluate(grid: grid, totalBet: totalBet)
        return RoundResult(
            grid: grid, lineWins: evaluated.lineWins, scatterCount: evaluated.stars,
            scatterWin: evaluated.scatterWin, freeSpins: [], specialSymbol: nil, totalWin: evaluated.total
        )
    }
}

enum SphinxEngine {
    static let order = ["book", "pharaoh", "ankh", "scarab", "eye", "ace", "king", "queen", "jack", "ten"]
    static let weights: [(String, Int)] = [
        ("book", 5), ("pharaoh", 4), ("ankh", 5), ("scarab", 7), ("eye", 8),
        ("ace", 16), ("king", 18), ("queen", 20), ("jack", 22), ("ten", 24)
    ]
    /// Line pays, multiples of the line bet. Books are wild.
    static let pay: [String: [Int: Int]] = [
        "book": [3: 14, 4: 55, 5: 210],
        "pharaoh": [3: 42, 4: 110, 5: 280],
        "ankh": [3: 28, 4: 70, 5: 170],
        "scarab": [3: 17, 4: 42, 5: 110],
        "eye": [3: 11, 4: 28, 5: 70],
        "ace": [3: 7, 4: 17, 5: 42],
        "king": [3: 7, 4: 17, 5: 42],
        "queen": [3: 6, 4: 14, 5: 35],
        "jack": [3: 6, 4: 14, 5: 35],
        "ten": [3: 4, 4: 11, 5: 28]
    ]
    /// Expanding-symbol pays during free spins, multiples of the TOTAL bet.
    /// Premium symbols also pay for two reels.
    static let expandPay: [String: [Int: Int]] = [
        "pharaoh": [2: 3, 3: 42, 4: 110, 5: 280],
        "ankh": [2: 2, 3: 28, 4: 70, 5: 170],
        "scarab": [3: 17, 4: 42, 5: 110],
        "eye": [3: 11, 4: 28, 5: 70],
        "ace": [3: 7, 4: 17, 5: 42],
        "king": [3: 7, 4: 17, 5: 42],
        "queen": [3: 6, 4: 14, 5: 35],
        "jack": [3: 6, 4: 14, 5: 35],
        "ten": [3: 4, 4: 11, 5: 28]
    ]
    static let freeSpinAward = 10
    static let freeSpinCap = 120

    static var payRows: [PayRow] {
        order.map { symbol in
            var text = payLine(pay[symbol] ?? [:])
            if symbol != "book", let two = expandPay[symbol]?[2] {
                text = "2 Walzen → \(two)× Einsatz · " + text
            }
            return PayRow(symbol: symbol, detail: text)
        }
    }

    static func scatterMultiplier(_ count: Int) -> Int {
        switch count {
        case 3: return 3
        case 4: return 14
        case 5: return 55
        case 6...: return 140
        default: return 0
        }
    }

    static func evaluateBase(grid: [[String]], totalBet: Int) -> (lineWins: [LineWin], books: Int, scatterWin: Int, total: Int) {
        let lineBet = totalBet / 10
        let wins = LineEvaluator.wild(
            grid: grid, lines: Paylines.ten, pay: pay, order: order,
            wild: "book", lineBet: lineBet
        )
        let books = grid.reduce(0) { $0 + $1.filter { $0 == "book" }.count }
        let scatter = scatterMultiplier(books) * totalBet
        return (wins, books, scatter, wins.reduce(0) { $0 + $1.amount } + scatter)
    }

    static func spin<R: RandomNumberGenerator>(totalBet: Int, rng: inout R) -> RoundResult {
        let grid = RNGDraw.grid(&rng, weights: weights)
        let base = evaluateBase(grid: grid, totalBet: totalBet)
        var steps: [FreeSpinStep] = []
        var special: String?
        if base.books >= 3 {
            let candidates = order.filter { $0 != "book" }
            let chosen = candidates[RNGDraw.index(&rng, upper: candidates.count)]
            special = chosen
            let lineBet = totalBet / 10
            var left = freeSpinAward
            var played = 0
            while left > 0 && played < freeSpinCap {
                played += 1
                left -= 1
                let freeGrid = RNGDraw.grid(&rng, weights: weights)
                let books = freeGrid.reduce(0) { $0 + $1.filter { $0 == "book" }.count }
                let scatter = scatterMultiplier(books) * totalBet
                let retrigger = books >= 3
                if retrigger { left += freeSpinAward }
                let other = LineEvaluator.wild(
                    grid: freeGrid, lines: Paylines.ten, pay: pay, order: order,
                    wild: "book", lineBet: lineBet, skip: chosen
                )
                let reels = freeGrid.indices.filter { freeGrid[$0].contains(chosen) }
                let expandMult = expandPay[chosen]?[reels.count] ?? 0
                let expandWin = expandMult * totalBet
                let stepTotal = other.reduce(0) { $0 + $1.amount } + scatter + expandWin
                steps.append(FreeSpinStep(
                    grid: freeGrid, lineWins: other, scatterCount: books, scatterWin: scatter,
                    expandedReels: Array(reels), expandSymbol: chosen, expandWin: expandWin,
                    retriggered: retrigger, totalWin: stepTotal
                ))
            }
        }
        let freeTotal = steps.reduce(0) { $0 + $1.totalWin }
        return RoundResult(
            grid: grid, lineWins: base.lineWins, scatterCount: base.books, scatterWin: base.scatterWin,
            freeSpins: steps, specialSymbol: special, totalWin: base.total + freeTotal
        )
    }
}

func payLine(_ table: [Int: Int]) -> String {
    table.keys.sorted().map { count in
        "\(count)→\(table[count] ?? 0)"
    }.joined(separator: "  ")
}

enum RTPLab {
    struct Report: Sendable {
        var rtp: Double
        var hitRate: Double
        var spins: Int
    }

    static func simulate(game: GameKind, spins: Int, seed: UInt64, bet: Int = 100) -> Report {
        var rng = SeededGenerator(seed: seed)
        var won = 0
        var hits = 0
        for _ in 0..<spins {
            let result = game.spin(totalBet: bet, rng: &rng)
            won += result.totalWin
            if result.totalWin > 0 { hits += 1 }
        }
        let wagered = spins * bet
        return Report(
            rtp: Double(won) / Double(wagered),
            hitRate: Double(hits) / Double(spins),
            spins: spins
        )
    }
}

import Foundation

/// Symbols of the "Book of Muse" slot. The book is Wild + Scatter.
enum BookSymbol: String, CaseIterable {
    case book
    case muse
    case crown
    case gem
    case scarab
    case ace
    case king
    case queen
    case jack

    var displayName: String {
        switch self {
        case .book: return "Buch"
        case .muse: return "Muse-Stern"
        case .crown: return "Krone"
        case .gem: return "Juwel"
        case .scarab: return "Skarabäus"
        case .ace: return "Ass"
        case .king: return "König"
        case .queen: return "Dame"
        case .jack: return "Bube"
        }
    }

    /// Reel weight per cell (higher = more common).
    static let weights: [BookSymbol: Int] = [
        .book: 2, .muse: 3, .crown: 4, .gem: 5, .scarab: 6,
        .ace: 8, .king: 8, .queen: 9, .jack: 9
    ]

    /// Line payouts as multiples of the line bet, keyed by count (3/4/5).
    static let paytable: [BookSymbol: [Int: Int]] = [
        .book: [3: 20, 4: 200, 5: 1000],
        .muse: [3: 10, 4: 50, 5: 250],
        .crown: [3: 8, 4: 30, 5: 150],
        .gem: [3: 5, 4: 20, 5: 100],
        .scarab: [3: 5, 4: 15, 5: 75],
        .ace: [3: 4, 4: 10, 5: 50],
        .king: [3: 4, 4: 10, 5: 50],
        .queen: [3: 3, 4: 8, 5: 40],
        .jack: [3: 3, 4: 8, 5: 40]
    ]

    /// Symbols that can become the free-spin expanding symbol (never the book itself).
    static var freeSpinCandidates: [BookSymbol] {
        allCases.filter { $0 != .book }
    }

    static func random<R: RandomNumberGenerator>(using rng: inout R) -> BookSymbol {
        let total = weights.values.reduce(0, +)
        var roll = Int.random(in: 0..<total, using: &rng)
        for symbol in allCases {
            let weight = weights[symbol] ?? 0
            if roll < weight { return symbol }
            roll -= weight
        }
        return .jack
    }
}

/// Result of one fully evaluated Book of Muse spin (base game math).
struct BookSpinResult {
    let grid: [[BookSymbol]] // [reel][row], 5 x 3
    let lineWins: [LineWin]
    let lineWinTotal: Int
    let scatterCount: Int
    let scatterWin: Int
}

enum BookOfMuseEngine {
    static let freeSpinsAwarded = 10

    static func randomGrid() -> [[BookSymbol]] {
        var rng = SystemRandomNumberGenerator()
        return randomGrid(using: &rng)
    }

    static func randomGrid<R: RandomNumberGenerator>(using rng: inout R) -> [[BookSymbol]] {
        (0..<5).map { _ in (0..<3).map { _ in BookSymbol.random(using: &rng) } }
    }

    static func spin(betPerLine: Int, totalBet: Int) -> BookSpinResult {
        var rng = SystemRandomNumberGenerator()
        let grid = randomGrid(using: &rng)
        let evaluation = evaluate(grid: grid, betPerLine: betPerLine, totalBet: totalBet)
        return BookSpinResult(
            grid: grid,
            lineWins: evaluation.lineWins,
            lineWinTotal: evaluation.lineWins.reduce(0) { $0 + $1.amount },
            scatterCount: evaluation.scatterCount,
            scatterWin: evaluation.scatterWin
        )
    }

    /// Evaluates the 10 paylines (book substitutes for every symbol) plus the book scatter.
    static func evaluate(grid: [[BookSymbol]], betPerLine: Int, totalBet: Int)
        -> (lineWins: [LineWin], scatterCount: Int, scatterWin: Int)
    {
        var lineWins: [LineWin] = []

        for (lineIndex, line) in SlotMath.fiveReelLines.enumerated() {
            var best: LineWin?
            for symbol in BookSymbol.allCases {
                var count = 0
                var positions: [GridPosition] = []
                for reel in 0..<5 {
                    let cell = grid[reel][line[reel]]
                    let matches: Bool
                    if symbol == .book {
                        matches = cell == .book
                    } else {
                        matches = cell == symbol || cell == .book // wild substitution
                    }
                    if matches {
                        count += 1
                        positions.append(GridPosition(reel: reel, row: line[reel]))
                    } else {
                        break
                    }
                }
                guard count >= 3, let multiplier = BookSymbol.paytable[symbol]?[count] else { continue }
                let amount = multiplier * betPerLine
                if best == nil || amount > best!.amount {
                    best = LineWin(
                        lineIndex: lineIndex,
                        symbolID: symbol.rawValue,
                        count: count,
                        amount: amount,
                        positions: positions
                    )
                }
            }
            if let best {
                lineWins.append(best)
            }
        }

        let scatterCount = grid.reduce(0) { partial, column in
            partial + column.filter { $0 == .book }.count
        }
        let scatterWin = scatterMultiplier(for: scatterCount) * totalBet
        return (lineWins, scatterCount, scatterWin)
    }

    /// Scatter pays as a multiple of the total bet.
    static func scatterMultiplier(for bookCount: Int) -> Int {
        switch bookCount {
        case 3: return 5
        case 4: return 25
        case 5...15: return 100
        default: return 0
        }
    }

    /// Free-spin feature: if the special symbol appears on 3+ reels it expands to
    /// cover those reels and pays like a line win based on the number of reels hit.
    static func expandingWin(grid: [[BookSymbol]], special: BookSymbol, betPerLine: Int)
        -> (amount: Int, reels: Set<Int>)
    {
        var reels = Set<Int>()
        for reel in 0..<5 where grid[reel].contains(special) {
            reels.insert(reel)
        }
        guard reels.count >= 3, let multiplier = BookSymbol.paytable[special]?[reels.count] else {
            return (0, [])
        }
        return (multiplier * betPerLine, reels)
    }
}

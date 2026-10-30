import Foundation

/// Symbols of "Mochi Millions" — a 3-reel classic with plush & gem symbols.
enum MochiSymbol: String, CaseIterable {
    case teddy
    case diamond
    case star
    case heart
    case coin
    case bell

    var displayName: String {
        switch self {
        case .teddy: return "Plüsch-Teddy"
        case .diamond: return "Diamant"
        case .star: return "Stern"
        case .heart: return "Herz"
        case .coin: return "Münze"
        case .bell: return "Glocke"
        }
    }

    static let weights: [MochiSymbol: Int] = [
        .teddy: 2, .diamond: 3, .star: 4, .heart: 5, .coin: 6, .bell: 6
    ]

    /// Three-of-a-kind payouts as multiples of the line bet.
    static let paytable: [MochiSymbol: Int] = [
        .teddy: 100, .diamond: 50, .star: 25, .heart: 15, .coin: 10, .bell: 8
    ]

    /// Symbols that count as "jewels" for the mixed-jewel line win.
    static let jewelSet: Set<MochiSymbol> = [.diamond, .star, .heart]
    static let jewelMixPayout = 4

    static func random<R: RandomNumberGenerator>(using rng: inout R) -> MochiSymbol {
        let total = weights.values.reduce(0, +)
        var roll = Int.random(in: 0..<total, using: &rng)
        for symbol in allCases {
            let weight = weights[symbol] ?? 0
            if roll < weight { return symbol }
            roll -= weight
        }
        return .bell
    }
}

struct MochiSpinResult {
    let grid: [[MochiSymbol]] // [reel][row], 3 x 3
    let lineWins: [LineWin]
    let totalWin: Int
}

enum MochiMillionsEngine {
    static func randomGrid() -> [[MochiSymbol]] {
        var rng = SystemRandomNumberGenerator()
        return randomGrid(using: &rng)
    }

    static func randomGrid<R: RandomNumberGenerator>(using rng: inout R) -> [[MochiSymbol]] {
        (0..<3).map { _ in (0..<3).map { _ in MochiSymbol.random(using: &rng) } }
    }

    static func spin(betPerLine: Int) -> MochiSpinResult {
        var rng = SystemRandomNumberGenerator()
        let grid = randomGrid(using: &rng)
        let wins = evaluate(grid: grid, betPerLine: betPerLine)
        return MochiSpinResult(
            grid: grid,
            lineWins: wins,
            totalWin: wins.reduce(0) { $0 + $1.amount }
        )
    }

    /// 5 lines over 3 reels: three of a kind, or any mixed jewel combination.
    static func evaluate(grid: [[MochiSymbol]], betPerLine: Int) -> [LineWin] {
        var wins: [LineWin] = []
        for (lineIndex, line) in SlotMath.threeReelLines.enumerated() {
            let symbols = (0..<3).map { grid[$0][line[$0]] }
            let positions = (0..<3).map { GridPosition(reel: $0, row: line[$0]) }
            if symbols[0] == symbols[1], symbols[1] == symbols[2],
               let multiplier = MochiSymbol.paytable[symbols[0]] {
                wins.append(
                    LineWin(
                        lineIndex: lineIndex,
                        symbolID: symbols[0].rawValue,
                        count: 3,
                        amount: multiplier * betPerLine,
                        positions: positions
                    )
                )
            } else if symbols.allSatisfy({ MochiSymbol.jewelSet.contains($0) }) {
                wins.append(
                    LineWin(
                        lineIndex: lineIndex,
                        symbolID: "jewelMix",
                        count: 3,
                        amount: MochiSymbol.jewelMixPayout * betPerLine,
                        positions: positions
                    )
                )
            }
        }
        return wins
    }
}

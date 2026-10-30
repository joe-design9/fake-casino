import Foundation

/// Symbols of the "Vice Fruits" slot — a classic 5-reel fruit machine, no wilds.
enum FruitSymbol: String, CaseIterable {
    case cherry
    case lemon
    case grape
    case plum
    case bell
    case diamond
    case seven

    var displayName: String {
        switch self {
        case .cherry: return "Kirsche"
        case .lemon: return "Zitrone"
        case .grape: return "Traube"
        case .plum: return "Pflaume"
        case .bell: return "Glocke"
        case .diamond: return "Diamant"
        case .seven: return "Sieben"
        }
    }

    static let weights: [FruitSymbol: Int] = [
        .seven: 2, .diamond: 3, .bell: 5, .grape: 7,
        .plum: 8, .lemon: 9, .cherry: 10
    ]

    /// Line payouts as multiples of the line bet. Cherries also pay for 2 of a kind.
    static let paytable: [FruitSymbol: [Int: Int]] = [
        .seven: [3: 50, 4: 200, 5: 1000],
        .diamond: [3: 25, 4: 100, 5: 500],
        .bell: [3: 10, 4: 40, 5: 150],
        .grape: [3: 5, 4: 20, 5: 80],
        .plum: [3: 4, 4: 15, 5: 60],
        .lemon: [3: 3, 4: 10, 5: 40],
        .cherry: [2: 2, 3: 5, 4: 15, 5: 50]
    ]

    static func random<R: RandomNumberGenerator>(using rng: inout R) -> FruitSymbol {
        let total = weights.values.reduce(0, +)
        var roll = Int.random(in: 0..<total, using: &rng)
        for symbol in allCases {
            let weight = weights[symbol] ?? 0
            if roll < weight { return symbol }
            roll -= weight
        }
        return .cherry
    }
}

struct FruitSpinResult {
    let grid: [[FruitSymbol]] // [reel][row], 5 x 3
    let lineWins: [LineWin]
    let totalWin: Int
}

enum ViceFruitsEngine {
    static func randomGrid() -> [[FruitSymbol]] {
        var rng = SystemRandomNumberGenerator()
        return randomGrid(using: &rng)
    }

    static func randomGrid<R: RandomNumberGenerator>(using rng: inout R) -> [[FruitSymbol]] {
        (0..<5).map { _ in (0..<3).map { _ in FruitSymbol.random(using: &rng) } }
    }

    static func spin(betPerLine: Int) -> FruitSpinResult {
        var rng = SystemRandomNumberGenerator()
        let grid = randomGrid(using: &rng)
        let wins = evaluate(grid: grid, betPerLine: betPerLine)
        return FruitSpinResult(
            grid: grid,
            lineWins: wins,
            totalWin: wins.reduce(0) { $0 + $1.amount }
        )
    }

    /// Straight left-to-right line evaluation, no wilds.
    static func evaluate(grid: [[FruitSymbol]], betPerLine: Int) -> [LineWin] {
        var wins: [LineWin] = []
        for (lineIndex, line) in SlotMath.fiveReelLines.enumerated() {
            let first = grid[0][line[0]]
            var count = 0
            var positions: [GridPosition] = []
            for reel in 0..<5 {
                if grid[reel][line[reel]] == first {
                    count += 1
                    positions.append(GridPosition(reel: reel, row: line[reel]))
                } else {
                    break
                }
            }
            if let multiplier = FruitSymbol.paytable[first]?[count] {
                wins.append(
                    LineWin(
                        lineIndex: lineIndex,
                        symbolID: first.rawValue,
                        count: count,
                        amount: multiplier * betPerLine,
                        positions: positions
                    )
                )
            }
        }
        return wins
    }
}

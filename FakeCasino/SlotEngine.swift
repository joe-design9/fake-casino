import Foundation

// MARK: - Symbol artwork (pure data; rendered by SymbolArt.swift)

enum ShapeKind: String {
    case cherry
    case grape
    case lemon
    case donut
    case candy
    case lollipop
    case horseshoe
    case gem
    case coin
    case seven
    case bar
}

enum SymbolArt: Equatable {
    case sf(String)
    case letter(String)
    case shape(ShapeKind)
}

/// Two/three-stop gradient palette (hex strings) for one machine.
struct MachinePalette: Equatable {
    let colors: [String]
    let accent: String

    init(_ colors: [String], accent: String) {
        self.colors = colors
        self.accent = accent
    }
}

// MARK: - Machine configuration

enum MachineCategory: String, CaseIterable, Hashable {
    case freispiele = "Freispiele"
    case klassiker = "Klassiker"
    case hochvolatil = "Hochvolatil"
}

struct SlotSymbolConfig: Identifiable, Equatable {
    let id: String
    let name: String
    let art: SymbolArt
    let tint: String // hex
    let weight: Int
    /// Line payouts as multiples of the line bet, keyed by match count.
    let pays: [Int: Int]
    let isWild: Bool
    let isScatter: Bool

    init(
        id: String,
        name: String,
        art: SymbolArt,
        tint: String,
        weight: Int,
        pays: [Int: Int],
        isWild: Bool = false,
        isScatter: Bool = false
    ) {
        self.id = id
        self.name = name
        self.art = art
        self.tint = tint
        self.weight = weight
        self.pays = pays
        self.isWild = isWild
        self.isScatter = isScatter
    }
}

struct SlotMachineConfig: Identifiable {
    let id: String
    let name: String
    let tagline: String
    let reels: Int // 3 or 5
    let lineCount: Int
    let symbols: [SlotSymbolConfig]
    /// Scatter payouts as multiples of the TOTAL bet, keyed by scatter count anywhere.
    let scatterPays: [Int: Int]
    /// Free spins awarded for 3+ scatters (0 = no free-spin feature).
    let freeSpinsAwarded: Int
    /// Multiplier applied to every win during free spins (1 = none).
    let freeSpinMultiplier: Int
    /// Chance (0...1) that a winning spin is multiplied afterwards.
    let randomMultiplierChance: Double
    /// Random multiplier is rolled in 2...randomMultiplierMax.
    let randomMultiplierMax: Int
    let palette: MachinePalette
    let motif: SymbolArt
    let categories: Set<MachineCategory>

    var wildSymbol: SlotSymbolConfig? { symbols.first { $0.isWild } }
    var scatterSymbol: SlotSymbolConfig? { symbols.first { $0.isScatter } }
    var totalBetMultiplier: Int { lineCount }

    func symbol(id: String) -> SlotSymbolConfig? {
        symbols.first { $0.id == id }
    }
}

// MARK: - Generic engine

struct GenericSpinResult {
    let grid: [[String]] // [reel][row] of symbol ids
    let lineWins: [LineWin]
    let lineWinTotal: Int
    let scatterCount: Int
    let scatterWin: Int

    var rawTotal: Int { lineWinTotal + scatterWin }
}

enum GenericSlotEngine {
    static func randomSymbol(config: SlotMachineConfig, using rng: inout SystemRandomNumberGenerator) -> String {
        let total = config.symbols.reduce(0) { $0 + $1.weight }
        var roll = Int.random(in: 0..<total, using: &rng)
        for symbol in config.symbols {
            if roll < symbol.weight { return symbol.id }
            roll -= symbol.weight
        }
        return config.symbols.last?.id ?? ""
    }

    static func randomGrid(config: SlotMachineConfig) -> [[String]] {
        var rng = SystemRandomNumberGenerator()
        return (0..<config.reels).map { _ in
            (0..<3).map { _ in randomSymbol(config: config, using: &rng) }
        }
    }

    static func spin(config: SlotMachineConfig, betPerLine: Int, totalBet: Int) -> GenericSpinResult {
        let grid = randomGrid(config: config)
        return evaluate(config: config, grid: grid, betPerLine: betPerLine, totalBet: totalBet)
    }

    static func evaluate(
        config: SlotMachineConfig,
        grid: [[String]],
        betPerLine: Int,
        totalBet: Int
    ) -> GenericSpinResult {
        let lines = SlotMath.paylines(reels: config.reels, count: config.lineCount)
        let wildID = config.wildSymbol?.id
        var lineWins: [LineWin] = []

        for (lineIndex, line) in lines.enumerated() {
            var best: LineWin?
            for candidate in config.symbols where !candidate.isScatter {
                var count = 0
                var positions: [GridPosition] = []
                for reel in 0..<config.reels {
                    let cell = grid[reel][line[reel]]
                    if cell == candidate.id || cell == wildID {
                        count += 1
                        positions.append(GridPosition(reel: reel, row: line[reel]))
                    } else {
                        break
                    }
                }
                guard count >= 2, let multiplier = candidate.pays[count] else { continue }
                let amount = multiplier * betPerLine
                if best == nil || amount > best!.amount {
                    best = LineWin(
                        lineIndex: lineIndex,
                        symbolID: candidate.id,
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

        var scatterCount = 0
        if let scatterID = config.scatterSymbol?.id {
            scatterCount = grid.reduce(0) { partial, column in
                partial + column.filter { $0 == scatterID }.count
            }
        }
        let scatterWin = (config.scatterPays[scatterCount] ?? 0) * totalBet

        return GenericSpinResult(
            grid: grid,
            lineWins: lineWins,
            lineWinTotal: lineWins.reduce(0) { $0 + $1.amount },
            scatterCount: scatterCount,
            scatterWin: scatterWin
        )
    }
}

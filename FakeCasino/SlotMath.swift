import Foundation

/// A cell position inside a slot grid (column-major: grid[reel][row]).
struct GridPosition: Equatable, Hashable {
    let reel: Int
    let row: Int
}

/// One evaluated payline win.
struct LineWin {
    let lineIndex: Int
    let symbolID: String
    let count: Int
    let amount: Int
    let positions: [GridPosition]
}

enum SlotMath {
    /// 20 paylines for a 5-reel / 3-row machine.
    /// Each entry lists the row (0 = top, 1 = middle, 2 = bottom) for reels 0...4.
    /// The first 10 entries are the classic 10 lines; the first 5 are the classic 5.
    static let twentyLines: [[Int]] = [
        [1, 1, 1, 1, 1], // 1: middle
        [0, 0, 0, 0, 0], // 2: top
        [2, 2, 2, 2, 2], // 3: bottom
        [0, 1, 2, 1, 0], // 4: V
        [2, 1, 0, 1, 2], // 5: inverted V
        [0, 0, 1, 0, 0], // 6
        [2, 2, 1, 2, 2], // 7
        [1, 0, 0, 0, 1], // 8
        [1, 2, 2, 2, 1], // 9
        [1, 0, 1, 0, 1], // 10
        [1, 2, 1, 2, 1], // 11
        [0, 1, 1, 1, 0], // 12
        [2, 1, 1, 1, 2], // 13
        [0, 1, 0, 1, 0], // 14
        [2, 1, 2, 1, 2], // 15
        [1, 1, 0, 1, 1], // 16
        [1, 1, 2, 1, 1], // 17
        [0, 0, 2, 0, 0], // 18
        [2, 2, 0, 2, 2], // 19
        [1, 0, 2, 0, 1]  // 20
    ]

    /// 10 classic paylines for a 5-reel / 3-row machine (prefix of the 20-line set).
    static var fiveReelLines: [[Int]] { Array(twentyLines.prefix(10)) }

    /// 5 paylines for a 3-reel / 3-row classic machine.
    static let threeReelLines: [[Int]] = [
        [0, 0, 0], // top row
        [1, 1, 1], // middle row
        [2, 2, 2], // bottom row
        [0, 1, 2], // diagonal down
        [2, 1, 0]  // diagonal up
    ]

    /// Returns the payline set for a machine configuration.
    /// - 5-reel machines: the first `count` entries of the 20-line table (5, 10 or 20).
    /// - 3-reel machines: the first `count` entries of the 3-reel table (max 5).
    static func paylines(reels: Int, count: Int) -> [[Int]] {
        if reels == 3 {
            return Array(threeReelLines.prefix(min(count, threeReelLines.count)))
        }
        return Array(twentyLines.prefix(min(count, twentyLines.count)))
    }
}

extension Int {
    /// German-style grouped number, e.g. 10000 -> "10.000".
    var grouped: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = "."
        formatter.usesGroupingSeparator = true
        return formatter.string(from: NSNumber(value: self)) ?? "\(self)"
    }
}

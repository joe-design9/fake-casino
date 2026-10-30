import Foundation

/// A cell position inside a slot grid (column-major: grid[reel][row]).
struct GridPosition: Equatable {
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
    /// 10 classic paylines for a 5-reel / 3-row machine.
    /// Each entry lists the row (0 = top, 1 = middle, 2 = bottom) for reels 0...4.
    static let fiveReelLines: [[Int]] = [
        [1, 1, 1, 1, 1], // middle
        [0, 0, 0, 0, 0], // top
        [2, 2, 2, 2, 2], // bottom
        [0, 1, 2, 1, 0], // V
        [2, 1, 0, 1, 2], // inverted V
        [0, 0, 1, 0, 0],
        [2, 2, 1, 2, 2],
        [1, 0, 0, 0, 1],
        [1, 2, 2, 2, 1],
        [1, 0, 1, 0, 1]
    ]

    /// 5 paylines for a 3-reel / 3-row classic machine.
    static let threeReelLines: [[Int]] = [
        [0, 0, 0], // top row
        [1, 1, 1], // middle row
        [2, 2, 2], // bottom row
        [0, 1, 2], // diagonal down
        [2, 1, 0]  // diagonal up
    ]
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

import SwiftUI

struct ReelBoard: View {
    let columns: [[String]]
    let pool: [String]
    let spinning: Bool
    let spinID: Int
    let turbo: Bool
    let anticipateFrom: Int?
    let highlighted: Set<GridPosition>
    let winLines: [LineWin]
    let forcedReels: [Int: String]
    let onReelStop: (Int) -> Void

    var body: some View {
        GeometryReader { geo in
            let cols = max(columns.count, 1)
            let gap: CGFloat = 5
            let cellW = (geo.size.width - gap * CGFloat(cols - 1)) / CGFloat(cols)
            let cellH = (geo.size.height - gap * 2) / 3
            ZStack(alignment: .topLeading) {
                HStack(spacing: gap) {
                    ForEach(0..<cols, id: \.self) { reel in
                        let rows = reel < columns.count ? columns[reel] : ["cherry", "cherry", "cherry"]
                        ReelColumn(
                            target: rows,
                            pool: pool,
                            reelIndex: reel,
                            spinning: spinning,
                            spinID: spinID,
                            delay: stopDelay(reel: reel),
                            highlighted: Set(highlighted.filter { $0.reel == reel }.map(\.row)),
                            forcedSymbol: forcedReels[reel],
                            tense: (anticipateFrom.map { reel >= $0 } ?? false) && spinning,
                            onStopped: onReelStop
                        )
                        .frame(width: cellW, height: cellH * 3 + gap * 2)
                    }
                }
                WinLineLayer(lines: winLines, cellW: cellW, cellH: cellH, gap: gap)
                    .allowsHitTesting(false)
            }
        }
    }

    private func stopDelay(reel: Int) -> Double {
        let base = turbo ? 0.16 : 0.42
        let step = turbo ? 0.09 : 0.22
        var delay = base + Double(reel) * step
        if let start = anticipateFrom, reel >= start {
            delay += turbo ? 0.40 : 0.95
        }
        return delay
    }
}

private struct ReelColumn: View {
    let target: [String]
    let pool: [String]
    let reelIndex: Int
    let spinning: Bool
    let spinID: Int
    let delay: Double
    let highlighted: Set<Int>
    let forcedSymbol: String?
    let tense: Bool
    let onStopped: (Int) -> Void

    @State private var shown: [String]
    @State private var blur: CGFloat = 0
    @State private var offset: CGFloat = 0
    @State private var whirling = false
    @State private var handledSpin = -1
    @State private var task: Task<Void, Never>?

    init(
        target: [String],
        pool: [String],
        reelIndex: Int,
        spinning: Bool,
        spinID: Int,
        delay: Double,
        highlighted: Set<Int>,
        forcedSymbol: String?,
        tense: Bool,
        onStopped: @escaping (Int) -> Void
    ) {
        self.target = target
        self.pool = pool
        self.reelIndex = reelIndex
        self.spinning = spinning
        self.spinID = spinID
        self.delay = delay
        self.highlighted = highlighted
        self.forcedSymbol = forcedSymbol
        self.tense = tense
        self.onStopped = onStopped
        let initial = forcedSymbol.map { [$0, $0, $0] } ?? target
        _shown = State(initialValue: initial)
    }

    var body: some View {
        VStack(spacing: 5) {
            ForEach(0..<3, id: \.self) { row in
                SymbolTile(
                    id: shown.indices.contains(row) ? shown[row] : "cherry",
                    highlighted: highlighted.contains(row),
                    tense: tense
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .offset(y: offset)
        .blur(radius: blur)
        .onChange(of: spinning) { _, isSpinning in
            if isSpinning {
                beginWhirl()
            } else if handledSpin != spinID {
                handledSpin = spinID
                land()
            }
        }
        .onChange(of: forcedSymbol) { _, symbol in
            if let symbol, !spinning, !whirling {
                shown = [symbol, symbol, symbol]
            }
        }
    }

    private func beginWhirl() {
        task?.cancel()
        whirling = true
        blur = tense ? 2.5 : 6
        task = Task {
            while !Task.isCancelled {
                let next = (0..<3).map { _ in pool.randomElement() ?? "cherry" }
                await MainActor.run {
                    if whirling { shown = next }
                }
                try? await Task.sleep(nanoseconds: tense ? 90_000_000 : 48_000_000)
            }
        }
    }

    private func land() {
        whirling = false
        task?.cancel()
        let pause = delay
        task = Task {
            try? await Task.sleep(nanoseconds: UInt64(pause * 1_000_000_000))
            if Task.isCancelled { return }
            await MainActor.run {
                if let forcedSymbol {
                    shown = [forcedSymbol, forcedSymbol, forcedSymbol]
                } else {
                    shown = target
                }
                blur = 0
                offset = -12
                withAnimation(.spring(response: 0.34, dampingFraction: 0.58)) {
                    offset = 0
                }
                onStopped(reelIndex)
            }
        }
    }
}

private struct WinLineLayer: View {
    let lines: [LineWin]
    let cellW: CGFloat
    let cellH: CGFloat
    let gap: CGFloat

    var body: some View {
        Canvas { context, _ in
            for win in lines {
                var path = Path()
                let points = win.positions.map(center)
                guard let first = points.first else { continue }
                path.move(to: first)
                for point in points.dropFirst() {
                    path.addLine(to: point)
                }
                context.stroke(
                    path,
                    with: .color(Color(red: 1, green: 0.86, blue: 0.35).opacity(0.95)),
                    style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round)
                )
            }
        }
    }

    private func center(_ position: GridPosition) -> CGPoint {
        CGPoint(
            x: CGFloat(position.reel) * (cellW + gap) + cellW / 2,
            y: CGFloat(position.row) * (cellH + gap) + cellH / 2
        )
    }
}

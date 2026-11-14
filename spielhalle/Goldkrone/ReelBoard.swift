import SwiftUI

enum LinePalette {
    static let colors: [Color] = [
        Color(red: 0.15, green: 0.75, blue: 0.25),
        Color(red: 1.0, green: 0.82, blue: 0.1),
        Color(red: 0.92, green: 0.16, blue: 0.18),
        Color(red: 0.2, green: 0.75, blue: 0.95),
        Color(red: 1.0, green: 0.5, blue: 0.1),
        Color(red: 0.7, green: 0.3, blue: 0.95),
        Color(red: 0.95, green: 0.4, blue: 0.7),
        Color.white,
        Color(red: 0.4, green: 0.95, blue: 0.7),
        Color(red: 0.35, green: 0.45, blue: 1)
    ]

    static func color(for index: Int) -> Color {
        colors[index % colors.count]
    }
}

struct ReelBoard: View {
    let columns: [[String]]
    let pool: [String]
    let lines: [[Int]]
    let spinning: Bool
    let spinID: Int
    let turbo: Bool
    let anticipateFrom: Int?
    let highlighted: Set<GridPosition>
    let winLines: [LineWin]
    let forcedReels: [Int: String]
    let onReelStop: (Int) -> Void

    var body: some View {
        HStack(spacing: 4) {
            LineMarkers(count: lines.count, winning: Set(winLines.map(\.lineIndex)), side: .leading)
            GeometryReader { geo in
                let cols = max(columns.count, 1)
                let gap: CGFloat = 3
                let cellW = (geo.size.width - gap * CGFloat(cols - 1)) / CGFloat(cols)
                let cellH = geo.size.height / 3
                ZStack(alignment: .topLeading) {
                    HStack(spacing: gap) {
                        ForEach(0..<cols, id: \.self) { reel in
                            let rows = reel < columns.count ? columns[reel] : Array(repeating: "cherry", count: 3)
                            SpinningReel(
                                target: rows,
                                pool: pool,
                                reelIndex: reel,
                                spinning: spinning,
                                spinID: spinID,
                                delay: stopDelay(reel: reel),
                                highlighted: Set(highlighted.filter { $0.reel == reel }.map(\.row)),
                                forcedSymbol: forcedReels[reel],
                                onStopped: onReelStop
                            )
                            .frame(width: cellW, height: cellH * 3)
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(Color(white: 0.75), lineWidth: 1)
                            )
                        }
                    }
                    WinLineLayer(lines: winLines, cellW: cellW, cellH: cellH, gap: gap)
                        .allowsHitTesting(false)
                }
            }
            LineMarkers(count: lines.count, winning: Set(winLines.map(\.lineIndex)), side: .trailing)
        }
    }

    private func stopDelay(reel: Int) -> Double {
        let fast = LaunchFlags.uiTest
        let base = fast ? 0.08 : (turbo ? 0.22 : 0.55)
        let step = fast ? 0.04 : (turbo ? 0.08 : 0.22)
        var delay = base + Double(reel) * step
        if let start = anticipateFrom, reel >= start {
            delay += fast ? 0.05 : (turbo ? 0.25 : 0.7)
        }
        return delay
    }
}

private struct SpinningReel: View {
    let target: [String]
    let pool: [String]
    let reelIndex: Int
    let spinning: Bool
    let spinID: Int
    let delay: Double
    let highlighted: Set<Int>
    let forcedSymbol: String?
    let onStopped: (Int) -> Void

    @State private var strip: [String]
    @State private var offset: CGFloat = 0
    @State private var blur: CGFloat = 0
    @State private var handledSpin = -1
    @State private var task: Task<Void, Never>?

    private let extra = 16

    init(
        target: [String],
        pool: [String],
        reelIndex: Int,
        spinning: Bool,
        spinID: Int,
        delay: Double,
        highlighted: Set<Int>,
        forcedSymbol: String?,
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
        self.onStopped = onStopped
        let initial = forcedSymbol.map { [$0, $0, $0] } ?? target
        _strip = State(initialValue: initial)
    }

    var body: some View {
        GeometryReader { geo in
            let cell = max(1, geo.size.height / 3)
            VStack(spacing: 0) {
                ForEach(Array(strip.enumerated()), id: \.offset) { _, symbol in
                    SymbolTile(id: symbol, highlighted: false)
                        .frame(width: geo.size.width, height: cell)
                }
            }
            .offset(y: offset)
            .blur(radius: blur)
            .onChange(of: spinning) { _, isSpinning in
                if isSpinning {
                    begin(cell: cell)
                } else if handledSpin != spinID {
                    handledSpin = spinID
                    land(cell: cell)
                }
            }
            .onChange(of: forcedSymbol) { _, symbol in
                guard let symbol, !spinning else { return }
                strip = [symbol, symbol, symbol]
                offset = 0
                blur = 0
            }
        }
        .clipped()
        .overlay {
            // Highlight the settled symbols without fighting the moving strip.
            if !spinning, !highlighted.isEmpty {
                VStack(spacing: 0) {
                    ForEach(0..<3, id: \.self) { row in
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(highlighted.contains(row) ? Color(red: 1, green: 0.8, blue: 0.1) : Color.clear, lineWidth: 3)
                            .frame(maxHeight: .infinity)
                    }
                }
                .allowsHitTesting(false)
            }
        }
    }

    private func begin(cell: CGFloat) {
        task?.cancel()
        let filler = (0..<extra).map { _ in pool.randomElement() ?? "cherry" }
        strip = filler + target
        offset = 0
        blur = 7
        let distance = -CGFloat(extra) * cell
        withAnimation(.easeIn(duration: max(0.12, delay * 0.72))) {
            offset = distance + cell * 0.35
        }
    }

    private func land(cell: CGFloat) {
        task?.cancel()
        let distance = -CGFloat(extra) * cell
        let pause = delay
        task = Task {
            try? await Task.sleep(nanoseconds: UInt64(max(0.05, pause * 0.72) * 1_000_000_000))
            if Task.isCancelled { return }
            await MainActor.run {
                blur = 0
                withAnimation(.spring(response: 0.34, dampingFraction: 0.52)) {
                    offset = distance
                }
            }
            try? await Task.sleep(nanoseconds: 280_000_000)
            if Task.isCancelled { return }
            await MainActor.run {
                let settled = forcedSymbol.map { [$0, $0, $0] } ?? target
                strip = settled
                offset = 0
                blur = 0
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
                let color = LinePalette.color(for: win.lineIndex)
                context.stroke(path, with: .color(color.opacity(0.95)), style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
            }
        }
    }

    private func center(_ position: GridPosition) -> CGPoint {
        CGPoint(
            x: CGFloat(position.reel) * (cellW + gap) + cellW / 2,
            y: CGFloat(position.row) * cellH + cellH / 2
        )
    }
}

private struct LineMarkers: View {
    enum Side { case leading, trailing }
    let count: Int
    let winning: Set<Int>
    let side: Side

    var body: some View {
        VStack(spacing: 3) {
            ForEach(0..<max(count, 1), id: \.self) { index in
                Text("\(index + 1)")
                    .font(.system(size: count > 6 ? 9 : 11, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(width: count > 6 ? 16 : 20, height: count > 6 ? 16 : 20)
                    .background(
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(LinePalette.color(for: index))
                            .shadow(color: winning.contains(index) ? .white : .clear, radius: 4)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Color.white.opacity(winning.contains(index) ? 1 : 0.35), lineWidth: 1)
                    )
            }
        }
        .frame(maxHeight: .infinity)
    }
}

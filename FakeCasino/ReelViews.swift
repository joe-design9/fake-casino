import SwiftUI

/// A slot reel window whose reels are genuine vertical scrolling strips.
///
/// Presentation only: the parent view model pre-computes the result grid and
/// passes it as `columns`. When `spinID` changes, each reel builds a strip of
/// [current symbols + random filler + result symbols] and animates its offset
/// with a strong ease-out curve, so reels race, decelerate and land exactly on
/// the result. Reels stop left-to-right via per-reel durations, each landing
/// with a spring settle bounce. Reels listed in `anticipationReels` glow and
/// pulse while they are still spinning.
struct StripReelView<Item: Equatable, Cell: View>: View {
    /// Final grid to land on: [reel][row].
    let columns: [[Item]]
    let rows: Int
    /// Increment to start a spin.
    let spinID: Int
    /// Total spin time per reel (left-to-right increasing = staggered stops).
    let reelDurations: [Double]
    /// Reels that get the anticipation glow while spinning.
    let anticipationReels: Set<Int>
    /// Cells highlighted in the settled state (winning lines).
    let highlighted: Set<GridPosition>
    /// Optional settled-state override (e.g. expanded free-spin reels).
    let overrideColumns: [[Item]]?
    let cellSize: CGFloat
    let filler: () -> Item
    let onReelStop: (Int) -> Void
    let onFinished: () -> Void
    let cell: (Item, GridPosition, Bool) -> Cell

    private let spacing: CGFloat = 6

    @State private var settledColumns: [[Item]]
    @State private var strips: [[Item]] = []
    @State private var offsets: [CGFloat] = []
    @State private var stoppedFlags: [Bool] = []
    @State private var bounce: [CGFloat] = []
    @State private var spinning = false
    @State private var glowPhase = false

    init(
        columns: [[Item]],
        rows: Int,
        spinID: Int,
        reelDurations: [Double],
        anticipationReels: Set<Int>,
        highlighted: Set<GridPosition>,
        overrideColumns: [[Item]]? = nil,
        cellSize: CGFloat,
        filler: @escaping () -> Item,
        onReelStop: @escaping (Int) -> Void,
        onFinished: @escaping () -> Void,
        @ViewBuilder cell: @escaping (Item, GridPosition, Bool) -> Cell
    ) {
        self.columns = columns
        self.rows = rows
        self.spinID = spinID
        self.reelDurations = reelDurations
        self.anticipationReels = anticipationReels
        self.highlighted = highlighted
        self.overrideColumns = overrideColumns
        self.cellSize = cellSize
        self.filler = filler
        self.onReelStop = onReelStop
        self.onFinished = onFinished
        self.cell = cell
        _settledColumns = State(initialValue: columns)
    }

    private var step: CGFloat { cellSize + spacing }
    private var viewportHeight: CGFloat { CGFloat(rows) * cellSize + CGFloat(rows - 1) * spacing }
    private var gold: Color { Color(red: 0.98, green: 0.82, blue: 0.35) }

    var body: some View {
        HStack(spacing: spacing) {
            ForEach(columns.indices, id: \.self) { reel in
                reelView(reel)
            }
        }
        .onChange(of: spinID) { _, _ in
            startSpin()
        }
    }

    // MARK: - Reel rendering

    private func reelView(_ reel: Int) -> some View {
        let stopped = stoppedFlags.indices.contains(reel) && stoppedFlags[reel]
        let anticipating = spinning && !stopped && anticipationReels.contains(reel)
        return ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.black.opacity(0.28))
                .frame(height: viewportHeight)
            if spinning, strips.indices.contains(reel) {
                stripView(reel)
            } else {
                staticColumn(reel)
            }
            Rectangle()
                .fill(
                    LinearGradient(
                        stops: [
                            .init(color: .black.opacity(0.38), location: 0),
                            .init(color: .clear, location: 0.30),
                            .init(color: .clear, location: 0.70),
                            .init(color: .black.opacity(0.38), location: 1)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(height: viewportHeight)
                .allowsHitTesting(false)
        }
        .frame(maxWidth: .infinity)
        .frame(height: viewportHeight)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(
                    anticipating ? gold.opacity(glowPhase ? 0.95 : 0.35) : Color.white.opacity(0.10),
                    lineWidth: anticipating ? 2.5 : 1
                )
        )
        .shadow(color: anticipating ? gold.opacity(glowPhase ? 0.55 : 0.15) : .clear, radius: 12)
        .offset(y: bounce.indices.contains(reel) ? bounce[reel] : 0)
    }

    private func stripView(_ reel: Int) -> some View {
        let strip = strips[reel]
        let stopped = stoppedFlags.indices.contains(reel) && stoppedFlags[reel]
        return VStack(spacing: spacing) {
            ForEach(strip.indices, id: \.self) { index in
                cell(strip[index], GridPosition(reel: reel, row: min(index, rows - 1)), false)
                    .frame(maxWidth: .infinity)
                    .frame(height: cellSize)
            }
        }
        .offset(y: offsets.indices.contains(reel) ? offsets[reel] : 0)
        .blur(radius: stopped ? 0 : 2.4)
    }

    private func staticColumn(_ reel: Int) -> some View {
        let source = overrideColumns ?? settledColumns
        return VStack(spacing: spacing) {
            ForEach(0..<rows, id: \.self) { row in
                if source.indices.contains(reel), source[reel].indices.contains(row) {
                    let position = GridPosition(reel: reel, row: row)
                    cell(source[reel][row], position, highlighted.contains(position))
                        .frame(maxWidth: .infinity)
                        .frame(height: cellSize)
                } else {
                    Color.clear.frame(maxWidth: .infinity).frame(height: cellSize)
                }
            }
        }
    }

    // MARK: - Spin driver

    private func startSpin() {
        guard !columns.isEmpty else {
            onFinished()
            return
        }
        let previous = settledColumns.count == columns.count ? settledColumns : columns
        var newStrips: [[Item]] = []
        var targets: [CGFloat] = []
        for reel in columns.indices {
            let fillerCount = 12 + reel * 3 + (anticipationReels.contains(reel) ? 9 : 0)
            var strip = previous[reel]
            for _ in 0..<fillerCount {
                strip.append(filler())
            }
            strip += columns[reel]
            newStrips.append(strip)
            targets.append(CGFloat(previous[reel].count + fillerCount) * step)
        }
        strips = newStrips
        offsets = Array(repeating: 0, count: columns.count)
        stoppedFlags = Array(repeating: false, count: columns.count)
        bounce = Array(repeating: 0, count: columns.count)
        spinning = true
        glowPhase = false
        withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) {
            glowPhase = true
        }

        let token = spinID
        for reel in columns.indices {
            let duration = reel < reelDurations.count ? reelDurations[reel] : 1.0
            withAnimation(.timingCurve(0.12, 0.82, 0.24, 1.0, duration: duration)) {
                offsets[reel] = -targets[reel]
            }
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
                guard token == spinID, spinning else { return }
                withAnimation(.easeOut(duration: 0.15)) {
                    stoppedFlags[reel] = true
                }
                onReelStop(reel)
                bounce[reel] = 3.5
                withAnimation(.spring(response: 0.26, dampingFraction: 0.55)) {
                    bounce[reel] = 0
                }
                if stoppedFlags.allSatisfy({ $0 }) {
                    spinning = false
                    settledColumns = columns
                    strips = []
                    onFinished()
                }
            }
        }
    }
}

import QuartzCore
import SwiftUI
import UIKit

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
    let quickStopToken: Int
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
                            let anticipating = spinning && (anticipateFrom.map { reel >= $0 } ?? false)
                            ReelHost(
                                target: rows,
                                pool: pool,
                                reelIndex: reel,
                                spinning: spinning,
                                spinID: spinID,
                                turbo: turbo,
                                quickStopToken: quickStopToken,
                                anticipate: anticipating,
                                forcedSymbol: forcedReels[reel],
                                onStopped: { onReelStop(reel) }
                            )
                            .frame(width: cellW, height: cellH * 3)
                            .overlay {
                                if !spinning {
                                    VStack(spacing: 0) {
                                        ForEach(0..<3, id: \.self) { row in
                                            RoundedRectangle(cornerRadius: 3)
                                                .stroke(
                                                    highlighted.contains(GridPosition(reel: reel, row: row))
                                                        ? Color(red: 1, green: 0.78, blue: 0.1) : Color.clear,
                                                    lineWidth: 3
                                                )
                                                .frame(maxHeight: .infinity)
                                        }
                                    }
                                    .allowsHitTesting(false)
                                }
                            }
                            .overlay {
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(anticipating ? Color(red: 1, green: 0.82, blue: 0.2) : Color.clear, lineWidth: 3)
                                    .shadow(color: anticipating ? Color.yellow.opacity(0.8) : .clear, radius: 6)
                                    .allowsHitTesting(false)
                            }
                        }
                    }
                    if !spinning {
                        WinLineLayer(lines: winLines, cellW: cellW, cellH: cellH, gap: gap)
                            .allowsHitTesting(false)
                    }
                }
            }
            LineMarkers(count: lines.count, winning: Set(winLines.map(\.lineIndex)), side: .trailing)
        }
    }
}

/// UIKit reel. A display link moves prebuilt image layers; SwiftUI is not
/// invalidated on every frame.
private struct ReelHost: UIViewRepresentable {
    let target: [String]
    let pool: [String]
    let reelIndex: Int
    let spinning: Bool
    let spinID: Int
    let turbo: Bool
    let quickStopToken: Int
    let anticipate: Bool
    let forcedSymbol: String?
    let onStopped: () -> Void

    func makeUIView(context: Context) -> ReelStripUIView {
        let view = ReelStripUIView()
        view.onStopped = onStopped
        view.show(symbols: forcedSymbol.map { [$0, $0, $0] } ?? target)
        return view
    }

    func updateUIView(_ uiView: ReelStripUIView, context: Context) {
        uiView.onStopped = onStopped
        uiView.pool = pool.isEmpty ? ["cherry"] : pool
        uiView.turbo = turbo
        uiView.anticipate = anticipate
        uiView.reelIndex = reelIndex
        if spinning, uiView.appliedSpin != spinID {
            uiView.appliedSpin = spinID
            uiView.startSpin(target: target)
        }
        if uiView.seenQuick != quickStopToken {
            uiView.seenQuick = quickStopToken
            if quickStopToken > 0, uiView.isAnimating {
                uiView.quickStop()
            }
        }
        if !spinning, !uiView.isAnimating {
            uiView.show(symbols: forcedSymbol.map { [$0, $0, $0] } ?? target)
        }
    }

    static func dismantleUIView(_ uiView: ReelStripUIView, coordinator: ()) {
        uiView.halt()
    }
}

private final class ReelPump: NSObject {
    weak var view: ReelStripUIView?
    @objc func tick(_ link: CADisplayLink) {
        view?.tick(link)
    }
}

private final class ReelStripUIView: UIView {
    var onStopped: (() -> Void)?
    var pool: [String] = ["cherry"]
    var turbo = false
    var anticipate = false
    var reelIndex = 0
    var appliedSpin = -1
    var seenQuick = 0
    private(set) var isAnimating = false

    private var strip: [String] = ["cherry", "lemon", "plum"]
    private var symbolLayers: [CALayer] = []
    private var scroll: CGFloat = 0
    private var plan: ReelMotion?
    private var quick: ReelQuickStop?
    private var spinStartedAt: CFTimeInterval = 0
    private var quickStartedAt: CFTimeInterval = 0
    private var finished = false
    private var lastSpeed: CGFloat = 0
    private var link: CADisplayLink?
    private let pump = ReelPump()
    private var shownKey = ""

    override init(frame: CGRect) {
        super.init(frame: frame)
        clipsToBounds = true
        backgroundColor = .white
        isOpaque = true
        pump.view = self
    }

    required init?(coder: NSCoder) { nil }

    func halt() {
        link?.invalidate()
        link = nil
        isAnimating = false
    }

    deinit { halt() }

    func show(symbols: [String]) {
        guard !isAnimating else { return }
        let rows = symbols.count >= 3 ? Array(symbols.prefix(3)) : symbols + Array(repeating: "cherry", count: 3)
        let key = rows.joined(separator: "|")
        if key == shownKey, !symbolLayers.isEmpty { return }
        shownKey = key
        strip = rows
        scroll = 0
        rebuildLayers()
        positionLayers(speed: 0)
    }

    func startSpin(target: [String]) {
        halt()
        finished = false
        quick = nil
        let motion = ReelMotion.make(reel: reelIndex, turbo: turbo, anticipate: anticipate, uiTest: LaunchFlags.uiTest)
        plan = motion
        let travel = Int(motion.travel)
        let resting = strip.count >= 3 ? Array(strip.prefix(3)) : ["cherry", "lemon", "plum"]
        let landing = 1 + travel
        var band = Array(repeating: pool.first ?? "cherry", count: landing + 6)
        band[0] = pool.randomElement() ?? "cherry"
        band[1] = resting[0]
        band[2] = resting[1]
        band[3] = resting[2]
        if landing + 2 < band.count {
            band[landing] = target.count > 0 ? target[0] : "cherry"
            band[landing + 1] = target.count > 1 ? target[1] : "cherry"
            band[landing + 2] = target.count > 2 ? target[2] : "cherry"
        }
        for index in band.indices where !(index == 1 || index == 2 || index == 3 || index == landing || index == landing + 1 || index == landing + 2) {
            band[index] = pool.randomElement() ?? "cherry"
        }
        strip = band
        scroll = 1
        shownKey = ""
        rebuildLayers()
        isAnimating = true
        spinStartedAt = CACurrentMediaTime()
        let display = CADisplayLink(target: pump, selector: #selector(ReelPump.tick(_:)))
        display.preferredFrameRateRange = CAFrameRateRange(minimum: 60, maximum: 120, preferred: 120)
        display.add(to: .main, forMode: .common)
        link = display
        positionLayers(speed: 0)
    }

    func quickStop() {
        guard isAnimating, quick == nil, let plan else { return }
        let elapsed = CACurrentMediaTime() - spinStartedAt
        let current = plan.sample(elapsed).pos
        quick = plan.quickStop(from: current, turbo: turbo)
        quickStartedAt = CACurrentMediaTime()
    }

    func tick(_ link: CADisplayLink) {
        guard isAnimating, let plan else { return }
        let sample: (pos: CGFloat, speed: CGFloat)
        let done: Bool
        if let quick {
            let elapsed = link.timestamp - quickStartedAt
            sample = quick.sample(elapsed)
            done = elapsed >= quick.duration
        } else {
            let elapsed = link.timestamp - spinStartedAt
            sample = plan.sample(elapsed)
            done = elapsed >= plan.duration
        }
        scroll = 1 + sample.pos
        lastSpeed = sample.speed
        positionLayers(speed: sample.speed)
        if done { finish() }
    }

    private func finish() {
        guard !finished else { return }
        finished = true
        isAnimating = false
        link?.invalidate()
        link = nil
        if let plan {
            scroll = 1 + plan.travel
            let index = Int(plan.travel) + 1
            if index >= 0, index + 2 < strip.count {
                strip = [strip[index], strip[index + 1], strip[index + 2]]
                scroll = 0
                rebuildLayers()
            }
        }
        positionLayers(speed: 0)
        onStopped?()
    }

    private func rebuildLayers() {
        symbolLayers.forEach { $0.removeFromSuperlayer() }
        symbolLayers = strip.map { symbol in
            let layer = CALayer()
            layer.contents = SymbolImageCache.image(for: symbol).cgImage
            layer.contentsGravity = .resizeAspect
            layer.backgroundColor = UIColor.white.cgColor
            layer.masksToBounds = true
            layer.isOpaque = true
            self.layer.addSublayer(layer)
            return layer
        }
    }

    private func positionLayers(speed: CGFloat) {
        let cell = bounds.height > 1 ? bounds.height / 3 : 40
        let width = bounds.width
        let stretch = 1 + min(0.9, abs(speed) / 18)
        for (index, layer) in symbolLayers.enumerated() {
            let y = (CGFloat(index) - scroll) * cell
            layer.bounds = CGRect(x: 0, y: 0, width: max(1, width - 2), height: max(1, cell - 1))
            layer.position = CGPoint(x: width / 2, y: y + cell / 2)
            layer.transform = CATransform3DMakeScale(1, stretch, 1)
            layer.isHidden = y < -cell * 1.6 || y > bounds.height + cell * 0.6
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        positionLayers(speed: isAnimating ? lastSpeed : 0)
    }
}

private enum SymbolImageCache {
    private static var cache: [String: UIImage] = [:]

    static func image(for symbol: String) -> UIImage {
        if let cached = cache[symbol] { return cached }
        let image = UIImage(named: "sym-\(symbol)") ?? UIImage()
        cache[symbol] = image
        return image
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

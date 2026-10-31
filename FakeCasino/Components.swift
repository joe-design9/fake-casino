import SwiftUI
import UIKit

// MARK: - Haptics

enum Haptics {
    static func reelStop() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    static func tap() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    static func win(big: Bool) {
        UINotificationFeedbackGenerator().notificationOccurred(big ? .success : .warning)
    }
}

// MARK: - Liquid Glass helpers

private struct GlassPanelModifier: ViewModifier {
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            return AnyView(
                content.glassEffect(.regular, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            )
        }
        return AnyView(
            content.background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        )
    }
}

extension View {
    /// Frosted Liquid Glass panel (falls back to ultra-thin material on older systems).
    func glassPanel(cornerRadius: CGFloat = 20) -> some View {
        modifier(GlassPanelModifier(cornerRadius: cornerRadius))
    }
}

// MARK: - Brand & money

/// Small elegant play-money badge (replaces the giant v1 pill).
struct PlayMoneyBadge: View {
    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: "info.circle.fill")
                .font(.system(size: 10, weight: .semibold))
            Text("NUR SPIELGELD · KEIN ECHTGELD")
                .font(.system(size: 10, weight: .semibold))
                .tracking(1.1)
        }
        .foregroundStyle(Color(red: 0.98, green: 0.85, blue: 0.55))
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            Capsule()
                .fill(Color(red: 0.85, green: 0.62, blue: 0.15).opacity(0.16))
                .overlay(Capsule().strokeBorder(Color(red: 0.98, green: 0.85, blue: 0.55).opacity(0.45), lineWidth: 0.75))
        )
    }
}

/// Glossy gold coin with an embossed star (matches the app icon).
struct CoinIcon: View {
    var size: CGFloat = 22

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color(red: 1.0, green: 0.88, blue: 0.45), Color(red: 0.92, green: 0.62, blue: 0.12)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            Circle()
                .strokeBorder(Color(red: 0.72, green: 0.45, blue: 0.05), lineWidth: max(1, size * 0.07))
                .padding(size * 0.14)
            Image(systemName: "star.fill")
                .font(.system(size: size * 0.38, weight: .bold))
                .foregroundStyle(Color(red: 0.62, green: 0.38, blue: 0.03))
        }
        .frame(width: size, height: size)
    }
}

/// Balance display with animated number transitions.
struct BalancePill: View {
    @EnvironmentObject private var wallet: WalletStore

    var body: some View {
        HStack(spacing: 7) {
            CoinIcon(size: 22)
            Text(wallet.balance.grouped)
                .font(.system(.subheadline, design: .default).weight(.bold))
                .monospacedDigit()
                .contentTransition(.numericText())
                .animation(.easeOut(duration: 0.45), value: wallet.balance)
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .glassPanel(cornerRadius: 20)
    }
}

// MARK: - Background

/// Deep near-black violet casino backdrop. Always full-bleed:
/// place inside a ZStack and it ignores the safe area on all sides,
/// while sibling content keeps its normal safe-area insets.
struct CasinoBackground: View {
    var body: some View {
        ZStack {
            Color(red: 0.045, green: 0.03, blue: 0.09)
            LinearGradient(
                colors: [
                    Color(red: 0.10, green: 0.05, blue: 0.22),
                    Color(red: 0.05, green: 0.03, blue: 0.10),
                    Color(red: 0.02, green: 0.06, blue: 0.10)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            RadialGradient(
                colors: [Color(red: 0.45, green: 0.20, blue: 0.75).opacity(0.28), .clear],
                center: .top,
                startRadius: 10,
                endRadius: 420
            )
            RadialGradient(
                colors: [Color(red: 0.85, green: 0.62, blue: 0.15).opacity(0.10), .clear],
                center: .bottomLeading,
                startRadius: 10,
                endRadius: 380
            )
        }
        .ignoresSafeArea()
    }
}

// MARK: - Counting number

/// Text that counts up (or down) to a target value whenever it changes.
struct CountUpText: View {
    let value: Int
    var font: Font = .system(.title3, design: .default).weight(.bold)
    var color: Color = .white

    @State private var displayed: Int = 0
    @State private var taskID = 0

    var body: some View {
        Text(displayed.grouped)
            .font(font)
            .monospacedDigit()
            .foregroundStyle(color)
            .onAppear { run(to: value) }
            .onChange(of: value) { _, newValue in run(to: newValue) }
    }

    private func run(to target: Int) {
        taskID += 1
        let token = taskID
        let start = displayed
        guard start != target else { return }
        Task { @MainActor in
            let steps = 22
            for step in 1...steps {
                if token != taskID { return }
                displayed = start + (target - start) * step / steps
                try? await Task.sleep(nanoseconds: 24_000_000)
            }
            if token == taskID { displayed = target }
        }
    }
}

// MARK: - Win celebration

enum WinTier: Equatable {
    case big
    case mega

    var title: String {
        switch self {
        case .big: return "BIG WIN"
        case .mega: return "MEGA WIN"
        }
    }

    static func tier(win: Int, totalBet: Int) -> WinTier? {
        guard totalBet > 0, win > 0 else { return nil }
        let ratio = win / totalBet
        if ratio >= 25 { return .mega }
        if ratio >= 10 { return .big }
        return nil
    }
}

/// Full-screen win celebration overlay. Tap anywhere to dismiss.
struct BigWinOverlay: View {
    let tier: WinTier
    let amount: Int
    let onDismiss: () -> Void

    @State private var shown = false
    @State private var rayRotation: Double = 0

    var body: some View {
        ZStack {
            Color.black.opacity(0.62)
                .ignoresSafeArea()
                .onTapGesture(perform: onDismiss)

            StarburstShape(spikes: 12)
                .fill(
                    RadialGradient(
                        colors: [Color(red: 1.0, green: 0.85, blue: 0.35).opacity(0.30), .clear],
                        center: .center,
                        startRadius: 10,
                        endRadius: 260
                    )
                )
                .frame(width: 520, height: 520)
                .rotationEffect(.degrees(rayRotation))

            VStack(spacing: 14) {
                Text(tier.title)
                    .font(.system(size: tier == .mega ? 52 : 44, weight: .black))
                    .tracking(1.5)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color(red: 1.0, green: 0.92, blue: 0.55), Color(red: 0.95, green: 0.68, blue: 0.16)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .shadow(color: Color(red: 0.95, green: 0.68, blue: 0.16).opacity(0.65), radius: 18)
                HStack(spacing: 10) {
                    CoinIcon(size: 34)
                    CountUpText(
                        value: amount,
                        font: .system(size: 40, weight: .black),
                        color: .white
                    )
                }
                Text("Tippen zum Fortfahren")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.65))
                    .padding(.top, 6)
            }
            .scaleEffect(shown ? 1.0 : 0.7)
            .opacity(shown ? 1.0 : 0)
        }
        .onAppear {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.62)) { shown = true }
            withAnimation(.linear(duration: 24).repeatForever(autoreverses: false)) {
                rayRotation = 360
            }
        }
        .onTapGesture(perform: onDismiss)
    }
}

private struct StarburstShape: Shape {
    let spikes: Int

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let outer = min(rect.width, rect.height) / 2
        let inner = outer * 0.62
        for i in 0..<(spikes * 2) {
            let radius = i.isMultiple(of: 2) ? outer : inner
            let angle = Double(i) * .pi / Double(spikes) - .pi / 2
            let point = CGPoint(
                x: center.x + radius * cos(angle),
                y: center.y + radius * sin(angle)
            )
            if i == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        path.closeSubpath()
        return path
    }
}

// MARK: - Controls

/// Premium gold spin button.
struct SpinButton: View {
    let title: String
    let enabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(.headline, design: .default).weight(.black))
                .tracking(1.6)
                .foregroundStyle(Color(red: 0.22, green: 0.13, blue: 0.01))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    Capsule().fill(
                        LinearGradient(
                            colors: [
                                Color(red: 1.0, green: 0.90, blue: 0.50),
                                Color(red: 0.96, green: 0.70, blue: 0.18),
                                Color(red: 0.88, green: 0.58, blue: 0.10)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                )
                .shadow(color: Color(red: 0.95, green: 0.68, blue: 0.16).opacity(enabled ? 0.45 : 0.0), radius: 16, y: 6)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1.0 : 0.55)
    }
}

/// Bet selector (+ / -) shared by all machines.
struct BetSelector: View {
    let betPerLine: Int
    let totalBet: Int
    let locked: Bool
    let onDecrease: () -> Void
    let onIncrease: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Einsatz / Linie")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.65))
                Text("\(betPerLine) Coins")
                    .font(.system(.subheadline, design: .default).weight(.bold))
                    .foregroundStyle(.white)
            }
            Spacer()
            stepButton(systemName: "minus", disabled: locked, action: onDecrease)
            stepButton(systemName: "plus", disabled: locked, action: onIncrease)
            VStack(alignment: .trailing, spacing: 2) {
                Text("Gesamt")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.65))
                Text("\(totalBet.grouped)")
                    .font(.system(.subheadline, design: .default).weight(.bold))
                    .foregroundStyle(.white)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .glassPanel(cornerRadius: 18)
    }

    private func stepButton(systemName: String, disabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 38, height: 38)
                .background(Circle().fill(Color.white.opacity(0.12)))
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled ? 0.45 : 1.0)
    }
}

/// Free refill button, shown when the balance is nearly empty.
struct RefillButton: View {
    @EnvironmentObject private var wallet: WalletStore

    var body: some View {
        if wallet.needsRefill {
            Button {
                wallet.refill()
            } label: {
                Label("Gratis-Refill: +\(WalletStore.refillAmount.grouped) Coins", systemImage: "gift.fill")
                    .font(.system(.subheadline, design: .default).weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(Color(red: 0.16, green: 0.62, blue: 0.34)))
            }
            .buttonStyle(.plain)
        }
    }
}

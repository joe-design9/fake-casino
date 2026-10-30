import SwiftUI

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

// MARK: - Shared building blocks

/// Small gold play-money coin with an "M".
struct CoinIcon: View {
    var size: CGFloat = 22

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color(red: 1.0, green: 0.85, blue: 0.35), Color(red: 0.95, green: 0.65, blue: 0.15)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            Circle()
                .strokeBorder(Color.white.opacity(0.5), lineWidth: 1)
            Text("M")
                .font(.system(size: size * 0.55, weight: .black, design: .rounded))
                .foregroundStyle(Color(red: 0.45, green: 0.28, blue: 0.02))
        }
        .frame(width: size, height: size)
    }
}

/// Balance display shown on every screen.
struct BalancePill: View {
    @EnvironmentObject private var wallet: WalletStore

    var body: some View {
        HStack(spacing: 8) {
            CoinIcon(size: 24)
            Text(wallet.balance.grouped)
                .font(.system(.headline, design: .rounded).weight(.bold))
                .monospacedDigit()
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .glassPanel(cornerRadius: 24)
    }
}

/// Dark violet "vice" gradient backdrop with soft light blobs.
struct CasinoBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.09, green: 0.02, blue: 0.22),
                    Color(red: 0.24, green: 0.05, blue: 0.36),
                    Color(red: 0.02, green: 0.15, blue: 0.22)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Circle()
                .fill(Color.pink.opacity(0.35))
                .frame(width: 300, height: 300)
                .blur(radius: 90)
                .offset(x: -120, y: -280)
            Circle()
                .fill(Color.cyan.opacity(0.30))
                .frame(width: 280, height: 280)
                .blur(radius: 90)
                .offset(x: 130, y: 260)
            Circle()
                .fill(Color.orange.opacity(0.22))
                .frame(width: 200, height: 200)
                .blur(radius: 80)
                .offset(x: 150, y: -160)
        }
        .ignoresSafeArea()
    }
}

/// Big glass spin button used by all slot machines.
struct SpinButton: View {
    let title: String
    let enabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(.title3, design: .rounded).weight(.black))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    Capsule().fill(
                        LinearGradient(
                            colors: [Color.pink, Color.orange],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                )
                .shadow(color: Color.pink.opacity(enabled ? 0.55 : 0.0), radius: 14, y: 6)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1.0 : 0.55)
    }
}

/// Bet-per-line selector (+ / -) shared by all machines.
struct BetSelector: View {
    let betPerLine: Int
    let totalBet: Int
    let locked: Bool
    let onDecrease: () -> Void
    let onIncrease: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Einsatz pro Linie")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
                Text("\(betPerLine) Coins")
                    .font(.system(.headline, design: .rounded).weight(.bold))
                    .foregroundStyle(.white)
            }
            Spacer()
            Button(action: onDecrease) {
                Image(systemName: "minus")
                    .font(.headline)
                    .frame(width: 38, height: 38)
            }
            .buttonStyle(.plain)
            .glassPanel(cornerRadius: 19)
            .disabled(locked || betPerLine <= 1)
            Button(action: onIncrease) {
                Image(systemName: "plus")
                    .font(.headline)
                    .frame(width: 38, height: 38)
            }
            .buttonStyle(.plain)
            .glassPanel(cornerRadius: 19)
            .disabled(locked)
            VStack(alignment: .trailing, spacing: 2) {
                Text("Gesamt")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
                Text("\(totalBet)")
                    .font(.system(.headline, design: .rounded).weight(.bold))
                    .foregroundStyle(.white)
            }
        }
        .padding()
        .glassPanel()
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
                    .font(.system(.subheadline, design: .rounded).weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(Color.green.opacity(0.75)))
            }
            .buttonStyle(.plain)
        }
    }
}

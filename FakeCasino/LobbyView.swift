import SwiftUI

enum CasinoTab {
    case lobby
    case book
    case vice
    case mochi
}

/// App root: glass tab bar with lobby + the three machines.
struct RootView: View {
    @State private var selection: CasinoTab = .lobby

    var body: some View {
        TabView(selection: $selection) {
            LobbyView(goTo: { selection = $0 })
                .tabItem { Label("Casino", systemImage: "house.fill") }
                .tag(CasinoTab.lobby)

            BookOfMuseView()
                .tabItem { Label("Book of Muse", systemImage: "book.fill") }
                .tag(CasinoTab.book)

            ViceFruitsView()
                .tabItem { Label("Vice Fruits", systemImage: "leaf.fill") }
                .tag(CasinoTab.vice)

            MochiMillionsView()
                .tabItem { Label("Mochi", systemImage: "teddybear.fill") }
                .tag(CasinoTab.mochi)
        }
        .tint(.pink)
    }
}

struct LobbyView: View {
    @EnvironmentObject private var wallet: WalletStore
    let goTo: (CasinoTab) -> Void

    var body: some View {
        ZStack {
            CasinoBackground()
            ScrollView {
                VStack(spacing: 20) {
                    header
                    balanceCard
                    statsRow
                    gamesSection
                    footerNote
                }
                .padding(.horizontal)
                .padding(.top, 10)
                .padding(.bottom, 28)
            }
        }
    }

    // MARK: - Sections

    private var header: some View {
        VStack(spacing: 10) {
            Text("MUSE CASINO")
                .font(.system(size: 38, weight: .black, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.white, Color(red: 1.0, green: 0.75, blue: 0.85)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            Text("NUR SPIELGELD – KEIN ECHTGELD")
                .font(.system(.caption, design: .rounded).weight(.black))
                .tracking(1.2)
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(Capsule().fill(Color.orange.opacity(0.8)))
        }
        .padding(.top, 6)
    }

    private var balanceCard: some View {
        VStack(spacing: 14) {
            Text("Dein Spielgeld-Guthaben")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.75))
            HStack(spacing: 10) {
                CoinIcon(size: 34)
                Text(wallet.balance.grouped)
                    .font(.system(size: 34, weight: .black, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white)
            }
            HStack(spacing: 10) {
                Button {
                    wallet.claimDailyBonus()
                } label: {
                    Label(
                        wallet.canClaimDailyBonus
                            ? "Tagesbonus +\(WalletStore.dailyBonusAmount.grouped)"
                            : "Bonus morgen wieder da",
                        systemImage: "gift.fill"
                    )
                    .font(.system(.subheadline, design: .rounded).weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(Color.purple.opacity(wallet.canClaimDailyBonus ? 0.85 : 0.35)))
                }
                .buttonStyle(.plain)
                .disabled(!wallet.canClaimDailyBonus)

                RefillButton()
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .padding(.horizontal, 16)
        .glassPanel()
    }

    private var statsRow: some View {
        GlassEffectContainer(spacing: 10) {
            HStack(spacing: 10) {
                statChip(title: "Drehungen gesamt", value: "\(wallet.totalSpins)")
                statChip(title: "Größter Gewinn", value: wallet.biggestWin.grouped)
            }
        }
    }

    private func statChip(title: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(.title3, design: .rounded).weight(.black))
                .monospacedDigit()
                .foregroundStyle(.white)
            Text(title)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .glassPanel(cornerRadius: 16)
    }

    private var gamesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Spielautomaten")
                .font(.system(.title3, design: .rounded).weight(.black))
                .foregroundStyle(.white)

            gameCard(
                tab: .book,
                icon: "book.fill",
                color: .orange,
                title: "Book of Muse",
                subtitle: "5 Walzen · 10 Linien · Freispiele mit Expandier-Symbol"
            )
            gameCard(
                tab: .vice,
                icon: "leaf.fill",
                color: .green,
                title: "Vice Fruits",
                subtitle: "5 Walzen · 10 Linien · der fruchtige Klassiker"
            )
            gameCard(
                tab: .mochi,
                icon: "teddybear.fill",
                color: .pink,
                title: "Mochi Millions",
                subtitle: "3 Walzen · 5 Linien · Plüsch, Juwelen & Münzen"
            )
        }
    }

    private func gameCard(tab: CasinoTab, icon: String, color: Color, title: String, subtitle: String) -> some View {
        Button {
            goTo(tab)
        } label: {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundStyle(.white)
                    .frame(width: 52, height: 52)
                    .background(Circle().fill(color.opacity(0.75)))
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(.headline, design: .rounded).weight(.black))
                        .foregroundStyle(.white)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.75))
                        .multilineTextAlignment(.leading)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white.opacity(0.6))
            }
            .padding(16)
            .glassPanel()
        }
        .buttonStyle(.plain)
    }

    private var footerNote: some View {
        Text("Muse Casino ist ein reines Unterhaltungsspiel mit Spielgeld. "
            + "Es gibt kein Echtgeld, keine Käufe, keine Auszahlungen und keine Verbindung zu echten Casinos.")
            .font(.caption)
            .foregroundStyle(.white.opacity(0.55))
            .multilineTextAlignment(.center)
            .padding(.horizontal, 8)
    }
}

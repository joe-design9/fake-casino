import SwiftUI

/// The single swappable wordmark string shown in the lobby header.
let casinoWordmark = "MUSE ROYAL CASINO"

// MARK: - Root

/// App root: exactly one navigation pattern — a NavigationStack with the
/// lobby as root and every game pushed full-screen. No tab bar anywhere.
struct RootView: View {
    var body: some View {
        NavigationStack {
            LobbyView()
                .navigationDestination(for: CasinoRoute.self) { route in
                    switch route {
                    case .book:
                        BookOfMuseView()
                    case .vice:
                        ViceFruitsView()
                    case .mochi:
                        MochiMillionsView()
                    case .generic(let id):
                        if let config = SlotCatalog.config(id: id) {
                            GenericSlotView(config: config)
                        }
                    }
                }
        }
        .tint(Color(red: 0.98, green: 0.82, blue: 0.35))
    }
}

// MARK: - Lobby

struct LobbyView: View {
    @EnvironmentObject private var wallet: WalletStore
    @State private var selectedCategory: MachineCategory?
    @State private var searchText = ""

    private let columns = [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14),
    ]

    private var visibleEntries: [LobbyEntry] {
        SlotCatalog.lobbyEntries.filter { entry in
            let categoryOK = selectedCategory == nil || entry.categories.contains(selectedCategory!)
            let searchOK = searchText.isEmpty
                || entry.name.localizedCaseInsensitiveContains(searchText)
                || entry.tagline.localizedCaseInsensitiveContains(searchText)
            return categoryOK && searchOK
        }
    }

    var body: some View {
        ZStack {
            CasinoBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    balanceCard
                    searchField
                    filterRow
                    slotsHeader
                    grid
                    footerNote
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 40)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    // MARK: Search

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white.opacity(0.45))
            TextField("Slot suchen", text: $searchText)
                .font(.subheadline)
                .foregroundStyle(.white)
                .autocorrectionDisabled()
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.white.opacity(0.45))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .glassPanel(cornerRadius: 12)
    }

    // MARK: Header

    private var header: some View {
        VStack(spacing: 8) {
            HStack(alignment: .center, spacing: 10) {
                CoinIcon(size: 30)
                Text(casinoWordmark)
                    .font(.system(size: 21, weight: .black))
                    .tracking(1.2)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color(red: 1.0, green: 0.90, blue: 0.55), Color(red: 0.85, green: 0.62, blue: 0.20)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Spacer()
                BalancePill()
            }
            HStack {
                PlayMoneyBadge()
                Spacer()
                Text("\(SlotCatalog.lobbyEntries.count) Automaten")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.55))
            }
        }
    }

    // MARK: Balance + stats card

    private var balanceCard: some View {
        VStack(spacing: 12) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("GUTHABEN")
                        .font(.caption2.weight(.bold))
                        .tracking(1.4)
                        .foregroundStyle(.white.opacity(0.55))
                    HStack(spacing: 7) {
                        CoinIcon(size: 26)
                        CountUpText(
                            value: wallet.balance,
                            font: .system(size: 30, weight: .black),
                            color: .white
                        )
                    }
                }
                Spacer()
                Button {
                    wallet.claimDailyBonus()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: wallet.canClaimDailyBonus ? "gift.fill" : "checkmark")
                            .font(.system(size: 13, weight: .bold))
                        Text(wallet.canClaimDailyBonus ? "Bonus +\(WalletStore.dailyBonusAmount.grouped)" : "Bonus geholt")
                            .font(.system(.subheadline, design: .default).weight(.bold))
                    }
                    .foregroundStyle(wallet.canClaimDailyBonus ? Color(red: 0.20, green: 0.12, blue: 0.01) : Color.white.opacity(0.55))
                    .padding(.horizontal, 13)
                    .padding(.vertical, 9)
                    .background(
                        Capsule().fill(
                            wallet.canClaimDailyBonus
                                ? AnyShapeStyle(LinearGradient(
                                    colors: [Color(red: 1.0, green: 0.88, blue: 0.45), Color(red: 0.90, green: 0.68, blue: 0.22)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                ))
                                : AnyShapeStyle(Color.white.opacity(0.12))
                        )
                    )
                }
                .buttonStyle(.plain)
                .disabled(!wallet.canClaimDailyBonus)
            }
            Divider().overlay(Color.white.opacity(0.14))
            HStack(spacing: 0) {
                statCell(title: "SPINS", value: wallet.totalSpins.grouped)
                statDivider
                statCell(title: "GRÖSSTER GEWINN", value: wallet.biggestWin.grouped)
                statDivider
                statCell(title: "TAGESBONUS", value: wallet.canClaimDailyBonus ? "+\(WalletStore.dailyBonusAmount.grouped)" : "Geholt")
            }
        }
        .padding(16)
        .glassPanel(cornerRadius: 20)
    }

    private func statCell(title: String, value: String) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(.headline, design: .default).weight(.bold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(title)
                .font(.system(size: 9, weight: .bold))
                .tracking(0.8)
                .foregroundStyle(.white.opacity(0.5))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
    }

    private var statDivider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.12))
            .frame(width: 1, height: 30)
    }

    // MARK: Filters

    private var filterRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                filterChip(title: "Alle", category: nil)
                filterChip(title: "Freispiele", category: .freispiele)
                filterChip(title: "Klassiker", category: .klassiker)
                filterChip(title: "Hochvolatil", category: .hochvolatil)
            }
            .padding(.vertical, 2)
        }
    }

    private func filterChip(title: String, category: MachineCategory?) -> some View {
        let isActive = selectedCategory == category
        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedCategory = category
            }
        } label: {
            Text(title)
                .font(.system(.subheadline, design: .default).weight(.semibold))
                .foregroundStyle(isActive ? Color(red: 0.20, green: 0.12, blue: 0.01) : Color.white.opacity(0.85))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    Capsule().fill(
                        isActive
                            ? AnyShapeStyle(LinearGradient(
                                colors: [Color(red: 1.0, green: 0.88, blue: 0.45), Color(red: 0.88, green: 0.66, blue: 0.20)],
                                startPoint: .top,
                                endPoint: .bottom
                            ))
                            : AnyShapeStyle(Color.white.opacity(0.10))
                    )
                )
                .overlay(
                    Capsule().strokeBorder(Color.white.opacity(isActive ? 0 : 0.14), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: Slots grid

    private var slotsHeader: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("Slots")
                .font(.system(.title3, design: .default).weight(.black))
                .foregroundStyle(.white)
            Spacer()
            Text("\(visibleEntries.count) von \(SlotCatalog.lobbyEntries.count)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.5))
        }
    }

    private var grid: some View {
        Group {
            if visibleEntries.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 26))
                        .foregroundStyle(.white.opacity(0.4))
                    Text("Kein Automat gefunden.")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.6))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 30)
            } else {
                LazyVGrid(columns: columns, spacing: 14) {
                    ForEach(visibleEntries) { entry in
                        NavigationLink(value: entry.route) {
                            SlotTileView(entry: entry)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var footerNote: some View {
        Text("Alle Automaten spielen ausschließlich mit Spielgeld. Keine Einzahlungen, keine Auszahlungen, keine Werbung.")
            .font(.caption)
            .foregroundStyle(.white.opacity(0.45))
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.top, 6)
    }
}

// MARK: - Slot tile

struct SlotTileView: View {
    let entry: LobbyEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack {
                PaletteArtwork(palette: entry.palette, glowOpacity: 0.55)
                SymbolArtView(art: entry.motif, tint: Color(hex: entry.motifTint), size: 52)
                    .shadow(color: .black.opacity(0.35), radius: 6, y: 3)
            }
            .frame(height: 96)
            .frame(maxWidth: .infinity)
            VStack(alignment: .leading, spacing: 3) {
                Text(entry.name)
                    .font(.system(.subheadline, design: .default).weight(.bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Text(entry.tagline)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.62))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 4) {
                    Text("SPIELEN")
                        .font(.system(size: 10, weight: .black))
                        .tracking(0.8)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 8, weight: .black))
                }
                .foregroundStyle(entry.palette.accentColor)
                .padding(.top, 4)
            }
            .padding(11)
        }
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.055))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

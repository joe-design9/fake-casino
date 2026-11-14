import SwiftUI

@main
struct GoldkroneApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}

struct RootView: View {
    @StateObject private var wallet = WalletStore.shared
    @State private var game: GameKind?
    @State private var showDisclaimer: Bool
    @State private var showStats = false
    private let shot = Screenshot.current

    init() {
        let shot = Screenshot.current
        _game = State(initialValue: shot?.game)
        _showDisclaimer = State(initialValue: shot == nil && !LaunchFlags.uiTest && !WalletStore.shared.disclaimerAccepted)
    }

    var body: some View {
        ZStack {
            ArcadeBackground()
            if let game {
                SlotGameView(game: game, shot: shot, onExit: {
                    if shot == nil { self.game = nil }
                })
                .id(game)
            } else {
                LobbyView(
                    onPlay: { game = $0 },
                    onStats: { showStats = true },
                    onHint: { showDisclaimer = true }
                )
            }
            if showStats {
                StatsPanel { showStats = false }
            }
            if showDisclaimer {
                DisclaimerView {
                    wallet.acceptDisclaimer()
                    showDisclaimer = false
                }
            }
        }
        .environmentObject(wallet)
        .preferredColorScheme(.dark)
        .tint(GK.gold)
    }
}

import Foundation

/// Central play-money wallet. Everything is persisted in UserDefaults.
/// This casino uses 100% play money ("Spielgeld") — no real money, no purchases.
final class WalletStore: ObservableObject {
    static let shared = WalletStore()

    private let balanceKey = "fakecasino.balance"
    private let spinsKey = "fakecasino.totalSpins"
    private let biggestWinKey = "fakecasino.biggestWin"
    private let bonusKey = "fakecasino.lastBonusDay"

    static let startBalance = 10_000
    static let dailyBonusAmount = 1_000
    static let refillAmount = 1_000
    static let refillThreshold = 10

    @Published var balance: Int {
        didSet { UserDefaults.standard.set(balance, forKey: balanceKey) }
    }
    @Published var totalSpins: Int {
        didSet { UserDefaults.standard.set(totalSpins, forKey: spinsKey) }
    }
    @Published var biggestWin: Int {
        didSet { UserDefaults.standard.set(biggestWin, forKey: biggestWinKey) }
    }
    @Published private(set) var lastBonusDay: String {
        didSet { UserDefaults.standard.set(lastBonusDay, forKey: bonusKey) }
    }

    init() {
        let defaults = UserDefaults.standard
        if defaults.object(forKey: balanceKey) == nil {
            self.balance = WalletStore.startBalance
        } else {
            self.balance = defaults.integer(forKey: balanceKey)
        }
        self.totalSpins = defaults.integer(forKey: spinsKey)
        self.biggestWin = defaults.integer(forKey: biggestWinKey)
        self.lastBonusDay = defaults.string(forKey: bonusKey) ?? ""
    }

    // MARK: - Daily bonus

    var canClaimDailyBonus: Bool {
        lastBonusDay != WalletStore.todayKey()
    }

    func claimDailyBonus() {
        guard canClaimDailyBonus else { return }
        balance += WalletStore.dailyBonusAmount
        lastBonusDay = WalletStore.todayKey()
    }

    // MARK: - Refill

    var needsRefill: Bool {
        balance < WalletStore.refillThreshold
    }

    /// Free refill so a broke player can keep playing with play money.
    func refill() {
        guard needsRefill else { return }
        balance += WalletStore.refillAmount
    }

    // MARK: - Betting & wins

    /// Deducts a bet. Returns false (and changes nothing) if the balance is too low.
    func placeBet(_ amount: Int) -> Bool {
        guard amount > 0, balance >= amount else { return false }
        balance -= amount
        return true
    }

    func recordSpin() {
        totalSpins += 1
    }

    func addWin(_ amount: Int) {
        guard amount > 0 else { return }
        balance += amount
        if amount > biggestWin {
            biggestWin = amount
        }
    }

    // MARK: - Helpers

    private static func todayKey() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
}

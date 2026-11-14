import Combine
import Foundation

struct GameRecord: Codable, Equatable {
    var spins: Int = 0
    var bet: Int = 0
    var won: Int = 0
    var biggest: Int = 0

    var rtp: Double {
        bet == 0 ? 0 : Double(won) / Double(bet)
    }
}

/// Play-money wallet. Kronentaler have no cash value and are never purchased.
/// Touched from the main thread by the SwiftUI views that own it.
final class WalletStore: ObservableObject {
    static let shared = WalletStore()

    static let startBalance = 5_000
    static let minimumBet = 10
    static let refillAmount = 2_000
    static let betSteps = [10, 20, 50, 100, 200, 500, 1_000]

    static func bonusAmount(forStreak streak: Int) -> Int {
        let day = min(max(streak, 1), 7)
        return 1_000 + (day - 1) * 200
    }

    private let defaults = UserDefaults.standard
    private let balanceKey = "goldkrone.balance"
    private let spinsKey = "goldkrone.spins"
    private let betKey = "goldkrone.totalBet"
    private let wonKey = "goldkrone.totalWon"
    private let biggestKey = "goldkrone.biggest"
    private let streakKey = "goldkrone.streak"
    private let bonusKey = "goldkrone.bonusStamp"
    private let recordsKey = "goldkrone.records"
    private let soundKey = "goldkrone.sound"
    private let hapticsKey = "goldkrone.haptics"
    private let disclaimerKey = "goldkrone.disclaimer"

    private let persist: Bool
    private var roundOpen = false

    @Published var balance: Int {
        didSet { store(balance, balanceKey) }
    }
    @Published var totalSpins: Int {
        didSet { store(totalSpins, spinsKey) }
    }
    @Published var totalBet: Int {
        didSet { store(totalBet, betKey) }
    }
    @Published var totalWon: Int {
        didSet { store(totalWon, wonKey) }
    }
    @Published var biggestWin: Int {
        didSet { store(biggestWin, biggestKey) }
    }
    @Published var streak: Int {
        didSet { store(streak, streakKey) }
    }
    @Published var lastBonusStamp: Int {
        didSet { store(lastBonusStamp, bonusKey) }
    }
    @Published var records: [String: GameRecord] {
        didSet { saveRecords() }
    }
    @Published var soundOn: Bool {
        didSet { if persist { defaults.set(soundOn, forKey: soundKey) } }
    }
    @Published var hapticsOn: Bool {
        didSet { if persist { defaults.set(hapticsOn, forKey: hapticsKey) } }
    }
    @Published var disclaimerAccepted: Bool {
        didSet { if persist { defaults.set(disclaimerAccepted, forKey: disclaimerKey) } }
    }

    var overallRTP: Double {
        totalBet == 0 ? 0 : Double(totalWon) / Double(totalBet)
    }

    var canClaimDailyBonus: Bool {
        lastBonusStamp != Self.dayStamp(Date())
    }

    var canRefill: Bool {
        balance < Self.minimumBet
    }

    /// Amount the next claim will pay, including the streak step.
    var upcomingBonus: Int {
        Self.bonusAmount(forStreak: previewStreak)
    }

    private var previewStreak: Int {
        let today = Self.dayStamp(Date())
        if lastBonusStamp == today { return max(streak, 1) }
        if lastBonusStamp == Self.dayStamp(Self.yesterday) { return min(streak + 1, 7) }
        return 1
    }

    private init() {
        let shot = Screenshot.current
        persist = shot == nil
        if let shot {
            balance = shot == .lobby ? Self.startBalance : 8_400
            totalSpins = shot == .lobby ? 0 : 42
            totalBet = shot == .lobby ? 0 : 4_200
            totalWon = shot == .lobby ? 0 : 3_900
            biggestWin = shot == .lobby ? 0 : 2_400
            streak = shot == .lobby ? 0 : 3
            lastBonusStamp = 0
            records = [:]
            soundOn = true
            hapticsOn = true
            disclaimerAccepted = true
            return
        }

        if defaults.object(forKey: balanceKey) == nil {
            balance = Self.startBalance
        } else {
            balance = defaults.integer(forKey: balanceKey)
        }
        totalSpins = defaults.integer(forKey: spinsKey)
        totalBet = defaults.integer(forKey: betKey)
        totalWon = defaults.integer(forKey: wonKey)
        biggestWin = defaults.integer(forKey: biggestKey)
        streak = defaults.integer(forKey: streakKey)
        lastBonusStamp = defaults.integer(forKey: bonusKey)
        soundOn = defaults.object(forKey: soundKey) == nil ? true : defaults.bool(forKey: soundKey)
        hapticsOn = defaults.object(forKey: hapticsKey) == nil ? true : defaults.bool(forKey: hapticsKey)
        disclaimerAccepted = defaults.bool(forKey: disclaimerKey)
        if let data = defaults.data(forKey: recordsKey),
           let decoded = try? JSONDecoder().decode([String: GameRecord].self, from: data) {
            records = decoded
        } else {
            records = [:]
        }
    }

    func acceptDisclaimer() {
        disclaimerAccepted = true
    }

    @discardableResult
    func claimDailyBonus() -> Int {
        guard canClaimDailyBonus else { return 0 }
        let next = previewStreak
        streak = next
        let amount = Self.bonusAmount(forStreak: next)
        balance += amount
        lastBonusStamp = Self.dayStamp(Date())
        return amount
    }

    func refill() {
        guard canRefill else { return }
        balance += Self.refillAmount
    }

    func record(for game: GameKind) -> GameRecord {
        records[game.rawValue] ?? GameRecord()
    }

    /// Deducts the stake and counts the paid spin. Returns false when the balance is short.
    func beginRound(game: GameKind, bet: Int) -> Bool {
        guard bet > 0, balance >= bet else { return false }
        balance -= bet
        totalSpins += 1
        totalBet += bet
        var record = records[game.rawValue] ?? GameRecord()
        record.spins += 1
        record.bet += bet
        records[game.rawValue] = record
        roundOpen = true
        return true
    }

    /// Credits the collected win (after an optional gamble) exactly once per round.
    func finishRound(game: GameKind, win: Int) {
        guard roundOpen else { return }
        roundOpen = false
        let payout = max(0, win)
        if payout > 0 {
            balance += payout
            totalWon += payout
            if payout > biggestWin { biggestWin = payout }
        }
        var record = records[game.rawValue] ?? GameRecord()
        record.won += payout
        if payout > record.biggest { record.biggest = payout }
        records[game.rawValue] = record
    }

    private func store(_ value: Int, _ key: String) {
        if persist { defaults.set(value, forKey: key) }
    }

    private func saveRecords() {
        guard persist, let data = try? JSONEncoder().encode(records) else { return }
        defaults.set(data, forKey: recordsKey)
    }

    private static var yesterday: Date {
        Calendar(identifier: .gregorian).date(byAdding: .day, value: -1, to: Date()) ?? Date()
    }

    private static func dayStamp(_ date: Date) -> Int {
        let parts = Calendar(identifier: .gregorian).dateComponents([.year, .month, .day], from: date)
        return (parts.year ?? 0) * 10_000 + (parts.month ?? 0) * 100 + (parts.day ?? 0)
    }
}

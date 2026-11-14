import XCTest
@testable import Goldkrone

final class RTPSimulationTests: XCTestCase {
    func testFruchtfeuerKnownBellLine() {
        let grid = [
            ["cherry", "bell", "lemon"],
            ["lemon", "bell", "plum"],
            ["grape", "bell", "cherry"],
            ["plum", "melon", "bar"],
            ["lemon", "grape", "cherry"]
        ]
        let result = FruchtfeuerEngine.evaluate(grid: grid, totalBet: 100)
        XCTAssertEqual(result.lineWins.count, 1)
        XCTAssertEqual(result.lineWins[0].symbolID, "bell")
        XCTAssertEqual(result.lineWins[0].count, 3)
        XCTAssertEqual(result.total, 700)
    }

    func testSphinxThreeBooksPayScatterAndBestWild() {
        let grid = [
            ["book", "ten", "king"],
            ["queen", "book", "jack"],
            ["ten", "ace", "book"],
            ["jack", "queen", "ace"],
            ["ace", "king", "ten"]
        ]
        let result = SphinxEngine.evaluateBase(grid: grid, totalBet: 100)
        XCTAssertEqual(result.books, 3)
        XCTAssertEqual(result.scatterWin, 300)
        XCTAssertEqual(result.lineWins.count, 1)
        XCTAssertEqual(result.lineWins[0].symbolID, "pharaoh")
        XCTAssertEqual(result.lineWins[0].count, 3)
        XCTAssertEqual(result.total, 720)
    }

    func testJokerWildAndStars() {
        let grid = [
            ["star", "joker", "cherry"],
            ["grape", "seven", "star"],
            ["melon", "seven", "bell"],
            ["star", "bell", "grape"],
            ["cherry", "grape", "melon"]
        ]
        let result = JokerEngine.evaluate(grid: grid, totalBet: 100)
        XCTAssertEqual(result.stars, 3)
        XCTAssertEqual(result.scatterWin, 200)
        XCTAssertEqual(result.lineWins.count, 1)
        XCTAssertEqual(result.lineWins[0].symbolID, "seven")
        XCTAssertEqual(result.lineWins[0].amount, 400)
        XCTAssertEqual(result.total, 600)
    }

    func testSphinxRoundTotalsAddUp() {
        var rng = SeededGenerator(seed: 99)
        for _ in 0..<300 {
            let round = SphinxEngine.spin(totalBet: 100, rng: &rng)
            let parts = round.lineWins.reduce(0) { $0 + $1.amount }
                + round.scatterWin
                + round.freeSpins.reduce(0) { $0 + $1.totalWin }
            XCTAssertEqual(round.totalWin, parts)
            if round.scatterCount >= 3 {
                XCTAssertGreaterThanOrEqual(round.freeSpins.count, 10)
                XCTAssertLessThanOrEqual(round.freeSpins.count, SphinxEngine.freeSpinCap)
            } else {
                XCTAssertTrue(round.freeSpins.isEmpty)
            }
        }
    }

    func testLadderAndBonusMath() {
        XCTAssertEqual(LadderMath.amount(base: 700, level: 0), 700)
        XCTAssertEqual(LadderMath.amount(base: 700, level: 1), 1_400)
        XCTAssertEqual(LadderMath.amount(base: 700, level: 5), 22_400)
        XCTAssertEqual(WalletStore.bonusAmount(forStreak: 1), 1_000)
        XCTAssertEqual(WalletStore.bonusAmount(forStreak: 4), 1_600)
        XCTAssertEqual(WalletStore.bonusAmount(forStreak: 7), 2_200)
        XCTAssertEqual(WalletStore.bonusAmount(forStreak: 12), 2_200)
    }

    func testFruchtfeuerRTP() async {
        let report = await Task.detached(priority: .userInitiated) {
            RTPLab.simulate(game: .fruchtfeuer, spins: 1_000_000, seed: 0x4652_5543_4854)
        }.value
        reportLine("Fruchtfeuer", report)
        assertBand("Fruchtfeuer", report)
    }

    func testJokerSterneRTP() async {
        let report = await Task.detached(priority: .userInitiated) {
            RTPLab.simulate(game: .joker, spins: 1_000_000, seed: 0x4A4F_4B45_5200)
        }.value
        reportLine("Joker Sterne", report)
        assertBand("Joker Sterne", report)
    }

    func testBuchDerSphinxRTP() async {
        let report = await Task.detached(priority: .userInitiated) {
            RTPLab.simulate(game: .sphinx, spins: 2_000_000, seed: 0x5350_4849_4E58)
        }.value
        reportLine("Buch der Sphinx", report)
        assertBand("Buch der Sphinx", report)
    }

    private func reportLine(_ name: String, _ report: RTPLab.Report) {
        let line = String(
            format: "GOLDKRONE %@ RTP %.3f%%  Treffer %.2f%%  (%d Drehungen)",
            name, report.rtp * 100, report.hitRate * 100, report.spins
        )
        fputs(line + "\n", stderr)
    }

    private func assertBand(_ name: String, _ report: RTPLab.Report) {
        XCTAssertGreaterThanOrEqual(report.rtp, 0.93, "\(name) RTP \(report.rtp) unter 93%")
        XCTAssertLessThanOrEqual(report.rtp, 0.97, "\(name) RTP \(report.rtp) über 97%")
        XCTAssertGreaterThanOrEqual(report.hitRate, 0.25, "\(name) Trefferquote \(report.hitRate) unter 25%")
        XCTAssertLessThanOrEqual(report.hitRate, 0.35, "\(name) Trefferquote \(report.hitRate) über 35%")
    }
}

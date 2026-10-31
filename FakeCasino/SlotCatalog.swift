import Foundation

// MARK: - Lobby routing

enum CasinoRoute: Hashable {
    case book
    case vice
    case mochi
    case generic(String)
}

struct LobbyEntry: Identifiable {
    let route: CasinoRoute
    let name: String
    let tagline: String
    let palette: MachinePalette
    let motif: SymbolArt
    let motifTint: String
    let categories: Set<MachineCategory>

    var id: String { name }
}

// MARK: - Catalog builders

private enum RoyalTier {
    case low, mid, high
}

private func royals(_ tier: RoyalTier) -> [SlotSymbolConfig] {
    let a: [Int: Int], k: [Int: Int], q: [Int: Int], j: [Int: Int]
    let aw: Int, kw: Int, qw: Int, jw: Int
    switch tier {
    case .low:
        a = [3: 4, 4: 8, 5: 30]; k = [3: 4, 4: 8, 5: 30]
        q = [3: 3, 4: 6, 5: 20]; j = [3: 3, 4: 6, 5: 20]
        aw = 8; kw = 8; qw = 9; jw = 9
    case .mid:
        a = [3: 5, 4: 12, 5: 60]; k = [3: 5, 4: 12, 5: 60]
        q = [3: 4, 4: 8, 5: 40]; j = [3: 4, 4: 8, 5: 40]
        aw = 7; kw = 7; qw = 8; jw = 8
    case .high:
        a = [3: 6, 4: 16, 5: 90]; k = [3: 6, 4: 16, 5: 90]
        q = [3: 5, 4: 10, 5: 50]; j = [3: 5, 4: 10, 5: 50]
        aw = 7; kw = 7; qw = 8; jw = 8
    }
    return [
        SlotSymbolConfig(id: "A", name: "Ass", art: .letter("A"), tint: "#EFEAFB", weight: aw, pays: a),
        SlotSymbolConfig(id: "K", name: "König", art: .letter("K"), tint: "#EFEAFB", weight: kw, pays: k),
        SlotSymbolConfig(id: "Q", name: "Dame", art: .letter("Q"), tint: "#EFEAFB", weight: qw, pays: q),
        SlotSymbolConfig(id: "J", name: "Bube", art: .letter("J"), tint: "#EFEAFB", weight: jw, pays: j)
    ]
}

/// 5-reel themed symbol.
private func S(
    _ id: String, _ name: String, _ art: SymbolArt, _ tint: String,
    _ w: Int, _ p3: Int, _ p4: Int, _ p5: Int,
    wild: Bool = false, scatter: Bool = false
) -> SlotSymbolConfig {
    SlotSymbolConfig(
        id: id, name: name, art: art, tint: tint, weight: w,
        pays: [3: p3, 4: p4, 5: p5], isWild: wild, isScatter: scatter
    )
}

/// 3-reel classic symbol (three of a kind only).
private func C(
    _ id: String, _ name: String, _ art: SymbolArt, _ tint: String,
    _ w: Int, _ p3: Int, wild: Bool = false
) -> SlotSymbolConfig {
    SlotSymbolConfig(
        id: id, name: name, art: art, tint: tint, weight: w,
        pays: [3: p3], isWild: wild
    )
}

private func wild(_ p3: Int, _ p4: Int, _ p5: Int, art: SymbolArt = .letter("W"), name: String = "Wild") -> SlotSymbolConfig {
    S("wild", name, art, "#FFD94D", 2, p3, p4, p5, wild: true)
}

private func machine(
    id: String, name: String, tagline: String,
    reels: Int = 5, lines: Int = 10,
    palette: MachinePalette, motif: SymbolArt,
    categories: Set<MachineCategory> = [],
    symbols: [SlotSymbolConfig],
    scatterPays: [Int: Int] = [:],
    fs: Int = 0, fsMult: Int = 1,
    multChance: Double = 0, multMax: Int = 5
) -> SlotMachineConfig {
    SlotMachineConfig(
        id: id, name: name, tagline: tagline,
        reels: reels, lineCount: lines,
        symbols: symbols,
        scatterPays: scatterPays,
        freeSpinsAwarded: fs, freeSpinMultiplier: fsMult,
        randomMultiplierChance: multChance, randomMultiplierMax: multMax,
        palette: palette, motif: motif, categories: categories
    )
}

// MARK: - The 29 configurable machines

enum SlotCatalog {
    static let configs: [SlotMachineConfig] = [
        // ── Hero machines (hand-tuned) ─────────────────────────────

        machine(
            id: "leonida", name: "Leonida Nights",
            tagline: "Neon, Palmen & Wild-Symbol",
            palette: MachinePalette(["#2B0A3D", "#8A1453", "#0E4A5C"], accent: "#FF5DA2"),
            motif: .sf("bird.fill"),
            symbols: [
                wild(60, 250, 900, art: .sf("car.fill"), name: "Sportwagen (Wild)"),
                S("flamingo", "Flamingo", .sf("bird.fill"), "#FF7FB1", 3, 25, 100, 500),
                S("gem", "Neon-Juwel", .shape(.gem), "#39D5E8", 4, 15, 60, 250),
                S("sun", "Vice-Sonne", .sf("sun.max.fill"), "#FFB84D", 5, 10, 40, 150),
                S("coin", "Goldmünze", .shape(.coin), "#FFD94D", 6, 8, 30, 120)
            ] + royals(.mid)
        ),

        machine(
            id: "olympus", name: "Olympus Thunder",
            tagline: "Hohe Volatilität · Zufalls-Multiplikator bis 5×",
            palette: MachinePalette(["#0D1440", "#2C3E8F", "#6B4E12"], accent: "#FFD94D"),
            motif: .sf("bolt.fill"),
            categories: [.hochvolatil],
            symbols: [
                wild(80, 300, 1200, art: .sf("bolt.fill"), name: "Blitz (Wild)"),
                S("crown", "Zeus-Krone", .sf("crown.fill"), "#FFD94D", 3, 30, 120, 600),
                S("temple", "Tempel", .sf("building.columns.fill"), "#C9D4FF", 4, 20, 80, 350),
                S("laurel", "Lorbeer", .sf("leaf.fill"), "#7FE08A", 5, 12, 50, 200),
                S("sun", "Helios", .sf("sun.max.fill"), "#FFB84D", 6, 10, 35, 150)
            ] + royals(.high),
            multChance: 0.08, multMax: 5
        ),

        machine(
            id: "sugar", name: "Sugar Donuts",
            tagline: "Niedrige Volatilität · viele kleine Gewinne",
            palette: MachinePalette(["#3D1030", "#8F2A5C", "#C96A1E"], accent: "#FF9ECF"),
            motif: .shape(.donut),
            symbols: [
                SlotSymbolConfig(
                    id: "donut", name: "Donut", art: .shape(.donut), tint: "#FF9ECF",
                    weight: 5, pays: [2: 2, 3: 10, 4: 30, 5: 100]
                ),
                S("candy", "Bonbon", .shape(.candy), "#FF6B9D", 6, 6, 20, 70),
                S("lollipop", "Lolli", .shape(.lollipop), "#7FD8FF", 6, 5, 18, 60),
                S("heart", "Zuckerherz", .sf("heart.fill"), "#FF5D73", 7, 4, 14, 50),
                S("star", "Zuckerstern", .sf("star.fill"), "#FFD94D", 7, 4, 12, 45)
            ] + royals(.low)
        ),

        machine(
            id: "bandit", name: "Bandit Bounty",
            tagline: "Scatter startet 8 Freispiele mit 2×",
            palette: MachinePalette(["#2E1A08", "#7A4416", "#B07B2A"], accent: "#FFC46B"),
            motif: .shape(.horseshoe),
            categories: [.freispiele],
            symbols: [
                wild(50, 200, 800, art: .shape(.horseshoe), name: "Hufeisen (Wild)"),
                S("badge", "Sheriffstern", .sf("rosette"), "#FFD94D", 3, 0, 0, 0, scatter: true),
                S("flame", "Lagerfeuer", .sf("flame.fill"), "#FF8A3D", 4, 20, 80, 350),
                S("sun", "Prärie-Sonne", .sf("sun.max.fill"), "#FFB84D", 5, 12, 45, 180),
                S("coin", "Kopfgeld-Münze", .shape(.coin), "#FFD94D", 6, 8, 30, 120)
            ] + royals(.mid),
            scatterPays: [3: 2, 4: 8, 5: 25],
            fs: 8, fsMult: 2
        ),

        machine(
            id: "captain", name: "Captain's Gold",
            tagline: "Scatter zahlt überall · Wild an Bord",
            palette: MachinePalette(["#06283D", "#0E5A6D", "#8A6D1F"], accent: "#3FD8C2"),
            motif: .sf("map.fill"),
            symbols: [
                wild(60, 250, 900, art: .sf("lifepreserver.fill"), name: "Steuerrad (Wild)"),
                S("map", "Schatzkarte", .sf("map.fill"), "#FFC46B", 3, 0, 0, 0, scatter: true),
                S("gem", "Smaragd", .shape(.gem), "#3FE8A8", 4, 20, 75, 300),
                S("key", "Truhen-Schlüssel", .sf("key.fill"), "#FFD94D", 5, 12, 45, 180),
                S("ship", "Segelschiff", .sf("sailboat.fill"), "#7FD8FF", 6, 9, 32, 130)
            ] + royals(.mid),
            scatterPays: [3: 5, 4: 20, 5: 100]
        ),

        // ── Weitere Maschinen ──────────────────────────────────────

        machine(
            id: "samurai", name: "Neon Samurai",
            tagline: "20 Linien · 10 Freispiele",
            lines: 20,
            palette: MachinePalette(["#120A2E", "#3D1A6E", "#0E5A6D"], accent: "#6EE7FF"),
            motif: .sf("moon.stars.fill"),
            categories: [.freispiele],
            symbols: [
                wild(50, 200, 800),
                S("seal", "Samurai-Siegel", .sf("seal.fill"), "#FF6B81", 3, 0, 0, 0, scatter: true),
                S("moon", "Neonmond", .sf("moon.stars.fill"), "#B79CFF", 4, 20, 80, 320),
                S("jade", "Jade", .shape(.gem), "#3FE8A8", 5, 12, 45, 180),
                S("bamboo", "Bambus", .sf("leaf.fill"), "#7FE08A", 6, 9, 32, 130)
            ] + royals(.mid),
            scatterPays: [3: 3, 4: 10, 5: 40],
            fs: 10
        ),

        machine(
            id: "pharaoh", name: "Pharaoh's Riches",
            tagline: "Scatter zahlt überall",
            palette: MachinePalette(["#241203", "#6E4416", "#A87B1F"], accent: "#FFC46B"),
            motif: .sf("sun.max.fill"),
            symbols: [
                wild(60, 240, 900),
                S("pyramid", "Pyramide", .sf("triangle.fill"), "#FFD94D", 3, 0, 0, 0, scatter: true),
                S("scarab", "Skarabäus", .sf("ladybug.fill"), "#E85D5D", 4, 18, 70, 300),
                S("eye", "Horus-Auge", .sf("eye.fill"), "#7FD8FF", 5, 12, 45, 180),
                S("sun", "Ra-Sonne", .sf("sun.max.fill"), "#FFB84D", 6, 9, 32, 130)
            ] + royals(.mid),
            scatterPays: [3: 5, 4: 25, 5: 120]
        ),

        machine(
            id: "diamondrush", name: "Diamond Rush",
            tagline: "20 Linien · Multiplikator bis 4× · hochvolatil",
            lines: 20,
            palette: MachinePalette(["#0A1030", "#23306E", "#4A157A"], accent: "#9EE7FF"),
            motif: .shape(.gem),
            categories: [.hochvolatil],
            symbols: [
                wild(90, 350, 1500),
                S("gem", "Riesendiamant", .shape(.gem), "#9EE7FF", 3, 35, 150, 800),
                S("crown", "Krone", .sf("crown.fill"), "#FFD94D", 4, 22, 90, 400),
                S("bell", "Glocke", .sf("bell.fill"), "#FFC46B", 5, 14, 55, 220),
                S("star", "Stern", .sf("star.fill"), "#B79CFF", 6, 10, 38, 160)
            ] + royals(.high),
            multChance: 0.06, multMax: 4
        ),

        machine(
            id: "clover", name: "Lucky Clover",
            tagline: "Sanfte Gewinne · Wild-Goldtopf",
            palette: MachinePalette(["#0B2E14", "#1E6E34", "#6E8F1F"], accent: "#7FE08A"),
            motif: .sf("leaf.fill"),
            symbols: [
                wild(40, 150, 600, art: .shape(.coin), name: "Goldtopf (Wild)"),
                S("clover", "Kleeblatt", .sf("leaf.fill"), "#4ADE80", 4, 18, 65, 260),
                S("horseshoe", "Hufeisen", .shape(.horseshoe), "#C9D4FF", 5, 12, 45, 170),
                S("coin", "Glücksmünze", .shape(.coin), "#FFD94D", 6, 9, 32, 120),
                S("sun", "Sonne", .sf("cloud.sun.fill"), "#FFB84D", 7, 7, 25, 100)
            ] + royals(.low)
        ),

        machine(
            id: "dragon", name: "Dragon Pearl",
            tagline: "12 Freispiele mit 2×",
            palette: MachinePalette(["#2E0A12", "#7A1626", "#A87B1F"], accent: "#FF8A5D"),
            motif: .sf("flame.fill"),
            categories: [.freispiele],
            symbols: [
                wild(55, 220, 850),
                S("seal", "Drachen-Siegel", .sf("seal.fill"), "#FFD94D", 3, 0, 0, 0, scatter: true),
                S("flame", "Drachenflamme", .sf("flame.fill"), "#FF7A3D", 4, 22, 85, 340),
                S("pearl", "Drachenperle", .shape(.coin), "#F5F0FF", 5, 14, 50, 200),
                S("moon", "Mond", .sf("moon.fill"), "#B79CFF", 6, 10, 36, 150)
            ] + royals(.mid),
            scatterPays: [3: 3, 4: 12, 5: 50],
            fs: 12, fsMult: 2
        ),

        machine(
            id: "aztec", name: "Aztec Gold",
            tagline: "20 Linien · Scatter & 10 Freispiele",
            lines: 20,
            palette: MachinePalette(["#12240A", "#3D6E1A", "#A87B1F"], accent: "#FFC46B"),
            motif: .sf("sun.max.fill"),
            categories: [.freispiele],
            symbols: [
                wild(55, 220, 850),
                S("sunstone", "Sonnenstein", .sf("sun.max.fill"), "#FFB84D", 3, 0, 0, 0, scatter: true),
                S("mask", "Goldmaske", .sf("theatermasks.fill"), "#FFD94D", 4, 20, 80, 320),
                S("gem", "Jade", .shape(.gem), "#3FE8A8", 5, 12, 45, 180),
                S("bird", "Quetzal", .sf("bird.fill"), "#7FE08A", 6, 9, 32, 130)
            ] + royals(.mid),
            scatterPays: [3: 4, 4: 15, 5: 60],
            fs: 10
        ),

        machine(
            id: "frozen", name: "Frozen Gems",
            tagline: "Kühle Juwelen · Wild",
            palette: MachinePalette(["#081A30", "#14456E", "#1E7A8F"], accent: "#9EE7FF"),
            motif: .sf("snowflake"),
            symbols: [
                wild(50, 200, 750),
                S("gem", "Eisjuwel", .shape(.gem), "#6EE7FF", 4, 20, 80, 320),
                S("snow", "Schneeflocke", .sf("snowflake"), "#DFF6FF", 5, 13, 48, 190),
                S("crown", "Eiskrone", .sf("crown.fill"), "#B79CFF", 5, 12, 45, 180),
                S("bell", "Eisglocke", .sf("bell.fill"), "#FFC46B", 6, 9, 32, 130)
            ] + royals(.mid)
        ),

        machine(
            id: "safari", name: "Safari Kings",
            tagline: "8 Freispiele · hochvolatil",
            palette: MachinePalette(["#26160A", "#6E4416", "#8F6E1F"], accent: "#FFB84D"),
            motif: .sf("pawprint.fill"),
            categories: [.freispiele, .hochvolatil],
            symbols: [
                wild(70, 280, 1100),
                S("sun", "Savannen-Sonne", .sf("sun.max.fill"), "#FFB84D", 3, 0, 0, 0, scatter: true),
                S("lion", "Löwe", .sf("pawprint.fill"), "#FF9E5D", 3, 30, 130, 650),
                S("tree", "Akazie", .sf("leaf.fill"), "#7FE08A", 5, 14, 52, 210),
                S("gem", "Savannen-Juwel", .shape(.gem), "#3FE8A8", 6, 10, 36, 150)
            ] + royals(.high),
            scatterPays: [3: 3, 4: 12, 5: 50],
            fs: 8
        ),

        machine(
            id: "cherryboom", name: "Cherry Boom",
            tagline: "Klassiker · 3 Walzen",
            reels: 3, lines: 5,
            palette: MachinePalette(["#2E0A1A", "#7A1638", "#A81E4E"], accent: "#FF6B81"),
            motif: .shape(.cherry),
            categories: [.klassiker],
            symbols: [
                SlotSymbolConfig(
                    id: "cherry", name: "Kirsche", art: .shape(.cherry), tint: "#FF6B81",
                    weight: 6, pays: [2: 1, 3: 12]
                ),
                C("seven", "Sieben", .shape(.seven), "#FF5D5D", 2, 100),
                C("bar", "BAR", .shape(.bar), "#FFFFFF", 4, 40),
                C("lemon", "Zitrone", .shape(.lemon), "#FFE066", 5, 20),
                C("bell", "Glocke", .sf("bell.fill"), "#FFC46B", 5, 15),
                C("grape", "Traube", .shape(.grape), "#B79CFF", 6, 10)
            ]
        ),

        machine(
            id: "royalsevens", name: "Royal Sevens",
            tagline: "3 Walzen · fette Siebenen",
            reels: 3, lines: 5,
            palette: MachinePalette(["#141433", "#2C2C6E", "#6B4E12"], accent: "#FFD94D"),
            motif: .shape(.seven),
            categories: [.klassiker, .hochvolatil],
            symbols: [
                C("seven", "Sieben", .shape(.seven), "#FF5D5D", 2, 250),
                C("crown", "Krone", .sf("crown.fill"), "#FFD94D", 3, 100),
                C("gem", "Juwel", .shape(.gem), "#6EE7FF", 4, 60),
                C("bar", "BAR", .shape(.bar), "#FFFFFF", 5, 30),
                C("star", "Stern", .sf("star.fill"), "#B79CFF", 6, 18)
            ]
        ),

        machine(
            id: "bardeluxe", name: "Bar Deluxe",
            tagline: "3 Walzen · purer Klassiker",
            reels: 3, lines: 5,
            palette: MachinePalette(["#101418", "#2E3A44", "#6B4E12"], accent: "#E8E4F5"),
            motif: .shape(.bar),
            categories: [.klassiker],
            symbols: [
                C("bar", "BAR", .shape(.bar), "#FFFFFF", 3, 120),
                C("seven", "Sieben", .shape(.seven), "#FF5D5D", 3, 80),
                C("cherry", "Kirsche", .shape(.cherry), "#FF6B81", 5, 25),
                C("bell", "Glocke", .sf("bell.fill"), "#FFC46B", 5, 18),
                C("lemon", "Zitrone", .shape(.lemon), "#FFE066", 6, 12)
            ]
        ),

        machine(
            id: "mermaid", name: "Mermaid's Pearl",
            tagline: "20 Linien · 10 Freispiele mit 2×",
            lines: 20,
            palette: MachinePalette(["#062A3D", "#0E5A6D", "#1E7A6E"], accent: "#6EE7FF"),
            motif: .sf("fish.fill"),
            categories: [.freispiele],
            symbols: [
                wild(50, 200, 800),
                S("moon", "Mondperle", .sf("moon.fill"), "#DFF6FF", 3, 0, 0, 0, scatter: true),
                S("pearl", "Perle", .shape(.coin), "#F5F0FF", 4, 20, 80, 320),
                S("fish", "Fischschwarm", .sf("fish.fill"), "#FFB84D", 5, 12, 45, 180),
                S("boat", "Muschelboot", .sf("sailboat.fill"), "#7FD8FF", 6, 9, 32, 130)
            ] + royals(.mid),
            scatterPays: [3: 3, 4: 12, 5: 50],
            fs: 10, fsMult: 2
        ),

        machine(
            id: "volcano", name: "Volcano Eruption",
            tagline: "Multiplikator bis 5× · hochvolatil",
            palette: MachinePalette(["#2E0D06", "#7A2410", "#A85A1E"], accent: "#FF8A3D"),
            motif: .sf("flame.fill"),
            categories: [.hochvolatil],
            symbols: [
                wild(80, 320, 1300),
                S("flame", "Lavakern", .sf("flame.fill"), "#FF7A3D", 3, 32, 140, 700),
                S("mountain", "Vulkan", .sf("mountain.2.fill"), "#FFC4A3", 4, 20, 85, 360),
                S("gem", "Obsidian", .shape(.gem), "#B79CFF", 5, 13, 50, 200),
                S("sun", "Glutsonne", .sf("sun.max.fill"), "#FFB84D", 6, 10, 36, 150)
            ] + royals(.high),
            multChance: 0.10, multMax: 5
        ),

        machine(
            id: "panda", name: "Panda Fortune",
            tagline: "Sanft & freundlich · Wild",
            palette: MachinePalette(["#0E2417", "#1E5C38", "#6E8F1F"], accent: "#A7F3C7"),
            motif: .sf("pawprint.fill"),
            symbols: [
                wild(40, 160, 620),
                S("panda", "Panda", .sf("pawprint.fill"), "#F5F0FF", 4, 18, 68, 270),
                S("bamboo", "Bambus", .sf("leaf.fill"), "#7FE08A", 5, 12, 44, 170),
                S("coin", "Glücksmünze", .shape(.coin), "#FFD94D", 6, 9, 32, 125),
                S("moon", "Laternenmond", .sf("moon.fill"), "#B79CFF", 7, 7, 26, 105)
            ] + royals(.low)
        ),

        machine(
            id: "space", name: "Space Rocks",
            tagline: "20 Linien · Scatter zahlt überall",
            lines: 20,
            palette: MachinePalette(["#070B2E", "#1B2160", "#4A157A"], accent: "#6EE7FF"),
            motif: .sf("moon.stars.fill"),
            symbols: [
                wild(55, 220, 880),
                S("star", "Stern", .sf("star.fill"), "#FFD94D", 3, 0, 0, 0, scatter: true),
                S("galaxy", "Galaxie", .sf("moon.stars.fill"), "#B79CFF", 4, 20, 80, 330),
                S("planet", "Planet", .sf("globe"), "#7FD8FF", 5, 12, 46, 185),
                S("meteor", "Meteor", .shape(.gem), "#FF9E5D", 6, 9, 33, 135)
            ] + royals(.mid),
            scatterPays: [3: 5, 4: 20, 5: 100]
        ),

        machine(
            id: "viking", name: "Viking Voyage",
            tagline: "8 Freispiele mit 3× · hochvolatil",
            palette: MachinePalette(["#0D1B2E", "#1E446E", "#6E4416"], accent: "#FFC46B"),
            motif: .sf("shield.fill"),
            categories: [.freispiele, .hochvolatil],
            symbols: [
                wild(65, 260, 1050),
                S("moon", "Runenmond", .sf("moon.fill"), "#DFF6FF", 3, 0, 0, 0, scatter: true),
                S("shield", "Rundschild", .sf("shield.fill"), "#FF9E5D", 4, 24, 95, 420),
                S("ship", "Drachenschiff", .sf("sailboat.fill"), "#7FD8FF", 5, 14, 52, 210),
                S("raven", "Rabe", .sf("bird.fill"), "#B79CFF", 6, 10, 38, 160)
            ] + royals(.high),
            scatterPays: [3: 3, 4: 12, 5: 50],
            fs: 8, fsMult: 3
        ),

        machine(
            id: "candystars", name: "Candy Stars",
            tagline: "Süß & sanft · viele Treffer",
            palette: MachinePalette(["#33102E", "#7A2A6E", "#C94E8F"], accent: "#FF9ECF"),
            motif: .shape(.candy),
            symbols: [
                S("candy", "Bonbon", .shape(.candy), "#FF6B9D", 6, 6, 20, 72),
                S("lollipop", "Lolli", .shape(.lollipop), "#6EE7FF", 6, 5, 18, 62),
                S("star", "Zuckerstern", .sf("star.fill"), "#FFD94D", 6, 5, 16, 55),
                S("heart", "Herzbonbon", .sf("heart.fill"), "#FF5D73", 7, 4, 14, 48),
                S("donut", "Mini-Donut", .shape(.donut), "#FFB84D", 7, 4, 12, 42)
            ] + royals(.low)
        ),

        machine(
            id: "jungle", name: "Jungle King",
            tagline: "20 Linien · 12 Freispiele",
            lines: 20,
            palette: MachinePalette(["#0A2410", "#1E5C26", "#8F6E1F"], accent: "#7FE08A"),
            motif: .sf("leaf.fill"),
            categories: [.freispiele],
            symbols: [
                wild(55, 220, 860),
                S("sun", "Dschungel-Sonne", .sf("sun.max.fill"), "#FFB84D", 3, 0, 0, 0, scatter: true),
                S("tiger", "Tiger", .sf("pawprint.fill"), "#FF9E5D", 4, 21, 84, 340),
                S("parrot", "Papagei", .sf("bird.fill"), "#3FE8A8", 5, 12, 46, 185),
                S("gem", "Smaragd", .shape(.gem), "#3FE8A8", 6, 9, 33, 135)
            ] + royals(.mid),
            scatterPays: [3: 3, 4: 12, 5: 50],
            fs: 12
        ),

        machine(
            id: "pyramid", name: "Golden Pyramid",
            tagline: "Scatter zahlt · 10 Freispiele",
            palette: MachinePalette(["#26200A", "#6E5C16", "#A87B1F"], accent: "#FFD94D"),
            motif: .sf("triangle.fill"),
            categories: [.freispiele],
            symbols: [
                wild(55, 220, 880),
                S("pyramid", "Pyramide", .sf("triangle.fill"), "#FFD94D", 3, 0, 0, 0, scatter: true),
                S("eye", "Sonnenauge", .sf("eye.fill"), "#7FD8FF", 4, 20, 80, 330),
                S("scarab", "Goldskarabäus", .sf("ladybug.fill"), "#FF9E5D", 5, 12, 46, 185),
                S("sun", "Wüstensonne", .sf("sun.max.fill"), "#FFB84D", 6, 9, 33, 135)
            ] + royals(.mid),
            scatterPays: [3: 4, 4: 16, 5: 70],
            fs: 10
        ),

        machine(
            id: "icecrown", name: "Ice Crown",
            tagline: "3 Walzen · eisiger Klassiker",
            reels: 3, lines: 5,
            palette: MachinePalette(["#0A1E33", "#14456E", "#1E7A8F"], accent: "#9EE7FF"),
            motif: .sf("crown.fill"),
            categories: [.klassiker],
            symbols: [
                C("crown", "Eiskrone", .sf("crown.fill"), "#B79CFF", 2, 150),
                C("gem", "Eisjuwel", .shape(.gem), "#6EE7FF", 3, 70),
                C("snow", "Schneeflocke", .sf("snowflake"), "#DFF6FF", 5, 30),
                C("star", "Froststern", .sf("star.fill"), "#FFD94D", 5, 20),
                C("bell", "Frostglocke", .sf("bell.fill"), "#FFC46B", 6, 14)
            ]
        ),

        machine(
            id: "fireball", name: "Fireball Fruits",
            tagline: "Feuerball-Wild · Multiplikator bis 3×",
            palette: MachinePalette(["#2B0E06", "#7A2A10", "#A84E1E"], accent: "#FF8A3D"),
            motif: .shape(.cherry),
            symbols: [
                wild(45, 180, 750, art: .sf("flame.fill"), name: "Feuerball (Wild)"),
                S("cherry", "Feuerkirsche", .shape(.cherry), "#FF6B81", 5, 12, 45, 190),
                S("grape", "Feuertraube", .shape(.grape), "#B79CFF", 6, 9, 34, 140),
                S("lemon", "Feuerzitrone", .shape(.lemon), "#FFE066", 6, 8, 30, 125),
                S("bell", "Feuerglocke", .sf("bell.fill"), "#FFC46B", 7, 7, 26, 110)
            ] + royals(.mid),
            multChance: 0.08, multMax: 3
        ),

        machine(
            id: "wolves", name: "Moonlight Wolves",
            tagline: "10 Freispiele · hochvolatil",
            palette: MachinePalette(["#0A1226", "#1C2C56", "#3D5A80"], accent: "#B79CFF"),
            motif: .sf("moon.fill"),
            categories: [.freispiele, .hochvolatil],
            symbols: [
                wild(65, 260, 1080),
                S("moon", "Vollmond", .sf("moon.fill"), "#DFF6FF", 3, 0, 0, 0, scatter: true),
                S("wolf", "Wolf", .sf("pawprint.fill"), "#C9D4FF", 4, 24, 96, 430),
                S("stars", "Wolfsmond", .sf("moon.stars.fill"), "#B79CFF", 5, 14, 52, 215),
                S("gem", "Mondstein", .shape(.gem), "#6EE7FF", 6, 10, 38, 160)
            ] + royals(.high),
            scatterPays: [3: 3, 4: 12, 5: 50],
            fs: 10
        ),

        machine(
            id: "citrus", name: "Citrus Splash",
            tagline: "Frisch & fruchtig · sanfte Gewinne",
            palette: MachinePalette(["#14300A", "#3D7A16", "#C96A1E"], accent: "#FFE066"),
            motif: .shape(.lemon),
            categories: [.klassiker],
            symbols: [
                S("lemon", "Zitrone", .shape(.lemon), "#FFE066", 6, 7, 24, 90),
                S("grape", "Traube", .shape(.grape), "#B79CFF", 6, 6, 22, 80),
                S("cherry", "Kirsche", .shape(.cherry), "#FF6B81", 6, 6, 20, 75),
                S("leaf", "Minzblatt", .sf("leaf.fill"), "#7FE08A", 7, 5, 17, 62),
                S("bell", "Glocke", .sf("bell.fill"), "#FFC46B", 7, 4, 15, 55)
            ] + royals(.low)
        ),

        machine(
            id: "cove", name: "Treasure Cove",
            tagline: "20 Linien · Scatter & 12 Freispiele mit 2×",
            lines: 20,
            palette: MachinePalette(["#07222E", "#0E4A5C", "#8A6D1F"], accent: "#3FD8C2"),
            motif: .sf("key.fill"),
            categories: [.freispiele],
            symbols: [
                wild(55, 230, 920),
                S("map", "Schatzkarte", .sf("map.fill"), "#FFC46B", 3, 0, 0, 0, scatter: true),
                S("key", "Goldschlüssel", .sf("key.fill"), "#FFD94D", 4, 21, 84, 340),
                S("gem", "Tiefsee-Juwel", .shape(.gem), "#3FE8A8", 5, 12, 46, 185),
                S("coin", "Dublonen", .shape(.coin), "#FFD94D", 6, 9, 33, 135)
            ] + royals(.mid),
            scatterPays: [3: 4, 4: 16, 5: 70],
            fs: 12, fsMult: 2
        )
    ]

    static func config(id: String) -> SlotMachineConfig? {
        configs.first { $0.id == id }
    }
}

// MARK: - Lobby entries (all 32 machines)

extension SlotCatalog {
    private static func entry(for config: SlotMachineConfig) -> LobbyEntry {
        LobbyEntry(
            route: .generic(config.id),
            name: config.name,
            tagline: config.tagline,
            palette: config.palette,
            motif: config.motif,
            motifTint: config.palette.accent,
            categories: config.categories
        )
    }

    static let lobbyEntries: [LobbyEntry] = {
        var entries: [LobbyEntry] = []
        entries.append(LobbyEntry(
            route: .book,
            name: "Book of Muse",
            tagline: "Freispiele & Expanding Symbol",
            palette: MachinePalette(["#2A1450", "#6E3B12", "#8F6E1F"], accent: "#F5A623"),
            motif: .sf("book.fill"),
            motifTint: "#F5A623",
            categories: [.freispiele]
        ))
        // Configurable heroes first
        for id in ["leonida", "olympus", "bandit", "captain", "sugar"] {
            if let config = config(id: id) {
                entries.append(entry(for: config))
            }
        }
        entries.append(LobbyEntry(
            route: .vice,
            name: "Vice Fruits",
            tagline: "Klassiker · 5 Walzen",
            palette: MachinePalette(["#0E3B2E", "#7A1E3F", "#3D6E1A"], accent: "#4ADE80"),
            motif: .shape(.cherry),
            motifTint: "#FF6B81",
            categories: [.klassiker]
        ))
        entries.append(LobbyEntry(
            route: .mochi,
            name: "Mochi Millions",
            tagline: "Klassiker · 3 Walzen",
            palette: MachinePalette(["#33163F", "#7A2A5C", "#C94E8F"], accent: "#F9A8D4"),
            motif: .sf("teddybear.fill"),
            motifTint: "#F9A8D4",
            categories: [.klassiker]
        ))
        // All remaining configurable machines
        let heroIDs: Set<String> = ["leonida", "olympus", "bandit", "captain", "sugar"]
        for config in configs where !heroIDs.contains(config.id) {
            entries.append(entry(for: config))
        }
        return entries
    }()
}

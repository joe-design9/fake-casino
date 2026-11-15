import Foundation

/// Launch-argument screens used by the simulator screenshot job.
enum Screenshot: Equatable {
    case lobby
    case fruitWin
    case bookFreespins
    case joker
    case risikoleiter
    case kartenrisiko
    case megawin
    case spin

    static var current: Screenshot? {
        let args = ProcessInfo.processInfo.arguments
        guard let index = args.firstIndex(of: "-screenshot"), args.indices.contains(index + 1) else {
            return nil
        }
        switch args[index + 1] {
        case "lobby": return .lobby
        case "fruit-win": return .fruitWin
        case "book-freespins": return .bookFreespins
        case "joker": return .joker
        case "risikoleiter": return .risikoleiter
        case "kartenrisiko": return .kartenrisiko
        case "megawin": return .megawin
        case "spin": return .spin
        default: return .lobby
        }
    }

    var game: GameKind? {
        switch self {
        case .lobby: return nil
        case .fruitWin, .risikoleiter, .kartenrisiko, .megawin, .spin: return .fruchtfeuer
        case .bookFreespins: return .sphinx
        case .joker: return .joker
        }
    }
}

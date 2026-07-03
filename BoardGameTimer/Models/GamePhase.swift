import Foundation

// GamePhase lists every stage a live game moves through, in order. It is a plain Swift
// enum (NOT a SwiftData `@Model`) because it only describes what's happening RIGHT NOW on
// screen — nothing about "which phase is active" needs to be saved to disk. When a game
// finishes, only the final DURATION of each phase gets saved (that comes in Milestone 5).
//
// `String` after the colon means each case has a built-in text value (its own name, e.g.
// `.setup` is stored as "setup") — handy later for saving/debugging without extra code.
// `CaseIterable` auto-generates `GamePhase.allCases`, an array of every case in declaration
// order, which is exactly how `advancePhase()` below figures out "what comes next."
enum GamePhase: String, CaseIterable {
    // Players are getting the board/pieces ready. First phase of every game.
    case setup
    // Whoever is teaching explains the rules before play begins.
    case explanation
    // The actual game — this is when the chess-clock, per-player turn timers run.
    case playing
    // Packing the game away at the end.
    case cleanup
    // The final screen: totals for the whole game, once everything else is done.
    case summary
}

extension GamePhase {
    // A short, friendly title to show at the top of the Live Game screen for this phase.
    var displayTitle: String {
        switch self {
        case .setup: return "Setup"
        case .explanation: return "Explanation"
        case .playing: return "Playing"
        case .cleanup: return "Cleanup"
        case .summary: return "Summary"
        }
    }

    // The SF Symbol (built-in Apple icon) that represents this phase, shown next to its
    // title so every screen leads with an icon rather than text alone.
    var sfSymbolName: String {
        switch self {
        case .setup: return "wrench.and.screwdriver"
        case .explanation: return "text.bubble"
        case .playing: return "hourglass"
        case .cleanup: return "trash"
        case .summary: return "flag.checkered"
        }
    }
}

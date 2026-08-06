import Foundation

// GameMode is the choice made at the very top of Player Setup, before anything else: does
// each player's clock count UP from zero, or DOWN from a fixed budget?
//
// Both modes run on exactly the same engine — every player's time is always banked upward
// internally (see TimerGameViewModel). Countdown is a presentation-and-alarm layer on top:
// "remaining" is simply the budget minus the time used. That keeps the drift-free date math
// identical in both modes, and means a countdown game's saved history is directly comparable
// to a stopwatch one.
enum GameMode: String, Codable, CaseIterable, Hashable {
    // Clocks count up from 0:00 with no ceiling. The original (and still default) behavior.
    case stopwatch

    // Each player starts with a fixed budget of thinking time that counts down. Running out
    // is deliberately SOFT: the clock keeps going into negative numbers in red and sounds the
    // alarm once, but nobody is eliminated and no turn is auto-passed — the table decides what
    // running out means for their game.
    case countdown

    // The label shown on the mode chips in Player Setup.
    var title: String {
        switch self {
        case .stopwatch: return "Stopwatch"
        case .countdown: return "Countdown"
        }
    }

    // The one-line explanation shown under the chips, so the choice doesn't need a manual.
    var explanation: String {
        switch self {
        case .stopwatch: return "Every clock counts up. No limit."
        case .countdown: return "Each player spends a fixed time bank."
        }
    }
}

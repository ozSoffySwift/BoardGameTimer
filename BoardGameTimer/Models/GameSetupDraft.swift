import Foundation
import SwiftUI

// GameSetupDraft holds everything the Player Setup screen is editing BEFORE a game starts:
// how many players, their names/colors, the game's name, the per-turn time limit, and who
// goes first. It's `@Observable` so the setup screen's controls bind straight to it, and
// it's separate from TimerGameViewModel because a draft can be abandoned (back button)
// without ever becoming a real running game.
@Observable
final class GameSetupDraft {
    // Which seat goes first — either a specific player, or randomized at start time.
    enum FirstPlayerChoice: Hashable {
        case player(Int) // a specific seat index
        case random      // pick a random seat when the game actually starts
    }

    // The players being configured, in seat order. Grows/shrinks as the count changes.
    var players: [TimerPlayer]

    // The game's (optional) display name, e.g. "Catan Night".
    var gameName = ""

    // Per-turn limit in seconds (10-300, stepping by 5, per the design's slider).
    var turnLimitSeconds: Int

    // Who takes the first turn.
    var firstPlayerChoice: FirstPlayerChoice = .player(0)

    // How many players are in the draft right now (convenience for the count chips).
    var playerCount: Int { players.count }

    // Builds a fresh draft using the user's saved defaults from the Settings tab:
    // `defaultTurnLimit` seeds the time slider, and `defaultColors` decides which meeple
    // color each seat starts with.
    init(playerCount: Int = 4, defaultTurnLimit: Int = 60, defaultColors: [Int] = Array(0..<10)) {
        self.turnLimitSeconds = defaultTurnLimit
        self.players = (0..<playerCount).map { seat in
            TimerPlayer(
                name: "Player \(seat + 1)",
                // `% count` wraps around if there are somehow more seats than colors.
                colorIndex: defaultColors[seat % max(defaultColors.count, 1)]
            )
        }
        self.defaultColors = defaultColors
    }

    // Kept so newly-added seats (count chip taps) also get default colors.
    private let defaultColors: [Int]

    // Changes how many players there are, keeping existing names/colors for seats that
    // survive and adding fresh defaults for new seats — matching the design's chip behavior.
    func setPlayerCount(_ count: Int) {
        if count < players.count {
            players = Array(players.prefix(count))
        } else {
            while players.count < count {
                let seat = players.count
                players.append(TimerPlayer(
                    name: "Player \(seat + 1)",
                    colorIndex: defaultColors[seat % max(defaultColors.count, 1)]
                ))
            }
        }
        // If the chosen first player no longer exists (count shrank below them), fall
        // back to seat 0 rather than pointing at a missing seat.
        if case .player(let index) = firstPlayerChoice, index >= count {
            firstPlayerChoice = .player(0)
        }
    }

    // Resolves the actual starting seat at the moment the game begins — this is where
    // "Random First Player" actually rolls its dice.
    func resolvedFirstPlayerIndex() -> Int {
        switch firstPlayerChoice {
        case .player(let index):
            return min(index, max(players.count - 1, 0))
        case .random:
            return Int.random(in: 0..<max(players.count, 1))
        }
    }
}

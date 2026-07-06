import Foundation
import SwiftData

// PlayerResult is one player's final line in a finished game: who they were, which meeple
// color they used, and how much total thinking time they spent. A plain Codable struct
// (not its own @Model) because a result never exists on its own — it only lives inside a
// GameRecord, and SwiftData can store an array of Codable values directly as one field.
struct PlayerResult: Codable {
    // The player's display name at the time the game ended, e.g. "Alex".
    var name: String
    // Which of the ten MeeplePalette gradients this player used (0-9).
    var colorIndex: Int
    // Total seconds this player's clock ran across the whole game.
    var secondsUsed: Int
}

// GameRecord is one finished game, saved permanently on the device so it shows up in the
// Statistics tab (and the Home screen's "Recent Games" list) forever — until the user taps
// Clear History. `@Model` is SwiftData's marker meaning "store objects of this class in a
// database automatically" — no manual file reading/writing code anywhere; inserting one of
// these into the model context IS the save.
@Model
final class GameRecord {
    // When the game finished. Also what the Statistics list sorts by (newest first).
    var date: Date

    // The game's name, e.g. "Catan Night" — or "Untitled Game" if none was entered.
    var gameName: String

    // How many full rounds were completed (a round ends each time the turn passes back
    // to whoever went first).
    var rounds: Int

    // Every player's final result, in seat order. Stored as one Codable array field —
    // simpler than a full SwiftData relationship, and results are never queried on
    // their own, only ever loaded together with their game.
    var players: [PlayerResult]

    // Creates a record ready to insert. SwiftData requires an explicit initializer on
    // @Model classes (it can't synthesize one the way plain structs get for free).
    init(date: Date, gameName: String, rounds: Int, players: [PlayerResult]) {
        self.date = date
        self.gameName = gameName
        self.rounds = rounds
        self.players = players
    }
}

extension GameRecord {
    // The winner is whoever used the LEAST total time (fastest thinker) — matching the
    // design, which crowns the smallest time. Returns the index into `players`, or nil
    // for an empty (shouldn't happen) player list.
    var winnerIndex: Int? {
        guard !players.isEmpty else { return nil }
        // `min(by:)` finds the smallest element; `firstIndex` turns it back into a
        // position. Ties go to whoever appears first in seat order.
        let minSeconds = players.map(\.secondsUsed).min() ?? 0
        return players.firstIndex { $0.secondsUsed == minSeconds }
    }

    // A short caption like "4 players" or "1 player", used in history rows.
    var playerCountLabel: String {
        players.count == 1 ? "1 player" : "\(players.count) players"
    }

    // A short caption like "3 rounds" or "1 round".
    var roundsLabel: String {
        rounds == 1 ? "1 round" : "\(rounds) rounds"
    }

    // The game's date formatted like "Jul 3, 2026" for list rows and the results header.
    var dateLabel: String {
        date.formatted(.dateTime.month(.abbreviated).day().year())
    }

    // The plain-text summary the Share button sends, e.g.
    //   Catan Night — Jul 3, 2026
    //   - Alex: 12:30
    //   - Sam: 9:12
    var shareText: String {
        let lines = players.map { "- \($0.name): \(TimeInterval($0.secondsUsed).asClockString)" }
        return "\(gameName) \u{2014} \(dateLabel)\n" + lines.joined(separator: "\n")
    }
}

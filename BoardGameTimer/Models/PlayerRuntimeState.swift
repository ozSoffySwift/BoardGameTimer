import SwiftUI // Needed here because this struct stores a `Color`, which is a SwiftUI type.

// PlayerRuntimeState holds everything the Live Game screen needs to know about ONE player
// while a game is actually being played.
//
// This is NOT the same as a saved/persisted player (that comes later, in Milestone 5, using
// SwiftData). This struct only exists in memory while the app is running — think of it as a
// "scratchpad" version of a player that gets thrown away (or saved to the database) once the
// game ends. Keeping it separate from the saved data means we don't write to the database
// every single time a timer ticks or a turn changes, which would be slow and unnecessary.
struct PlayerRuntimeState: Identifiable {
    // `id` is required by SwiftUI's `Identifiable` protocol so things like `ForEach` can
    // tell every player apart, even if two players happen to have the same name.
    let id: UUID

    // The player's display name, e.g. "Alex". Shown inside their pie wedge.
    var name: String

    // The color used to fill this player's wedge and highlight their name/icon.
    // Later (Milestone 6) this will come from a named color in the Xcode Asset Catalog
    // instead of a raw SwiftUI Color, so each player's color can have different shades for
    // light/dark mode — but a plain Color is simpler to start with.
    var color: Color

    // The name of an SF Symbol (Apple's built-in icon set) representing this player,
    // e.g. "crown.fill". Using SF Symbols means we don't need any custom image files.
    var sfSymbolName: String

    // Which "seat" this player occupies around the pie, starting at 0. Seats 0, 1, 2...
    // are placed clockwise around the circle, starting from the top. This number is what
    // all the angle math in WedgeShape and PieLayoutView uses to figure out where this
    // player's slice goes and which way to rotate their text.
    var seatIndex: Int

    // How many seconds this player has accumulated so far during the "Playing" phase.
    // Starting in Milestone 2 this updates live while their clock is running; for now
    // (Milestone 1) it is just a fixed fake number so we can see time text rendered inside
    // the wedge.
    var accumulatedPlayTime: TimeInterval

    // How many separate turns this player has taken so far. Also fake/fixed for now.
    var turnCount: Int

    // Whether it is currently this player's turn (their clock is the one running).
    // The Live Game screen highlights whichever player has `isActiveTurn == true`.
    var isActiveTurn: Bool
}

extension PlayerRuntimeState {
    // Generates a fixed, fake list of players so we can test the pie layout before there is
    // a real game in progress. This is ONLY for Milestone 1 (proving the visual works) and
    // for Xcode's SwiftUI Preview. Starting in Milestone 2, real player data will come from
    // GameSessionViewModel instead of this function.
    static func sampleData(count: Int) -> [PlayerRuntimeState] {
        // A small fixed list of colors to cycle through so every sample player looks
        // different from their neighbors.
        let sampleColors: [Color] = [.red, .teal, .orange, .purple, .mint, .blue, .pink, .green]

        // A matching list of SF Symbol icon names, lined up one-to-one with the colors above.
        let sampleIcons: [String] = [
            "crown.fill", "shield.fill", "flame.fill", "bolt.fill",
            "leaf.fill", "star.fill", "drop.fill", "pawprint.fill"
        ]

        // Build one PlayerRuntimeState per seat, from seat 0 up to (count - 1).
        // `(0..<count).map { ... }` runs the closure once per seat index and collects the
        // results into an array — the standard Swift way to build a list from a range of
        // numbers.
        return (0..<count).map { seatIndex in
            PlayerRuntimeState(
                id: UUID(),
                name: "Player \(seatIndex + 1)",
                // `% sampleColors.count` ("modulo") wraps back around to the start of the
                // list if there are more players than sample colors, so this never crashes
                // even at 8 players.
                color: sampleColors[seatIndex % sampleColors.count],
                sfSymbolName: sampleIcons[seatIndex % sampleIcons.count],
                seatIndex: seatIndex,
                // Fake accumulated time, just so each wedge shows a slightly different time
                // string (e.g. seat 0 shows 0:05, seat 1 shows 0:17, and so on).
                accumulatedPlayTime: TimeInterval(seatIndex * 12 + 5),
                turnCount: seatIndex + 1,
                // Only the very first sample player is marked "active" so we can see what
                // the highlighted state looks like.
                isActiveTurn: seatIndex == 0
            )
        }
    }
}

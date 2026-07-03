import Foundation

// BGGGameSummary holds everything we need to show ONE search result from BoardGameGeek
// (BGG) — a website with a free database of board games. This is intentionally a small,
// plain struct (not a SwiftData @Model) because it's just a lightweight "here's what BGG
// told us" snapshot used while picking a game, not something we need to persist long-term
// on its own (only the pieces we care about — like the game's name — eventually get copied
// onto the GameSessionViewModel/GameSession once a game actually starts).
struct BGGGameSummary: Identifiable, Equatable {
    // BGG's own internal ID number for this game (e.g. Catan is id 13). We use BGG's id as
    // OUR `id` too, since it's already unique and stable — no need to invent our own UUID.
    let id: Int

    // The game's title, e.g. "Catan".
    let name: String

    // The year this game/edition was first published, e.g. 1995. Optional because BGG
    // doesn't always have this filled in for every entry.
    let yearPublished: Int?

    // A small preview picture of the game's box art, hosted on BGG's image servers.
    // Optional because looking up thumbnails is a second network step (see
    // BoardGameGeekService.swift) that might not have finished yet, or might fail.
    var thumbnailURL: URL?

    // The smallest and largest number of players the game supports, e.g. 3 and 4 for
    // Catan. Optional for the same reason as `thumbnailURL` above.
    var minPlayers: Int?
    var maxPlayers: Int?
}

import Foundation

// BoardGameGeekService talks to BoardGameGeek (BGG) — a free, public website with a huge
// database of board games — so the app can look up a game by name and show its real box
// art. BGG's API replies in XML (an older, tag-based text format, e.g. `<name value="Catan"
// />`), NOT the JSON most modern web APIs use, so this file also has to know how to read
// XML using Foundation's built-in `XMLParser`.
//
// `enum BoardGameGeekService` (rather than a `struct` or `class`) is a common Swift pattern
// for "a namespace full of static functions with no data of its own to store" — you never
// make an actual `BoardGameGeekService()` instance, you just call
// `BoardGameGeekService.search(...)` directly.
enum BoardGameGeekService {
    // As of late 2025, BGG requires every XML API request to be a REGISTERED, AUTHENTICATED
    // application — anonymous requests now get rejected with "401 Unauthorized" (this is a
    // real BGG policy change, not a bug here). Getting a token means applying at
    // https://boardgamegeek.com/using_the_xml_api (approval reportedly takes about a week)
    // and choosing a commercial/non-commercial license as appropriate for this app.
    //
    // Leave this `nil` until you have a real token. `nil` is handled gracefully everywhere
    // in this file: requests are simply sent without an Authorization header, BGG rejects
    // them, and the UI quietly falls back to letting the user type a plain game name with
    // no BGG match — nothing crashes or hangs either way.
    //
    // IMPORTANT: never commit a real token here — this repository is public on GitHub, and
    // anyone could read and reuse it. If you fill this in locally, either keep that change
    // uncommitted, or move it into a separate file added to `.gitignore`.
    private static let apiToken: String? = nil

    // The two things that can go wrong talking to BGG, beyond whatever `URLSession` itself
    // throws (like "no internet connection"). Conforming to `Error` lets these be thrown
    // and caught like any other Swift error.
    enum ServiceError: Error {
        // We failed to build a valid URL at all (shouldn't normally happen, but safer than
        // force-unwrapping and crashing).
        case invalidURL
        // BGG responded, but not with a normal "200 OK" success status.
        case unexpectedResponse
    }

    // Looks up games on BGG whose name matches `query` (e.g. "catan"), returning just the
    // basics (id/name/year) — NOT thumbnails yet, since BGG's search endpoint doesn't
    // include images. `async throws` means: this does network work that takes a moment
    // (so callers must `await` it), and it might fail (so callers must be ready to `catch`).
    static func search(query: String) async throws -> [BGGGameSummary] {
        // `URLComponents` builds a URL piece-by-piece and correctly escapes special
        // characters in the query text (spaces, punctuation, etc.) — much safer than
        // gluing strings together by hand, which can produce a broken or unsafe URL.
        var components = URLComponents(string: "https://boardgamegeek.com/xmlapi2/search")!
        components.queryItems = [
            URLQueryItem(name: "query", value: query),
            // Restrict results to base board games (not expansions/accessories), which
            // keeps the result list focused on what a search-as-you-type box should show.
            URLQueryItem(name: "type", value: "boardgame"),
        ]
        guard let url = components.url else { throw ServiceError.invalidURL }

        let data = try await fetchXMLData(from: url)

        // Hand the raw XML bytes to our small parser delegate below, which reads through
        // the XML tag-by-tag and builds up a plain array of BGGGameSummary as it goes.
        let parser = XMLParser(data: data)
        let delegate = SearchResultsParserDelegate()
        parser.delegate = delegate
        parser.parse()

        // A search for a common word can match dozens of expansions/reprints/foreign
        // editions. Keeping only the first 12 stops the results list from becoming an
        // overwhelming wall of near-duplicate entries to scroll through.
        return Array(delegate.results.prefix(12))
    }

    // Given some search results, looks up each game's thumbnail picture and player-count
    // range, then returns NEW copies of those same games with that extra info filled in.
    // This is a separate step from `search` because BGG's search endpoint doesn't include
    // images — you have to ask its "thing" (BGG's word for "game entry") endpoint instead.
    static func fetchThumbnails(for games: [BGGGameSummary]) async throws -> [BGGGameSummary] {
        // Nothing to look up if there were no search results — return immediately rather
        // than making a pointless empty network request.
        guard !games.isEmpty else { return games }

        // BGG's "thing" endpoint accepts MULTIPLE ids at once, comma-separated (e.g.
        // "13,822,536"), and returns details for all of them in a single response. Doing
        // one combined request for every search result is much faster than one request
        // per game.
        let idList = games.map { String($0.id) }.joined(separator: ",")
        var components = URLComponents(string: "https://boardgamegeek.com/xmlapi2/thing")!
        components.queryItems = [URLQueryItem(name: "id", value: idList)]
        guard let url = components.url else { throw ServiceError.invalidURL }

        let data = try await fetchXMLData(from: url)

        let parser = XMLParser(data: data)
        let delegate = ThingDetailsParserDelegate()
        parser.delegate = delegate
        parser.parse()

        // `map` walks every game we were given and returns an updated COPY of each one
        // (structs can't be changed in place inside a read-only array), filling in
        // whatever thumbnail/player-count info the parser found for that game's id — or
        // leaving those fields `nil` if BGG didn't have that info for some reason.
        return games.map { game in
            var updatedGame = game
            updatedGame.thumbnailURL = delegate.thumbnailURLsByGameID[game.id]
            updatedGame.minPlayers = delegate.minPlayersByGameID[game.id]
            updatedGame.maxPlayers = delegate.maxPlayersByGameID[game.id]
            return updatedGame
        }
    }

    // The single function the UI actually calls: searches by name, then immediately looks
    // up thumbnails for whatever it found, so PlayerCountView only has to await one thing.
    static func searchWithThumbnails(query: String) async throws -> [BGGGameSummary] {
        let basicResults = try await search(query: query)
        return try await fetchThumbnails(for: basicResults)
    }

    // A small shared helper used by both `search` and `fetchThumbnails` — actually performs
    // the network request and hands back the raw response bytes, once we're sure the
    // request actually succeeded.
    private static func fetchXMLData(from url: URL) async throws -> Data {
        // Building a `URLRequest` (rather than fetching the URL directly) is what lets us
        // attach a custom header — specifically the "Authorization: Bearer <token>" header
        // BGG now requires (see `apiToken` above). If `apiToken` is still `nil`, this header
        // is simply never added, and the request goes out exactly as it did before.
        var request = URLRequest(url: url)
        if let apiToken {
            request.setValue("Bearer \(apiToken)", forHTTPHeaderField: "Authorization")
        }

        // `URLSession.shared.data(for:)` is the modern async/await way to fetch a request:
        // it pauses this function (without freezing the rest of the app) until the
        // response arrives, then hands back both the raw bytes and metadata about the
        // response (like its status code).
        let (data, response) = try await URLSession.shared.data(for: request)

        // BGG occasionally replies "202 Accepted" (meaning "still preparing your answer,
        // try again shortly") instead of the data itself, especially under heavy load.
        // If we see that, wait briefly and retry ONCE rather than immediately failing.
        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 202 {
            try await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 seconds, in nanoseconds
            let (retryData, retryResponse) = try await URLSession.shared.data(for: request)
            guard let retryHTTPResponse = retryResponse as? HTTPURLResponse,
                  retryHTTPResponse.statusCode == 200 else {
                throw ServiceError.unexpectedResponse
            }
            return retryData
        }

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw ServiceError.unexpectedResponse
        }
        return data
    }
}

// SearchResultsParserDelegate reads through the XML returned by BGG's "search" endpoint,
// which looks roughly like:
//   <items>
//     <item type="boardgame" id="13">
//       <name type="primary" value="Catan"/>
//       <yearpublished value="1995"/>
//     </item>
//     ...
//   </items>
//
// `XMLParser` works by reading the document from top to bottom and calling methods on its
// `delegate` (this class) every time it encounters something — the START of a tag, the END
// of a tag, or text sitting between tags. This class implements just the two callbacks it
// actually needs (`didStartElement` and `didEndElement`) to build up a plain array of
// BGGGameSummary as the parser moves through the file.
private final class SearchResultsParserDelegate: NSObject, XMLParserDelegate {
    // The finished list of games found so far — this is what BoardGameGeekService.search
    // reads once parsing is done.
    private(set) var results: [BGGGameSummary] = []

    // These three hold whatever we've learned about the CURRENT `<item>` element while
    // we're still somewhere inside it, before we know we've reached its closing tag (at
    // which point we package them up into one BGGGameSummary and reset them for the next
    // item).
    private var currentID: Int?
    private var currentName: String?
    private var currentYear: Int?

    // Called every time the parser reaches the START of a tag, e.g. `<item id="13">` or
    // `<name type="primary" value="Catan"/>`. `attributeDict` holds that tag's attributes
    // (the `key="value"` pairs written inside the tag) as a plain `[String: String]`.
    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        switch elementName {
        case "item":
            // A new game entry is starting — read its id and reset the other fields so
            // leftover data from a PREVIOUS item can't accidentally leak into this one.
            currentID = attributeDict["id"].flatMap(Int.init)
            currentName = nil
            currentYear = nil

        case "name":
            // BGG lists a "primary" name plus sometimes several "alternate" (translated or
            // renamed) versions for the same game. We only want the primary one, and only
            // the FIRST time we see it (in the rare case BGG lists it twice).
            if attributeDict["type"] == "primary", currentName == nil {
                currentName = attributeDict["value"]
            }

        case "yearpublished":
            currentYear = attributeDict["value"].flatMap(Int.init)

        default:
            // Any other tag (like the outer `<items>` wrapper) doesn't matter to us here.
            break
        }
    }

    // Called every time the parser reaches the END of a tag, e.g. `</item>`. This is our
    // cue that we now know everything about the item we were just reading, so we can
    // package it up into a real BGGGameSummary and add it to `results`.
    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        guard elementName == "item" else { return }

        // Only keep this result if we actually found both an id and a name for it — an
        // entry missing either would be useless to display or to look up thumbnails for.
        if let id = currentID, let name = currentName {
            results.append(
                BGGGameSummary(id: id, name: name, yearPublished: currentYear)
            )
        }
    }
}

// ThingDetailsParserDelegate reads through the XML returned by BGG's "thing" endpoint,
// which (for our purposes) looks roughly like:
//   <items>
//     <item type="boardgame" id="13">
//       <thumbnail>https://cf.geekdo-images.com/.../pic123_t.jpg</thumbnail>
//       <minplayers value="3"/>
//       <maxplayers value="4"/>
//     </item>
//     ...
//   </items>
//
// This is a SEPARATE delegate class from SearchResultsParserDelegate (rather than one
// combined class trying to handle both XML shapes) so each one stays small and focused on
// reading just the one kind of response it's built for.
private final class ThingDetailsParserDelegate: NSObject, XMLParserDelegate {
    // Three separate lookup dictionaries, all keyed by BGG's game id, since a single
    // "thing" response can describe several games at once (see `fetchThumbnails` above).
    private(set) var thumbnailURLsByGameID: [Int: URL] = [:]
    private(set) var minPlayersByGameID: [Int: Int] = [:]
    private(set) var maxPlayersByGameID: [Int: Int] = [:]

    // Which game's `<item>` block we're currently reading through.
    private var currentGameID: Int?

    // Unlike `value="..."` attributes, `<thumbnail>` stores its URL as plain TEXT sitting
    // BETWEEN the opening and closing tags (`<thumbnail>this part here</thumbnail>`), so we
    // need to track "are we currently inside a <thumbnail> tag?" and collect that text as
    // it arrives, piece by piece, in `foundCharacters` below.
    private var isInsideThumbnailTag = false
    private var thumbnailTextSoFar = ""

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        switch elementName {
        case "item":
            currentGameID = attributeDict["id"].flatMap(Int.init)

        case "thumbnail":
            isInsideThumbnailTag = true
            thumbnailTextSoFar = ""

        case "minplayers":
            if let gameID = currentGameID, let value = attributeDict["value"].flatMap(Int.init) {
                minPlayersByGameID[gameID] = value
            }

        case "maxplayers":
            if let gameID = currentGameID, let value = attributeDict["value"].flatMap(Int.init) {
                maxPlayersByGameID[gameID] = value
            }

        default:
            break
        }
    }

    // Called with a CHUNK of the plain text sitting between two tags — for a short URL this
    // usually arrives all in one piece, but XMLParser doesn't guarantee that, so we always
    // append rather than overwrite, to be safe.
    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if isInsideThumbnailTag {
            thumbnailTextSoFar += string
        }
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        if elementName == "thumbnail" {
            // We've reached `</thumbnail>`, so `thumbnailTextSoFar` now holds the complete
            // URL text. `.trimmingCharacters` strips any stray leading/trailing whitespace
            // or newlines BGG's XML formatting might have included around it.
            if let gameID = currentGameID,
               let url = URL(string: thumbnailTextSoFar.trimmingCharacters(in: .whitespacesAndNewlines)) {
                thumbnailURLsByGameID[gameID] = url
            }
            isInsideThumbnailTag = false
        }
    }
}

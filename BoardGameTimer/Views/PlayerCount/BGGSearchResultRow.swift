import SwiftUI

// BGGSearchResultRow draws ONE row in the "which game did you mean?" list shown while
// typing a game name — a small cover thumbnail (fetched live from BoardGameGeek) plus the
// game's name and year/player-count info.
struct BGGSearchResultRow: View {
    // The search result this row displays.
    let game: BGGGameSummary

    // Whether this is the game the user has currently selected — draws a highlighted
    // background/border so the picked result stands out from the rest of the list.
    var isSelected: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            // `AsyncImage` is a built-in SwiftUI view (no extra networking code needed) that
            // downloads and displays an image from a URL, showing a placeholder until it
            // arrives (or if it fails/there's no URL at all).
            AsyncImage(url: game.thumbnailURL) { phase in
                if let image = phase.image {
                    image
                        .resizable()
                        .scaledToFill()
                } else {
                    // Shown while loading, or if there's no thumbnail/it failed to load —
                    // a plain icon so the row still looks intentional rather than blank.
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.systemGray5))
                        .overlay(
                            Image(systemName: "photo")
                                .foregroundStyle(.secondary)
                        )
                }
            }
            .frame(width: 44, height: 44)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 2) {
                Text(game.name)
                    .font(.system(.subheadline, design: .rounded).weight(.medium))
                    .foregroundStyle(isSelected ? Color.accentColor : .primary)
                    .lineLimit(1)

                // Builds a small "1995 · 3–4 players" caption, only including the pieces we
                // actually have data for (BGG doesn't always report every field).
                Text(captionText)
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isSelected ? Color.accentColor.opacity(0.12) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
        )
    }

    // Combines whichever of year/min/max player fields BGG actually gave us into one short
    // caption, e.g. "1995 · 3–4 players" — or just "3–4 players" if the year is missing.
    private var captionText: String {
        var parts: [String] = []
        if let year = game.yearPublished {
            parts.append(String(year))
        }
        if let minPlayers = game.minPlayers, let maxPlayers = game.maxPlayers {
            parts.append(minPlayers == maxPlayers ? "\(minPlayers) players" : "\(minPlayers)\u{2013}\(maxPlayers) players")
        }
        return parts.joined(separator: " \u{00B7} ")
    }
}

#Preview {
    VStack {
        BGGSearchResultRow(
            game: BGGGameSummary(id: 13, name: "Catan", yearPublished: 1995, minPlayers: 3, maxPlayers: 4),
            isSelected: true
        )
        BGGSearchResultRow(
            game: BGGGameSummary(id: 822, name: "Carcassonne", yearPublished: 2000, minPlayers: 2, maxPlayers: 5)
        )
    }
    .padding()
}

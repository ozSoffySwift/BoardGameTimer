import SwiftUI

// PlayerCountView is the very first real screen the user sees: name the game (optionally
// picked from BoardGameGeek, which fills in real cover art), then say how many players are
// playing. Kept on one screen since both are quick, single-tap-or-type decisions.
struct PlayerCountView: View {
    // How many players are currently selected, from 1 to 8. `@State` tells SwiftUI to watch
    // this value and automatically redraw the view whenever it changes.
    @State private var playerCount: Int = 4

    // The smallest and largest number of players this app supports, matching the app's
    // requirements (games from 1 up to 8 players).
    private let minPlayers = 1
    private let maxPlayers = 8

    // Whatever the user has typed into the "Game" field so far. Naming the game is entirely
    // optional — the timer works fine with this left blank.
    @State private var gameNameQuery = ""

    // The BoardGameGeek search results matching `gameNameQuery`, if any. Cleared out again
    // once the user actually picks one, so the list disappears.
    @State private var searchResults: [BGGGameSummary] = []

    // The specific BGG game the user tapped from the results list, if they picked one
    // rather than just leaving free-text in the field.
    @State private var selectedGame: BGGGameSummary?

    // Whether a BGG search is currently in flight, so we can show a small "Searching…" hint
    // instead of leaving the screen looking unresponsive.
    @State private var isSearching = false

    // The currently in-flight (or waiting-to-start) search, kept so we can CANCEL it if the
    // user keeps typing — without this, slow old searches could finish after a newer one
    // and overwrite its results with stale data.
    @State private var searchTask: Task<Void, Never>?

    // Whether the "everybody place a finger" first-player picker is currently covering the
    // screen. Starts the flow: PlayerCountView -> FirstPlayerPickerView -> LiveGameView.
    @State private var isShowingFirstPlayerPicker = false

    // Holds the view model for a game currently being played, or `nil` when no game is in
    // progress. Setting this to a real value is what triggers `.fullScreenCover(item:)`
    // below to appear; setting it back to `nil` (which SwiftUI does automatically when the
    // cover is dismissed) makes the cover go away.
    @State private var activeGameViewModel: GameSessionViewModel?

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                Image(systemName: "die.face.5.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.tint)
                    .padding(.top, 24)

                gameNameSection

                playerCountSection

                // Starting the game first shows the first-player picker; ONLY once that
                // resolves does a real GameSessionViewModel get created (see
                // `presentFirstPlayerPicker` / the `onPicked` closure below) — a real,
                // running game uses a full-screen cover rather than a normal push so an
                // accidental swipe-back or nav-bar tap can't interrupt a live timer.
                //
                // With only 1 player, "who goes first?" has exactly one possible answer —
                // the finger-picker mini-game would be pointless (and would just sit there
                // waiting for a second finger that's never coming), so skip straight to
                // starting the game with seat 0 instead of showing it at all.
                Button {
                    if playerCount > 1 {
                        isShowingFirstPlayerPicker = true
                    } else {
                        startGame(firstPlayerSeat: 0)
                    }
                } label: {
                    Text("Continue")
                        .font(.system(.headline, design: .rounded))
                        .frame(maxWidth: .infinity)
                        .padding()
                }
                .buttonStyle(.borderedProminent)
                .padding(.horizontal, 32)
                .padding(.bottom, 24)
            }
            .padding(.horizontal)
        }
        .fullScreenCover(isPresented: $isShowingFirstPlayerPicker) {
            FirstPlayerPickerView(
                playerCount: playerCount,
                onPicked: { firstSeat in
                    startGame(firstPlayerSeat: firstSeat)
                },
                onCancel: {
                    isShowingFirstPlayerPicker = false
                }
            )
        }
        // `.fullScreenCover(item:)` shows LiveGameView full-screen whenever
        // `activeGameViewModel` holds a real value, and automatically sets it back to `nil`
        // (dismissing the cover) once LiveGameView calls its own `dismiss()` on the Summary
        // screen's "Done" button.
        .fullScreenCover(item: $activeGameViewModel) { viewModel in
            LiveGameView(viewModel: viewModel)
        }
    }

    // The "which game are you playing?" text field, live BGG search results, and the
    // currently-selected game's cover card.
    private var gameNameSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Game")
                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                .foregroundStyle(.secondary)

            TextField("e.g. Catan", text: $gameNameQuery)
                .textFieldStyle(.roundedBorder)
                .autocorrectionDisabled()
                // Runs every time the typed text changes — (re)starts a debounced BGG
                // search rather than firing one network request per keystroke.
                .onChange(of: gameNameQuery) { _, newValue in
                    // If the field no longer matches the previously selected game, treat it
                    // as "no longer that specific game" so the search list reappears.
                    if newValue != selectedGame?.name {
                        selectedGame = nil
                    }
                    scheduleSearch(for: newValue)
                }

            if isSearching {
                Label("Searching BoardGameGeek\u{2026}", systemImage: "magnifyingglass")
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            // Only show the results LIST while there isn't already a confirmed selection —
            // once picked, we show the single "selected game" card further below instead.
            if selectedGame == nil, !searchResults.isEmpty {
                VStack(spacing: 4) {
                    ForEach(searchResults) { game in
                        BGGSearchResultRow(game: game)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedGame = game
                                gameNameQuery = game.name
                                searchResults = []
                            }
                    }
                }
            }

            if let selectedGame {
                BGGSearchResultRow(game: selectedGame, isSelected: true)
            }
        }
    }

    private var playerCountSection: some View {
        VStack(spacing: 16) {
            Text("How many players?")
                .font(.system(.title2, design: .rounded).weight(.semibold))

            // The big number showing the currently selected player count.
            Text("\(playerCount)")
                .font(.system(size: 64, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.tint)

            // Minus / plus buttons instead of a text field or slider — keeps this screen
            // tap-friendly and avoids a keyboard popping up for a simple 1-8 choice.
            HStack(spacing: 40) {
                Button {
                    // Never let the count drop below the minimum this app supports.
                    if playerCount > minPlayers { playerCount -= 1 }
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 40))
                }
                .disabled(playerCount <= minPlayers)

                Button {
                    // Never let the count go above the maximum this app supports.
                    if playerCount < maxPlayers { playerCount += 1 }
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 40))
                }
                .disabled(playerCount >= maxPlayers)
            }
        }
        .padding(.vertical, 12)
    }

    // (Re)schedules a debounced BGG search for `query`. Cancelling the PREVIOUS task every
    // time this runs means only the LATEST keystroke's search actually reaches the network
    // — if the user is still typing, every earlier in-flight search gets thrown away before
    // it can return stale results.
    private func scheduleSearch(for query: String) {
        searchTask?.cancel()

        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else {
            searchResults = []
            isSearching = false
            return
        }

        searchTask = Task {
            // Waits briefly before actually searching, so quick typing doesn't fire a
            // network request after every single letter — only once typing pauses for a
            // moment (400 milliseconds here).
            try? await Task.sleep(nanoseconds: 400_000_000)
            guard !Task.isCancelled else { return }

            isSearching = true
            do {
                let results = try await BoardGameGeekService.searchWithThumbnails(query: trimmedQuery)
                guard !Task.isCancelled else { return }
                searchResults = results
            } catch {
                // BGG being unreachable (or the search simply failing) shouldn't block the
                // user from continuing — they can still just type a plain name with no BGG
                // match, so we quietly show no results rather than an alarming error.
                searchResults = []
            }
            isSearching = false
        }
    }

    // Builds the real GameSessionViewModel now that both game setup AND the first-player
    // picker have finished, and shows the live game.
    private func startGame(firstPlayerSeat: Int) {
        let newViewModel = GameSessionViewModel(
            players: PlayerRuntimeState.sampleData(count: playerCount),
            gameTitle: selectedGame?.name ?? (gameNameQuery.isEmpty ? nil : gameNameQuery),
            coverImageURL: selectedGame?.thumbnailURL,
            firstPlayerIndex: firstPlayerSeat
        )

        if isShowingFirstPlayerPicker {
            // Dismiss the first-player-picker cover first...
            isShowingFirstPlayerPicker = false

            // ...then, a moment later, present the real live game. Presenting a SECOND
            // full-screen cover in the same instant the first one is dismissing can make
            // SwiftUI fight over which transition to animate — this tiny delay lets the
            // picker's dismiss animation finish cleanly before the live game cover begins.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                activeGameViewModel = newViewModel
            }
        } else {
            // The picker was never shown (e.g. a solo, 1-player game skips it entirely) —
            // there's no cover to dismiss first, so just present the live game right away.
            activeGameViewModel = newViewModel
        }
    }
}

#Preview {
    NavigationStack {
        PlayerCountView()
    }
}

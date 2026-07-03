import SwiftUI

// PlayerCountView is the very first screen the user sees: "how many players are playing?"
// It's intentionally simple — a big number and two buttons — since this app favors icons
// and minimal text over dense forms and text fields.
struct PlayerCountView: View {
    // How many players are currently selected, from 1 to 8. `@State` tells SwiftUI to watch
    // this value and automatically redraw the view whenever it changes.
    @State private var playerCount: Int = 4

    // The smallest and largest number of players this app supports, matching the app's
    // requirements (games from 1 up to 8 players).
    private let minPlayers = 1
    private let maxPlayers = 8

    // Holds the view model for a game currently being played, or `nil` when no game is in
    // progress. Setting this to a real value is what triggers `.fullScreenCover(item:)`
    // below to appear; setting it back to `nil` (which SwiftUI does automatically when the
    // cover is dismissed) makes the cover go away.
    @State private var activeGameViewModel: GameSessionViewModel?

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // A simple board-game-flavored icon to lead with, since the app favors icons
            // over walls of text. "die.face.5.fill" is one of Apple's built-in dice-face
            // SF Symbols.
            Image(systemName: "die.face.5.fill")
                .font(.system(size: 56))
                .foregroundStyle(.tint)

            Text("How many players?")
                .font(.system(.title2, design: .rounded).weight(.semibold))

            // The big number showing the currently selected player count.
            Text("\(playerCount)")
                .font(.system(size: 72, weight: .bold, design: .rounded))
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
                        .font(.system(size: 44))
                }
                // Dim (rather than hide) the minus button once we're already at the
                // minimum, so it's visually clear why tapping it does nothing.
                .disabled(playerCount <= minPlayers)

                Button {
                    // Never let the count go above the maximum this app supports.
                    if playerCount < maxPlayers { playerCount += 1 }
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 44))
                }
                .disabled(playerCount >= maxPlayers)
            }

            Spacer()

            // Starting the game builds a fresh GameSessionViewModel (still with fake
            // sample players, since PlayerSetupView — for real names/icons/colors — doesn't
            // exist yet) and stores it, which triggers the fullScreenCover below to appear.
            // A real, running game uses a full-screen cover rather than a normal push so an
            // accidental swipe-back or nav-bar tap can't interrupt a live timer.
            Button {
                activeGameViewModel = GameSessionViewModel(players: PlayerRuntimeState.sampleData(count: playerCount))
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
        .padding()
        // `.fullScreenCover(item:)` shows LiveGameView full-screen whenever
        // `activeGameViewModel` holds a real value, and automatically sets it back to `nil`
        // (dismissing the cover) once LiveGameView calls its own `dismiss()` on the Summary
        // screen's "Done" button.
        .fullScreenCover(item: $activeGameViewModel) { viewModel in
            LiveGameView(viewModel: viewModel)
        }
    }
}

#Preview {
    NavigationStack {
        PlayerCountView()
    }
}

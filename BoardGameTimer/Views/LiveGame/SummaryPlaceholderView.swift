import SwiftUI

// SummaryPlaceholderView is a deliberately simple, TEMPORARY stand-in for the real
// SummaryView that Milestone 5 will build (with Swift Charts bars and SwiftData saving).
// For now, its only job is to prove that the game state machine actually REACHES the
// `.summary` phase correctly and to show the raw numbers, so Milestone 2's timer/turn logic
// can be checked end-to-end without waiting for persistence to exist.
struct SummaryPlaceholderView: View {
    // The finished (or early-ended) game's view model, read-only from here.
    let viewModel: GameSessionViewModel

    // Called when the user taps "Done" — LiveGameView passes in a closure that dismisses
    // this whole full-screen game session.
    let onDone: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "flag.checkered")
                .font(.system(size: 56))
                .foregroundStyle(.tint)

            Text("Game Over")
                .font(.system(.title, design: .rounded).weight(.semibold))

            // List each phase's final duration (Setup/Explanation/Cleanup), if it happened.
            // `GamePhase.allCases` keeps these in the same fixed order every time.
            VStack(alignment: .leading, spacing: 6) {
                ForEach(GamePhase.allCases.filter { $0 != .playing && $0 != .summary }, id: \.self) { phase in
                    if let duration = viewModel.perPhaseDurations[phase] {
                        HStack {
                            Text(phase.displayTitle)
                            Spacer()
                            Text(duration.asClockString).monospacedDigit()
                        }
                    }
                }
            }
            .font(.system(.body, design: .rounded))
            .padding(.horizontal, 40)

            Divider().padding(.horizontal, 40)

            // Every player's final total play time and how many turns they took.
            VStack(spacing: 10) {
                ForEach(viewModel.players) { player in
                    PlayerListRowView(player: player, elapsedTime: player.accumulatedPlayTime)
                }
            }
            .padding(.horizontal, 40)

            Spacer()

            Button(action: onDone) {
                Text("Done")
                    .font(.system(.headline, design: .rounded))
                    .frame(maxWidth: .infinity)
                    .padding()
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal, 40)
            .padding(.bottom, 24)
        }
        .padding(.top, 40)
    }
}

#Preview {
    let viewModel = GameSessionViewModel(players: PlayerRuntimeState.sampleData(count: 4))
    viewModel.endGameEarly() // jumps straight to .summary so the preview has something to show
    return SummaryPlaceholderView(viewModel: viewModel, onDone: {})
}

import SwiftUI

// PlayingPhaseListView is the Milestone 2 stand-in for the Playing phase, BEFORE the radial
// pie visual gets wired up in Milestone 3. It shows every player as a plain vertical list of
// rows instead of pie wedges, so the chess-clock turn-passing logic
// (`selectPlayer`/`passToNextPlayer`) can be tested and proven correct on its own, without
// also having to get the rotation/angle math right at the same time.
struct PlayingPhaseListView: View {
    // The view model driving turn state and per-player timers.
    let viewModel: GameSessionViewModel

    // The shared "current moment" for this redraw, passed down from LiveGameView's
    // TimelineView so every row's displayed time is calculated against the same instant.
    let now: Date

    // Called when the user taps "End Game Early."
    let onEndGameEarly: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: viewModel.currentPhase.sfSymbolName)
                    .foregroundStyle(.tint)
                Text(viewModel.currentPhase.displayTitle)
                    .font(.system(.title2, design: .rounded).weight(.semibold))
                Spacer()
                Button(role: .destructive, action: onEndGameEarly) {
                    Label("End Game", systemImage: "xmark.circle")
                        .font(.system(.subheadline, design: .rounded))
                }
            }
            .padding(.horizontal)
            .padding(.top)

            // One row per player, tapping a row directly makes that player active — this is
            // the "tap any player, not just the next one in order" gesture described in the
            // plan, useful for board games that don't strictly enforce turn order.
            ScrollView {
                VStack(spacing: 10) {
                    ForEach(Array(viewModel.players.enumerated()), id: \.element.id) { index, player in
                        PlayerListRowView(
                            player: player,
                            elapsedTime: viewModel.elapsedTime(for: player, at: now)
                        )
                        .onTapGesture {
                            viewModel.selectPlayer(at: index)
                        }
                    }
                }
                .padding(.horizontal)
            }

            // The big, unmissable "Pass Turn" button, for the common case of following
            // strict rotation order without needing to precisely tap the next row.
            Button {
                viewModel.passToNextPlayer()
            } label: {
                Label("Pass Turn", systemImage: "arrow.triangle.2.circlepath")
                    .font(.system(.headline, design: .rounded))
                    .frame(maxWidth: .infinity)
                    .padding()
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal)
            .padding(.bottom)
        }
    }
}

#Preview {
    // Build a sample view model, advance it straight into the Playing phase so the preview
    // shows this screen (rather than the Setup screen it would otherwise start on).
    let viewModel = GameSessionViewModel(players: PlayerRuntimeState.sampleData(count: 4))
    viewModel.advancePhase() // setup -> explanation
    viewModel.advancePhase() // explanation -> playing (also starts seat 0's clock)
    return PlayingPhaseListView(viewModel: viewModel, now: Date(), onEndGameEarly: {})
}

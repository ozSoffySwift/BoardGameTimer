import SwiftUI

// PlayingPieView is the REAL Milestone 3/4 Playing-phase screen: the signature full-screen
// radial pie layout, wired to the live GameSessionViewModel, with working turn-passing.
// This replaces PlayingPhaseListView (Milestone 2's plain-list stand-in) as what
// LiveGameView actually shows during `.playing` — PlayingPhaseListView's file is left in
// place unused, since it's still a useful reference for how the turn logic worked before
// the pie visual was reconnected to it.
struct PlayingPieView: View {
    // The view model driving turn state and per-player timers.
    let viewModel: GameSessionViewModel

    // The shared "current moment" for this redraw, passed down from LiveGameView's
    // TimelineView so the live-updating time shown for the active player stays perfectly in
    // sync with every other clock on screen.
    let now: Date

    // Called when the user taps "End Game Early."
    let onEndGameEarly: () -> Void

    var body: some View {
        // Build a copy of `viewModel.players` where the ACTIVE player's stored time is
        // replaced with their true LIVE elapsed time (accumulated time plus whatever's
        // ticked by since their turn started) — every other player's stored time is already
        // correct as-is, since only one clock runs at once. Handing this "topped-up" array
        // to PieLayoutView means PieLayoutView/PlayerWedgeView don't need to know anything
        // about live timers at all — they just display whatever numbers they're given,
        // exactly like they did with Milestone 1's fake, unmoving sample data.
        let displayPlayers = viewModel.players.map { player -> PlayerRuntimeState in
            var updated = player
            updated.accumulatedPlayTime = viewModel.elapsedTime(for: player, at: now)
            return updated
        }

        // Look up the active player's name for the center hub's secondary line, e.g.
        // "Alex" underneath their live-ticking time. Falls back to a generic label in the
        // (normally impossible) case there's no active player during the Playing phase.
        let activePlayerName = viewModel.activePlayerIndex
            .flatMap { displayPlayers.indices.contains($0) ? displayPlayers[$0].name : nil }
            ?? "No active player"

        let activePlayerElapsed = viewModel.activePlayerIndex
            .flatMap { displayPlayers.indices.contains($0) ? displayPlayers[$0].accumulatedPlayTime : nil }
            ?? 0

        ZStack {
            PieLayoutView(
                players: displayPlayers,
                activeSeatIndex: viewModel.activePlayerIndex,
                onWedgeTap: { tappedIndex in
                    // Tapping the CURRENTLY ACTIVE wedge means "I'm done" and passes the
                    // turn to whoever's next in clockwise order — tapping any OTHER wedge
                    // jumps the turn directly to that player instead, which matters for
                    // games that don't strictly go in seat order.
                    if tappedIndex == viewModel.activePlayerIndex {
                        viewModel.passToNextPlayer()
                    } else {
                        viewModel.selectPlayer(at: tappedIndex)
                    }
                },
                centerPrimaryText: activePlayerElapsed.asClockString,
                centerSecondaryText: activePlayerName
            )
            .ignoresSafeArea()

            // Phase controls sit ABOVE the full-bleed pie, inset from the edges so they're
            // never obscured by a notch/Dynamic Island/home indicator — the pie background
            // is allowed to run edge-to-edge, but tappable controls deliberately are not.
            VStack {
                HStack {
                    Spacer()
                    Button(role: .destructive, action: onEndGameEarly) {
                        Label("End Game", systemImage: "xmark.circle.fill")
                            .font(.system(.subheadline, design: .rounded))
                            .padding(10)
                            .background(.thinMaterial, in: Capsule())
                    }
                }
                .padding()

                Spacer()

                // The big, unmissable "Pass Turn" affordance — for the common case of
                // following strict rotation order without needing to precisely tap the
                // next wedge under time pressure.
                Button {
                    viewModel.passToNextPlayer()
                } label: {
                    Label("Pass Turn", systemImage: "arrow.triangle.2.circlepath")
                        .font(.system(.headline, design: .rounded))
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(.thinMaterial, in: Capsule())
                }
                .padding(.bottom, 24)
            }
        }
    }
}

#Preview {
    // Advance a sample view model straight into the Playing phase so the preview shows this
    // screen (rather than the Setup screen it would otherwise start on).
    let viewModel = GameSessionViewModel(players: PlayerRuntimeState.sampleData(count: 5))
    viewModel.advancePhase() // setup -> explanation
    viewModel.advancePhase() // explanation -> playing (also starts seat 0's clock)
    return PlayingPieView(viewModel: viewModel, now: Date(), onEndGameEarly: {})
}

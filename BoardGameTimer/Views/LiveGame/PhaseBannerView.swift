import SwiftUI

// PhaseBannerView is the simple, plain-layout screen shown during the Setup, Explanation,
// and Cleanup phases — the three phases that share ONE single timer for the whole group
// (there's no concept of individual players during these phases, unlike Playing).
//
// Milestone 2 deliberately keeps this layout plain (icon + text + buttons, stacked
// vertically) rather than anything fancy, so we can prove the timer logic itself is correct
// before layering the more complex radial pie visual on top in later milestones.
struct PhaseBannerView: View {
    // The view model that owns the actual timer state and phase-advancing logic. This view
    // only reads from it and calls its methods — it never manages time itself.
    let viewModel: GameSessionViewModel

    // The exact "current moment" for this redraw, handed down from the `TimelineView` in
    // LiveGameView. Using one shared `now` for every bit of UI in the same redraw keeps
    // everything perfectly in sync with itself.
    let now: Date

    // Called when the user taps "End Game Early." LiveGameView passes in a closure that
    // actually performs the action (and any screen dismissal), so this view doesn't need to
    // know HOW ending the game early works, just that it should ask for it.
    let onEndGameEarly: () -> Void

    var body: some View {
        VStack(spacing: 28) {
            // A small "End Game Early" control tucked in the top corner — present from every
            // phase, but deliberately small/out-of-the-way so it's not accidentally tapped
            // mid-game.
            HStack {
                Spacer()
                Button(role: .destructive, action: onEndGameEarly) {
                    Label("End Game", systemImage: "xmark.circle")
                        .font(.system(.subheadline, design: .rounded))
                }
                .padding()
            }

            Spacer()

            // Large icon representing whichever phase we're in (wrench for setup, speech
            // bubble for explanation, trash can for cleanup) — icon-forward per this app's
            // design language.
            Image(systemName: viewModel.currentPhase.sfSymbolName)
                .font(.system(size: 64))
                .foregroundStyle(.tint)

            Text(viewModel.currentPhase.displayTitle)
                .font(.system(.title, design: .rounded).weight(.semibold))

            // The big, live-updating elapsed time for this shared phase, formatted as
            // "M:SS" using the TimeFormatting helper. Recalculated fresh from
            // `phaseStartDate` every time this view redraws (driven by the TimelineView
            // ticking in LiveGameView), so it never drifts.
            Text(viewModel.currentPhaseElapsed(at: now).asClockString)
                .font(.system(size: 56, weight: .bold, design: .rounded))
                .monospacedDigit() // keeps digit widths fixed so the text doesn't jiggle
                .foregroundStyle(.tint)

            // Start/Pause toggle for the shared timer. The label switches between "Pause"
            // and "Start" depending on whether the timer is currently running, so the button
            // always describes what tapping it will DO next.
            Button {
                viewModel.toggleSharedTimer()
            } label: {
                Label(
                    viewModel.isSharedTimerRunning ? "Pause" : "Start",
                    systemImage: viewModel.isSharedTimerRunning ? "pause.fill" : "play.fill"
                )
                .font(.system(.headline, design: .rounded))
                .frame(maxWidth: .infinity)
                .padding()
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal, 40)

            Spacer()

            // Moves on to the next phase (Setup -> Explanation -> Playing -> Cleanup ->
            // Summary), freezing this phase's elapsed time along the way.
            Button {
                viewModel.advancePhase()
            } label: {
                Text("Next Phase")
                    .font(.system(.headline, design: .rounded))
                    .frame(maxWidth: .infinity)
                    .padding()
            }
            .buttonStyle(.bordered)
            .padding(.horizontal, 40)
            .padding(.bottom, 24)
        }
    }
}

#Preview {
    // A throwaway view model just for previewing this screen in isolation, with 4 fake
    // players (their identities don't matter for this particular screen).
    PhaseBannerView(
        viewModel: GameSessionViewModel(players: PlayerRuntimeState.sampleData(count: 4)),
        now: Date(),
        onEndGameEarly: {}
    )
}

import SwiftUI

// LiveGameView is the real top-level container for an in-progress game. It swaps its whole
// body depending on `viewModel.currentPhase`, and is responsible for actually driving the
// "redraw every fraction of a second so timers look alive" behavior using `TimelineView` —
// none of the child views (PhaseBannerView, PlayingPieView, etc.) manage timing themselves;
// they just receive an already-decided `now` and display it.
//
// This replaces LiveGameDemoView (the Milestone-1 throwaway) as the screen that's actually
// shown after Continue is tapped. LiveGameDemoView's file is left in place as a reference
// for how the pie visual originally worked with fake, unmoving sample data.
struct LiveGameView: View {
    // The single source of truth for this game's phase/timer/turn state.
    let viewModel: GameSessionViewModel

    // Lets this view close itself. Used when the user taps "Done" on the Summary screen,
    // dismissing the `.fullScreenCover` this view was presented in, back to PlayerCountView.
    @Environment(\.dismiss) private var dismiss

    // Read from the Settings screen (see SettingsView.swift) — whether the phone's screen
    // should be prevented from auto-locking while a game is in progress.
    @AppStorage("keepScreenAwakeDuringGames") private var keepScreenAwakeDuringGames = true

    var body: some View {
        // `TimelineView(.periodic(from:by:))` asks SwiftUI to re-run the closure below on a
        // fixed schedule (every 0.2 seconds here) — this is what makes the on-screen timer
        // text visibly tick upward, without us writing any manual `Timer`/Combine code.
        // `timelineContext.date` is the "now" for that particular tick; passing the SAME
        // `now` down to every child view keeps all of this screen's time displays perfectly
        // consistent with each other, even though the underlying calculation
        // (`accumulated + time since start`) never actually stores "now" anywhere.
        TimelineView(.periodic(from: .now, by: 0.2)) { timelineContext in
            phaseContent(now: timelineContext.date)
        }
        // `UIApplication.shared.isIdleTimerDisabled` is the system-wide switch that tells
        // iOS "don't auto-lock the screen right now" — normally iOS locks the screen after
        // a short period of no touches, which would be disruptive mid-game. We turn this ON
        // the moment this screen appears, and — very importantly — turn it back OFF when
        // this screen disappears, so leaving a game doesn't accidentally leave the ENTIRE
        // REST OF THE APP unable to auto-lock, wasting battery forever.
        .onAppear {
            if keepScreenAwakeDuringGames {
                UIApplication.shared.isIdleTimerDisabled = true
            }
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
        }
    }

    // Picks which screen to show based on the current phase. Kept as its own small function
    // (rather than inline in `body`) just to keep `body` easy to read.
    @ViewBuilder
    private func phaseContent(now: Date) -> some View {
        switch viewModel.currentPhase {
        case .setup, .explanation, .cleanup:
            // These three phases all share the exact same single-timer banner UI — only the
            // icon/title text differs, and that's handled inside PhaseBannerView itself by
            // reading `viewModel.currentPhase`.
            PhaseBannerView(viewModel: viewModel, now: now, onEndGameEarly: viewModel.endGameEarly)
        case .playing:
            // The real signature radial pie layout, wired to live turn/timer state.
            PlayingPieView(viewModel: viewModel, now: now, onEndGameEarly: viewModel.endGameEarly)
        case .summary:
            // Dismiss this whole full-screen game session when "Done" is tapped, back to
            // wherever LiveGameView was presented from (PlayerCountView, for now).
            SummaryPlaceholderView(viewModel: viewModel, onDone: { dismiss() })
        }
    }
}

#Preview {
    LiveGameView(viewModel: GameSessionViewModel(players: PlayerRuntimeState.sampleData(count: 4)))
}

import SwiftUI

// LiveGameDemoView is a TEMPORARY Milestone-1 screen. Its only purpose is to show the pie
// layout full-screen with realistic-looking fake data, so we can see (and fix) the wedge
// angle math before any real timers or turn logic exist.
//
// Starting in Milestone 2, this will be replaced by the real `LiveGameView`, which switches
// between Setup / Explanation / Playing / Cleanup / Summary based on a
// GameSessionViewModel, instead of always just showing the pie with fake data.
struct LiveGameDemoView: View {
    // How many players to fake — passed in from PlayerCountView's stepper, so this demo at
    // least reflects the number the user picked, even though the players themselves (names,
    // colors, times) are still fake for now.
    let playerCount: Int

    var body: some View {
        PieLayoutView(players: PlayerRuntimeState.sampleData(count: playerCount))
            // The pie is meant to use the ENTIRE screen edge-to-edge, like a tabletop
            // display sitting in the middle of the table, so we deliberately ignore the
            // safe area here. (Once real phase-control buttons are added in later
            // milestones, THOSE will get their own manual padding so they never sit under a
            // notch/Dynamic Island — but the wedge background itself is allowed to run
            // full-bleed to the screen edges.)
            .ignoresSafeArea()
            // Hides the default navigation bar title so it doesn't clutter this full-bleed
            // screen with unwanted text.
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle("")
    }
}

#Preview {
    NavigationStack {
        LiveGameDemoView(playerCount: 5)
    }
}

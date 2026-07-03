import SwiftUI

// CenterHubView is the circle in the very middle of the pie. It sits on top of every wedge
// and shows the "big picture" info. Right now (Milestone 1) it just displays whatever fixed
// placeholder text is passed in, but from Milestone 2 onward this is where the shared phase
// timer or the currently-active player's name/time will actually be shown live.
struct CenterHubView: View {
    // The main line of text in the hub, e.g. "Playing" or a running time like "1:07".
    let primaryText: String

    // Smaller supporting text underneath, e.g. "4 players" or "Tap a wedge to pass the turn".
    let secondaryText: String

    // How wide (and tall — it's a circle, so width and height are equal) the hub should be,
    // in points. Passed in by the parent so it can size the hub relative to the whole pie.
    let diameter: CGFloat

    var body: some View {
        VStack(spacing: 4) {
            Text(primaryText)
                .font(.system(.title2, design: .rounded).weight(.bold))
                .monospacedDigit() // keeps digits a fixed width so a running timer doesn't jiggle
                .lineLimit(1)
                .minimumScaleFactor(0.5) // shrink rather than truncate if the text is too wide

            Text(secondaryText)
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
        }
        .padding(12)
        .frame(width: diameter, height: diameter)
        // A solid system background circle so the hub visually "punches through" the middle
        // of the pie, right where every wedge's pointed inner corner meets.
        .background(Circle().fill(Color(.systemBackground)))
        .overlay(Circle().stroke(Color(.separator), lineWidth: 1))
        // A soft shadow lifts the hub visually above the flat wedges underneath — part of
        // the "elegant, modern" look this app is going for, rather than a flat pie chart.
        .shadow(radius: 6)
    }
}

import SwiftUI

// WedgeShape draws ONE slice of the pie — the background shape for a single player's seat.
//
// Conforming to SwiftUI's `Shape` protocol means we only need to describe the outline (the
// `path` function below); SwiftUI takes care of filling it with color, stroking its edge,
// hit-testing taps against it, animating size changes, and so on.
struct WedgeShape: Shape {
    // Which seat this wedge represents (0 = first seat, 1 = second seat, and so on).
    let seatIndex: Int

    // How many players/seats are in the whole pie right now. Needed to know how wide (in
    // degrees) each wedge should be — e.g. 4 players means 4 wedges of 90 degrees each.
    let totalPlayers: Int

    // SwiftUI calls this function whenever it needs to know the actual shape to draw,
    // passing in `rect` — the rectangle of screen space this shape has been given to fill.
    func path(in rect: CGRect) -> Path {
        var path = Path()

        // Guard against dividing by zero if this is ever accidentally asked to draw a pie
        // with 0 players.
        guard totalPlayers > 0 else { return path }

        // Each wedge gets an equal share of the full 360-degree circle.
        let anglePerWedge = 360.0 / Double(totalPlayers)

        // We measure angles starting from the 12 o'clock position and increasing clockwise
        // as seatIndex goes up. SwiftUI's own angle convention normally starts at 3 o'clock
        // (like a standard math graph), so subtracting 90 degrees below rotates our zero
        // point from 3 o'clock to 12 o'clock instead.
        //
        // IMPORTANT: this exact "-90, increasing clockwise" convention is reused in
        // PieLayoutView to position and rotate each wedge's text/icon content. Both places
        // MUST use the same convention, or the content will drift out of alignment with its
        // own wedge — this mismatch is the single most common bug in radial layouts like this.
        let startDegrees = Double(seatIndex) * anglePerWedge - 90
        let endDegrees = startDegrees + anglePerWedge

        // The exact center point of the space we've been given.
        let center = CGPoint(x: rect.midX, y: rect.midY)

        // The radius of the whole pie: the smaller of width/height (so it always fits as a
        // circle even on a non-square screen), minus a small margin so the outer edge isn't
        // literally touching the edge of the screen.
        let edgeMargin: CGFloat = 4
        let radius = min(rect.width, rect.height) / 2 - edgeMargin

        // Draw the wedge exactly like you'd draw a slice of pie by hand: start at the
        // center point, draw a straight line out to the edge of the circle at the start
        // angle (this happens automatically as part of `addArc` below), sweep an arc around
        // to the end angle, then close the shape back to the center.
        path.move(to: center)
        path.addArc(
            center: center,
            radius: radius,
            startAngle: .degrees(startDegrees),
            endAngle: .degrees(endDegrees),
            // `clockwise: false` looks backwards, but SwiftUI's coordinate system has Y
            // increasing DOWNWARD on screen (unlike a normal math graph), which flips the
            // usual meaning of "clockwise" here. `false` is what actually produces a
            // clockwise-looking sweep on screen for our "increasing angle = clockwise"
            // convention above — this matches the standard technique used in SwiftUI pie
            // chart tutorials.
            clockwise: false
        )
        path.closeSubpath()

        return path
    }
}

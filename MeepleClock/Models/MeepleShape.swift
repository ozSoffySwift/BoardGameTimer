import SwiftUI

// MeepleShape draws the classic board-game "meeple" (little person) silhouette used
// throughout the app as each player's avatar — the Carcassonne pawn: a round head flowing
// into sloped shoulders, stubby rounded arms, and two legs under a rounded arch.
//
// The whole figure is drawn in a 100x120 design box and then scaled in ONE step to whatever
// size the view is given (see the transform at the bottom). Building it that way — rather
// than converting each point as it's written — means the head can be a true circular arc
// instead of hand-converted curve points, and the head/shoulder seam stays exact at any size.
struct MeepleShape: Shape {
    // --- The head, in design coordinates ---

    // Center and radius of the head circle.
    private static let headCenter = CGPoint(x: 50, y: 18)
    private static let headRadius: CGFloat = 15

    // The head is NOT a full circle: it's an arc that stops partway down each side, and the
    // 80-degree slice left undrawn along the bottom is where the neck meets the shoulders.
    // 130 degrees is the lower-LEFT of the head (in SwiftUI's flipped-Y angles, 90 points
    // straight DOWN and 180 points left, so 130 sits at about 7 o'clock); the arc sweeps from
    // there clockwise over the top to 410 (= 50, the mirrored lower-RIGHT at 5 o'clock).
    //
    // That undrawn slice is what makes this read as a meeple rather than a gingerbread man:
    // it leaves a neck about two thirds the width of the head, and the small concave notch
    // where the head's underside meets the shoulder line is a real meeple's most recognizable
    // feature.
    private static let headStartDegrees: CGFloat = 130
    private static let headEndDegrees: CGFloat = 410

    // Where that arc begins — the point the body's outline must come back to so the path
    // closes seamlessly. Computed from the angle rather than typed in, so the seam is exact.
    private static var neckLeft: CGPoint {
        let radians = headStartDegrees * .pi / 180
        return CGPoint(
            x: headCenter.x + headRadius * cos(radians),
            y: headCenter.y + headRadius * sin(radians)
        )
    }

    // SwiftUI calls this to get the outline to draw, handing us `rect` — the actual
    // on-screen space this shape has been given.
    func path(in rect: CGRect) -> Path {
        var path = Path()

        // A local shorthand so the long list of body coordinates below stays readable.
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x, y: y) }

        // --- Head ---
        // Start at the lower-left of the head and sweep over the top to the lower-right.
        // `clockwise: false` is what produces a visually clockwise sweep in SwiftUI's
        // flipped-Y coordinates (the same quirk the pie wedges in TimerActiveView rely on).
        path.move(to: Self.neckLeft)
        path.addArc(
            center: Self.headCenter,
            radius: Self.headRadius,
            startAngle: .degrees(Self.headStartDegrees),
            endAngle: .degrees(Self.headEndDegrees),
            clockwise: false
        )

        // --- Body, continuing from where the arc left off (the head's lower-right) and
        //     travelling down the right side, across the feet, and back up the left ---

        // Right shoulder: a long, barely-concave diagonal running from the neck out and
        // down to the top of the arm — a meeple has no shoulder shelf, the arm simply
        // spreads straight out of the neck.
        path.addQuadCurve(to: p(80, 52), control: p(67, 38))
        // Right arm: around the blunt rounded stub at the end.
        path.addQuadCurve(to: p(77, 64), control: p(86, 62))
        // Right underarm: a short, sharp cut back in to the waist.
        path.addQuadCurve(to: p(64, 66), control: p(71, 68))
        // Right flank: down the torso, flaring gently out to the hip.
        path.addQuadCurve(to: p(72, 108), control: p(66, 86))
        // Rounded bottom-right corner, then the flat base of the right foot.
        path.addQuadCurve(to: p(68, 118), control: p(72, 117))
        path.addLine(to: p(58, 118))
        // Inner edge of the right foot, turning upward.
        path.addQuadCurve(to: p(56, 108), control: p(56, 118))

        // The gap between the legs: a rounded arch rather than a sharp V. Both control
        // points sit directly above their own end point, so each inner leg edge rises
        // straight before the curve rounds over at the top.
        path.addCurve(to: p(44, 108), control1: p(56, 80), control2: p(44, 80))

        // --- The left side, mirroring the right (every x below is 100 minus its twin) ---
        path.addQuadCurve(to: p(42, 118), control: p(44, 118))
        path.addLine(to: p(32, 118))
        path.addQuadCurve(to: p(28, 108), control: p(28, 117))
        path.addQuadCurve(to: p(36, 66), control: p(34, 86))
        path.addQuadCurve(to: p(23, 64), control: p(29, 68))
        path.addQuadCurve(to: p(20, 52), control: p(14, 62))
        // Back into the exact point the head arc started from, closing the silhouette.
        path.addQuadCurve(to: Self.neckLeft, control: p(33, 38))
        path.closeSubpath()

        // --- Scale the finished design-space outline into the space we were given ---
        // Applying one transform at the end (instead of converting every point as it's
        // written) is what lets the head above be a real circular arc.
        return path.applying(
            CGAffineTransform(translationX: rect.minX, y: rect.minY)
                .scaledBy(x: rect.width / 100, y: rect.height / 120)
        )
    }
}

// MeepleView is the ready-to-use avatar: the meeple shape filled with a player's gradient,
// with the drop shadow the design gives it. Kept as its own small view so every screen
// (setup rows, wedge labels, results, swatches) renders meeples identically.
struct MeepleView: View {
    // Which of the ten palette gradients to fill with.
    let colorIndex: Int

    var body: some View {
        MeepleShape()
            .fill(MeeplePalette.gradient(colorIndex))
            .shadow(color: .black.opacity(0.4), radius: 3, y: 2)
            // The meeple's natural proportions are 100 wide : 120 tall — keeping that
            // aspect ratio means callers only need to set ONE dimension via .frame and the
            // other follows, so meeples never look squashed.
            .aspectRatio(100.0 / 120.0, contentMode: .fit)
    }
}

#Preview {
    VStack(spacing: 24) {
        // One meeple per palette color, to eyeball the whole set at once.
        HStack(spacing: 12) {
            ForEach(0..<10) { index in
                MeepleView(colorIndex: index)
                    .frame(width: 30)
            }
        }
        // The sizes the app actually draws at, largest to smallest, to check the silhouette
        // still reads when it's tiny (28pt is an inactive wedge label).
        HStack(alignment: .bottom, spacing: 20) {
            ForEach([72.0, 46.0, 40.0, 28.0], id: \.self) { width in
                MeepleView(colorIndex: 0)
                    .frame(width: width)
            }
        }
    }
    .padding()
    .background(MeeplePalette.background)
}

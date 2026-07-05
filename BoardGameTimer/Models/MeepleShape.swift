import SwiftUI

// MeepleShape draws the classic board-game "meeple" (little person) silhouette used
// throughout the redesigned app as each player's avatar. The outline is ported point-for-
// point from the design file's SVG: a circle for the head plus one closed polygon for the
// body/arms/legs, drawn in a 100x120 coordinate box and scaled to whatever size the view
// is given.
struct MeepleShape: Shape {
    // SwiftUI calls this to get the outline to draw, handing us `rect` — the actual
    // on-screen space this shape has been given.
    func path(in rect: CGRect) -> Path {
        var path = Path()

        // The design's meeple was drawn inside a 100-wide by 120-tall box; dividing the
        // real width/height by those gives the scale factors that stretch the original
        // coordinates to fill whatever size this view actually is.
        let sx = rect.width / 100
        let sy = rect.height / 120

        // A tiny helper so every point below can be written in the ORIGINAL design
        // coordinates and converted in one place, instead of sprinkling math everywhere.
        func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + x * sx, y: rect.minY + y * sy)
        }

        // The head: a circle of radius 16 centered at (50, 18) in design coordinates.
        // (An ellipse rect is its bounding box, hence center minus radius on both axes.)
        path.addEllipse(in: CGRect(
            x: rect.minX + (50 - 16) * sx,
            y: rect.minY + (18 - 16) * sy,
            width: 32 * sx,
            height: 32 * sy
        ))

        // The body: the design SVG's polygon points, copied in order. Straight lines only,
        // so it's just a move-to followed by line-to's and a close.
        let bodyPoints: [(CGFloat, CGFloat)] = [
            (41, 32), (41, 38), (20, 38), (8, 42), (6, 58), (18, 62), (30, 50),
            (30, 74), (12, 80), (8, 108), (30, 112), (36, 90), (50, 98), (64, 90),
            (70, 112), (92, 108), (88, 80), (70, 74), (70, 50), (82, 62), (94, 58),
            (92, 42), (80, 38), (59, 38), (59, 32),
        ]
        path.move(to: pt(bodyPoints[0].0, bodyPoints[0].1))
        // `dropFirst()` skips the first point (already used by `move`) and draws a line to
        // each remaining point in turn.
        for (x, y) in bodyPoints.dropFirst() {
            path.addLine(to: pt(x, y))
        }
        path.closeSubpath()

        return path
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
    HStack(spacing: 12) {
        // One meeple per palette color, to eyeball the whole set at once.
        ForEach(0..<10) { index in
            MeepleView(colorIndex: index)
                .frame(width: 30)
        }
    }
    .padding()
    .background(MeeplePalette.background)
}

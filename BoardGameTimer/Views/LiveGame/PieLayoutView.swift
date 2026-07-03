import SwiftUI

// PieLayoutView arranges every player's wedge and content into a single circular, table-like
// layout that fills the available screen space — this is the app's signature visual.
//
// The core idea: imagine the phone lying flat in the middle of a table, with players sitting
// all the way around it. Each player gets an equal pie slice, and the icon/name/time inside
// their slice is rotated so it reads right-side-up FROM THEIR SEAT — not from the top of the
// phone — like a lazy Susan.
struct PieLayoutView: View {
    // The players to display, already in seat order (seatIndex 0, 1, 2, ...).
    let players: [PlayerRuntimeState]

    var body: some View {
        // GeometryReader tells us exactly how much screen space we have to work with, via
        // `geometry.size`. All of the circle/angle math below depends on knowing this size,
        // so GeometryReader has to wrap everything else in this view.
        GeometryReader { geometry in
            // The pie's usable width/height is the smaller of the two, so it always fits as
            // a perfect circle even on a non-square screen area.
            let side = min(geometry.size.width, geometry.size.height)
            let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)

            ZStack {
                // --- Layer 1: every player's wedge shape, filled with their color ---
                //
                // `Array(players.enumerated())` pairs each player up with its position in
                // the array (0, 1, 2, ...), which we use directly as the seat index. This
                // assumes `players` is already sorted by seat — PieLayoutView doesn't
                // re-sort it itself.
                ForEach(Array(players.enumerated()), id: \.element.id) { index, player in
                    WedgeShape(seatIndex: index, totalPlayers: players.count)
                        // `.gradient` adds a subtle shine across the flat color, part of
                        // the "elegant, modern" look rather than a flat pie-chart color.
                        .fill(player.color.gradient)
                        // A thin background-colored stroke between wedges makes each seat
                        // read as visually separate, like real slices of a pie, instead of
                        // one solid blob of color.
                        .overlay(
                            WedgeShape(seatIndex: index, totalPlayers: players.count)
                                .stroke(Color(.systemBackground), lineWidth: 3)
                        )
                        // IMPORTANT: the tap gesture lives on the wedge SHAPE itself (which
                        // is never rotated), not on the rotated text/icon content in Layer 2
                        // below. That keeps the tappable area exactly matching the visible
                        // pie slice — rotating a view can make its tap target behave in
                        // surprising ways, so we deliberately keep taps on the unrotated shape.
                        .onTapGesture {
                            // Milestone 4 will replace this placeholder with a real call like
                            // `viewModel.selectPlayer(at: index)` to actually pass the turn.
                            print("Tapped seat \(index): \(player.name)")
                        }
                }

                // --- Layer 2: each player's name/icon/time content, positioned and rotated
                //     so it reads correctly from that seat's point of view ---
                ForEach(Array(players.enumerated()), id: \.element.id) { index, player in
                    let anglePerWedge = 360.0 / Double(players.count)

                    // The angle pointing at the exact middle of this player's wedge, using
                    // the same "-90 = start from 12 o'clock, increasing clockwise"
                    // convention as WedgeShape. This MUST match WedgeShape's math exactly,
                    // or this content will drift out of alignment with its own wedge.
                    let centerAngleDegrees = Double(index) * anglePerWedge + anglePerWedge / 2 - 90
                    let centerAngleRadians = centerAngleDegrees * .pi / 180

                    // How far from the center to place the content: about 68% of the way
                    // out to the edge, so it sits comfortably mid-slice — close enough to
                    // visually "belong" to its wedge, far enough not to crowd the center hub.
                    let contentRadius = (side / 2) * 0.68

                    PlayerWedgeView(player: player)
                        // `cos`/`sin` convert an angle into an (x, y) direction. Because
                        // this screen's Y axis increases DOWNWARD (like all iOS screens),
                        // this formula naturally places larger angles further clockwise,
                        // matching the same convention used for the wedge shapes above.
                        .position(
                            x: center.x + contentRadius * cos(centerAngleRadians),
                            y: center.y + contentRadius * sin(centerAngleRadians)
                        )
                        // Rotating by (centerAngleDegrees - 90) is the piece of math that
                        // makes the whole "lazy Susan" idea work: it points this content's
                        // "up" direction away from wherever that seat's player is sitting,
                        // which is what makes the text look upright TO THEM.
                        //
                        // For seats on the far side of the pie, this rotation will look
                        // genuinely upside-down to YOU looking at the phone head-on — that
                        // is correct and intentional, not a bug. Don't "fix" this by
                        // clamping the rotation angle; doing so would defeat the entire
                        // point of the radial, sit-anywhere-around-the-table layout.
                        .rotationEffect(.degrees(centerAngleDegrees - 90))
                }

                // --- Layer 3: the center hub, always drawn LAST so it appears on top of
                //     every wedge, covering the point where all the slices meet ---
                CenterHubView(
                    primaryText: "Playing",
                    secondaryText: "\(players.count) players",
                    diameter: side * 0.28
                )
                .position(center)
            }
        }
    }
}

#Preview {
    // Preview with 4 fake players — change this number in Xcode's canvas to spot-check
    // other player counts (try 8 to see how crowded the wedges get, per the Milestone 3
    // testing note).
    PieLayoutView(players: PlayerRuntimeState.sampleData(count: 4))
}

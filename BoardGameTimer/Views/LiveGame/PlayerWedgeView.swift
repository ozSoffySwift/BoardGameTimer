import SwiftUI

// PlayerWedgeView is the small "card" of content (icon + name + time) that sits on top of
// one player's pie slice. It does NOT know or care about rotation or where on the pie it
// is — that positioning/rotation is handled entirely by the parent view (PieLayoutView).
// This view's only job is to lay out the icon, name, and time nicely in a small stack.
struct PlayerWedgeView: View {
    // The player this piece of content belongs to. `let` because this view never changes
    // it — it only displays it.
    let player: PlayerRuntimeState

    var body: some View {
        VStack(spacing: 4) {
            // The player's SF Symbol icon, shown large since this app favors icons over
            // walls of text.
            Image(systemName: player.sfSymbolName)
                .font(.system(size: 28, weight: .semibold))

            // The player's name. `.lineLimit(1)` + `.minimumScaleFactor` stop long names
            // from wrapping onto a second line or spilling outside the wedge — instead the
            // text shrinks to fit, which matters a lot once there are 7 or 8 thin wedges.
            Text(player.name)
                .font(.system(.headline, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            // The player's accumulated play time, formatted as "M:SS" using the helper we
            // wrote in TimeFormatting.swift.
            Text(player.accumulatedPlayTime.asClockString)
                .font(.system(.subheadline, design: .rounded))
                // Keeps every digit the same width, so the displayed time doesn't visually
                // "jiggle" left and right as the numbers change each second.
                .monospacedDigit()
        }
        .foregroundStyle(.white)
        // A little padding plus a translucent dark backing keeps this text readable no
        // matter what color the wedge underneath happens to be.
        .padding(8)
        .background(.black.opacity(0.18), in: RoundedRectangle(cornerRadius: 12))
        // If this player is mid-turn, draw a bright border around their content as an extra
        // "this is who's up right now" signal, on top of whatever highlight the wedge shape
        // itself gets added to it in later milestones.
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(.white, lineWidth: player.isActiveTurn ? 3 : 0)
        )
    }
}

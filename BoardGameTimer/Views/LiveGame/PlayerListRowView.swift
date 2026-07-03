import SwiftUI

// PlayerListRowView draws ONE player as a single row in the plain (non-pie) Playing-phase
// list used by Milestone 2. It's the list-layout equivalent of PlayerWedgeView — same idea
// (icon, name, time), just arranged as a horizontal row instead of content inside a pie
// slice.
struct PlayerListRowView: View {
    // The player this row displays.
    let player: PlayerRuntimeState

    // This player's current elapsed time, already calculated by the view model (including
    // live time if it's their turn right now) — this view just displays it, it doesn't
    // compute it.
    let elapsedTime: TimeInterval

    var body: some View {
        HStack(spacing: 16) {
            // The player's SF Symbol icon, tinted with their assigned color so the list
            // still reads as "color-coded per player" even without the pie visual.
            Image(systemName: player.sfSymbolName)
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(player.color)
                .frame(width: 36)

            Text(player.name)
                .font(.system(.headline, design: .rounded))

            Spacer()

            // How many turns this player has taken so far, e.g. "Turn 3".
            Text("Turn \(player.turnCount)")
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(.secondary)

            // This player's running time, formatted "M:SS".
            Text(elapsedTime.asClockString)
                .font(.system(.headline, design: .rounded))
                .monospacedDigit() // fixed digit width so the time doesn't jiggle as it ticks
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 16)
        // Highlight the whole row with a tinted background when it's this player's turn,
        // so "who is active right now" is obvious even glancing quickly at the list.
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(player.isActiveTurn ? player.color.opacity(0.18) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(player.isActiveTurn ? player.color : Color(.separator), lineWidth: player.isActiveTurn ? 2 : 1)
        )
    }
}

#Preview {
    VStack(spacing: 8) {
        ForEach(PlayerRuntimeState.sampleData(count: 4)) { player in
            PlayerListRowView(player: player, elapsedTime: player.accumulatedPlayTime)
        }
    }
    .padding()
}

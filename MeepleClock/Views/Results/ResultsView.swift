import SwiftUI

// ResultsView is the finished-game summary from the redesign: the game's name/date/rounds,
// each player's total time (with a crown next to the winner — whoever used the LEAST
// time), a share button producing a plain-text summary, and Done (fresh game) or Close
// (browsing history) depending on how it was reached.
struct ResultsView: View {
    // The finished game being displayed — either just-ended, or loaded from history.
    let record: GameRecord

    // True when opened from history (Statistics/Recent Games): shows "Close" instead of
    // "Done" since there's no live game flow to finish.
    let isReadOnly: Bool

    // What Done should do when this wraps a just-finished game (dismiss the game cover).
    var onDone: (() -> Void)? = nil

    // Lets the read-only version close its own sheet.
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                // --- Header: game name, date, rounds ---
                VStack(alignment: .leading, spacing: 2) {
                    Text(record.gameName)
                        .font(.system(size: 24, weight: .heavy))
                        .foregroundStyle(.white)
                    Text("\(record.dateLabel) \u{00B7} Round \(record.rounds)")
                        .font(.system(size: 13))
                        .foregroundStyle(MeeplePalette.textSecondary)
                    // Countdown games say so, and say what the bank was — without it, a row
                    // reading "9:12" gives no sense of whether that was fast or slow.
                    if let modeCaption = record.modeCaption {
                        Text(modeCaption)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(MeeplePalette.silver)
                    }
                }
                .padding(.top, 6)

                // --- One row per player, winner crowned ---
                VStack(spacing: 10) {
                    ForEach(Array(record.players.enumerated()), id: \.offset) { index, player in
                        HStack(spacing: 12) {
                            MeepleView(colorIndex: player.colorIndex)
                                .frame(width: 34)
                            HStack(spacing: 6) {
                                Text(player.name)
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(.white)
                                // The crown marks the fastest player (least time used).
                                if index == record.winnerIndex {
                                    Image(systemName: "crown.fill")
                                        .font(.system(size: 13))
                                        .foregroundStyle(Color(hex: 0xFFD60A))
                                }
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 1) {
                                Text(TimeInterval(player.secondsUsed).asClockString)
                                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                                    .foregroundStyle(MeeplePalette.silver)
                                // Countdown games add what was LEFT underneath, in red for
                                // anyone who went past their bank.
                                if let remaining = record.secondsRemaining(for: index) {
                                    Text("\(TimeInterval(remaining).asSignedClockString) left")
                                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                                        .foregroundStyle(remaining < 0 ? MeeplePalette.overtimeRed : MeeplePalette.textSecondary)
                                }
                            }
                        }
                        .padding(.vertical, 12)
                        .padding(.horizontal, 14)
                        .background(MeeplePalette.card, in: RoundedRectangle(cornerRadius: 14))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(MeeplePalette.silver.opacity(0.12), lineWidth: 1)
                        )
                    }
                }

                // --- Share: hands the plain-text summary to the system share sheet ---
                ShareLink(item: record.shareText) {
                    HStack(spacing: 8) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(MeeplePalette.silver)
                        Text("Share Summary")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Color(hex: 0x1C1D20), in: RoundedRectangle(cornerRadius: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(MeeplePalette.silver.opacity(0.3), lineWidth: 1)
                    )
                }
                .padding(.top, 6)

                // --- Done (fresh game) or Close (history browsing) ---
                if isReadOnly {
                    Button {
                        dismiss()
                    } label: {
                        Text("Close")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(Color(hex: 0x1C1D20), in: RoundedRectangle(cornerRadius: 14))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(MeeplePalette.silver.opacity(0.3), lineWidth: 1)
                            )
                    }
                } else {
                    Button {
                        onDone?()
                    } label: {
                        Text("Done")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(MeeplePalette.background)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(MeeplePalette.silverGradient, in: RoundedRectangle(cornerRadius: 14))
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .background(MeeplePalette.background)
    }
}

#Preview("Stopwatch") {
    ResultsView(
        record: GameRecord(
            date: Date(),
            gameName: "Catan Night",
            rounds: 6,
            players: [
                PlayerResult(name: "Alex", colorIndex: 0, secondsUsed: 312),
                PlayerResult(name: "Sam", colorIndex: 1, secondsUsed: 195),
                PlayerResult(name: "Riley", colorIndex: 3, secondsUsed: 428),
            ]
        ),
        isReadOnly: false
    )
    .preferredColorScheme(.dark)
}

// Riley is deliberately over their 10-minute bank, so the negative "left" row is visible.
#Preview("Countdown") {
    ResultsView(
        record: GameRecord(
            date: Date(),
            gameName: "Chess Night",
            rounds: 6,
            players: [
                PlayerResult(name: "Alex", colorIndex: 0, secondsUsed: 312),
                PlayerResult(name: "Sam", colorIndex: 1, secondsUsed: 195),
                PlayerResult(name: "Riley", colorIndex: 3, secondsUsed: 664),
            ],
            mode: .countdown,
            totalTimePerPlayerSeconds: 600
        ),
        isReadOnly: false
    )
    .preferredColorScheme(.dark)
}

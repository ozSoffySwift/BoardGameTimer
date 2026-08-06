import SwiftUI
import SwiftData

// StatisticsView is the redesigned history tab: every saved game as a card (name, date, a
// row of colored dots — one per player — and the player/round counts), newest first.
// Tapping a card opens that game's results read-only. With no history yet, a friendly
// empty state shows instead.
struct StatisticsView: View {
    // All saved games, newest first, kept live by SwiftData — a game saved on the Timer
    // tab appears here immediately with no refresh code.
    @Query(sort: \GameRecord.date, order: .reverse) private var history: [GameRecord]

    // The tapped record being viewed read-only, or nil.
    @State private var viewingRecord: GameRecord?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Statistics")
                    .font(.system(size: 30, weight: .heavy))
                    .foregroundStyle(.white)
                    .padding(.top, 6)

                if history.isEmpty {
                    // --- Empty state: a ghosted meeple + hint text ---
                    VStack(spacing: 14) {
                        MeepleView(colorIndex: 9)
                            .frame(width: 72)
                            .opacity(0.15)
                        Text("No games played yet.\nStart a timer to see history here.")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(MeeplePalette.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 80)
                } else {
                    // --- One card per saved game ---
                    ForEach(history) { record in
                        Button {
                            viewingRecord = record
                        } label: {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text(record.gameName)
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundStyle(.white)
                                    Spacer()
                                    Text(record.dateLabel)
                                        .font(.system(size: 12))
                                        .foregroundStyle(MeeplePalette.textSecondary)
                                }
                                HStack(spacing: 8) {
                                    // One small gradient dot per player, in seat order.
                                    ForEach(Array(record.players.enumerated()), id: \.offset) { _, player in
                                        Circle()
                                            .fill(MeeplePalette.gradient(player.colorIndex))
                                            .frame(width: 12, height: 12)
                                    }
                                    Text("\(record.playerCountLabel) \u{00B7} \(record.roundsLabel)")
                                        .font(.system(size: 12))
                                        .foregroundStyle(MeeplePalette.textSecondary)
                                        .padding(.leading, 4)
                                }
                            }
                            .padding(.vertical, 14)
                            .padding(.horizontal, 16)
                            .background(MeeplePalette.card, in: RoundedRectangle(cornerRadius: 14))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(MeeplePalette.silver.opacity(0.12), lineWidth: 1)
                            )
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .background(MeeplePalette.background)
        .trackScreen(.statistics)
        // The tapped game's results, read-only (Close instead of Done).
        .sheet(item: $viewingRecord) { record in
            ResultsView(record: record, isReadOnly: true)
        }
    }
}

#Preview {
    StatisticsView()
        .modelContainer(for: GameRecord.self, inMemory: true)
        .preferredColorScheme(.dark)
}

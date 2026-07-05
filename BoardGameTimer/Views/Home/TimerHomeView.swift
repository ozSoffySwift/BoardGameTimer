import SwiftUI
import SwiftData

// TimerHomeView is the Timer tab's landing screen in the redesigned app: the app's name in
// big type, a split "New Timer" button (main area opens full Player Setup; the chevron end
// opens a quick-start grid that launches a default game instantly), and a short list of
// recently played games pulled from history.
struct TimerHomeView: View {
    // Recent games, newest first, straight from SwiftData — `@Query` keeps this array
    // up to date automatically whenever a new GameRecord is saved.
    @Query(sort: \GameRecord.date, order: .reverse) private var history: [GameRecord]

    // The user's saved defaults (set on the Settings tab), used to seed new games.
    @AppStorage("defaultTurnLimitSeconds") private var defaultTurnLimitSeconds = 60
    @AppStorage("soundAndHapticsEnabled") private var soundAndHapticsEnabled = true
    @AppStorage("defaultColorsCSV") private var defaultColorsCSV = "0,1,2,3,4,5,6,7,8,9"

    // Whether the quick-start player-count grid is currently expanded under the button.
    @State private var isShowingQuickPicker = false

    // A non-nil value here presents the Player Setup screen (full configuration flow).
    @State private var setupDraft: GameSetupDraft?

    // A non-nil value here presents the ACTIVE GAME full-screen (used by quick start,
    // which skips setup entirely). The setup flow presents its own game cover.
    @State private var quickGame: TimerGameViewModel?

    // A history record tapped from "Recent Games", shown read-only.
    @State private var viewingRecord: GameRecord?

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                // --- Title block ---
                VStack(spacing: 10) {
                    Text("Board Game\nTimer")
                        .font(.system(size: 42, weight: .heavy))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white)
                    Text("Chess-clock style turn timers for tabletop games.")
                        .font(.system(size: 14))
                        .foregroundStyle(MeeplePalette.textSecondary)
                }
                .padding(.top, 18)

                // --- Split "New Timer" button ---
                HStack(spacing: 0) {
                    // Main area (75%): the full setup flow.
                    Button {
                        setupDraft = GameSetupDraft(
                            playerCount: 4,
                            defaultTurnLimit: defaultTurnLimitSeconds,
                            defaultColors: decodedDefaultColors
                        )
                        isShowingQuickPicker = false
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "plus")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(MeeplePalette.silver)
                            Text("New Timer")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(.white)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(LinearGradient(
                            colors: [Color(hex: 0x1C1D20), Color(hex: 0x0D0E10)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        ))
                    }

                    // Thin divider between the two halves of the split button.
                    Rectangle()
                        .fill(MeeplePalette.silver.opacity(0.25))
                        .frame(width: 1)

                    // Chevron end (25%): toggles the quick-start grid below.
                    Button {
                        withAnimation(.easeOut(duration: 0.15)) {
                            isShowingQuickPicker.toggle()
                        }
                    } label: {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(MeeplePalette.silver)
                            // Point up while open so the button reads as a toggle.
                            .rotationEffect(.degrees(isShowingQuickPicker ? 180 : 0))
                            .frame(maxHeight: .infinity)
                            .frame(width: 84)
                            .background(LinearGradient(
                                colors: [Color(hex: 0x232427), Color(hex: 0x141517)],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            ))
                    }
                }
                .frame(height: 64)
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(MeeplePalette.silver.opacity(0.35), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.4), radius: 12, y: 8)

                // --- Quick-start grid (1-6 players, default settings, no setup) ---
                if isShowingQuickPicker {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("QUICK TIMER \u{2014} PLAYERS")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(MeeplePalette.textSecondary)
                            .padding(.horizontal, 4)

                        // Three columns of equal-width number buttons.
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                            ForEach(1...6, id: \.self) { count in
                                Button {
                                    startQuickGame(playerCount: count)
                                } label: {
                                    Text("\(count)")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundStyle(.white)
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 44)
                                        .background(MeeplePalette.control, in: RoundedRectangle(cornerRadius: 10))
                                }
                            }
                        }
                    }
                    .padding(14)
                    .background(MeeplePalette.card, in: RoundedRectangle(cornerRadius: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(MeeplePalette.silver.opacity(0.25), lineWidth: 1)
                    )
                    .transition(.opacity)
                }

                // --- Recent games (only when there's history) ---
                if !history.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("RECENT GAMES")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(MeeplePalette.textSecondary)

                        // Just the three most recent — the Statistics tab has the full list.
                        ForEach(history.prefix(3)) { record in
                            Button {
                                viewingRecord = record
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(record.gameName)
                                            .font(.system(size: 15, weight: .semibold))
                                            .foregroundStyle(.white)
                                        Text("\(record.dateLabel) \u{00B7} \(record.playerCountLabel)")
                                            .font(.system(size: 12))
                                            .foregroundStyle(MeeplePalette.textSecondary)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(MeeplePalette.textSecondary)
                                }
                                .padding(.vertical, 14)
                                .padding(.horizontal, 16)
                                .background(MeeplePalette.card, in: RoundedRectangle(cornerRadius: 16))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(MeeplePalette.cardBorder, lineWidth: 1)
                                )
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .background(MeeplePalette.background)
        // Full Player Setup flow, pushed as a cover so the game it eventually launches
        // can't be swiped away accidentally.
        .fullScreenCover(item: $setupDraft) { draft in
            PlayerSetupView(draft: draft)
        }
        // Quick-start games skip setup and go straight into the running timer.
        .fullScreenCover(item: $quickGame) { game in
            TimerActiveView(game: game)
        }
        // Read-only results for a tapped history row.
        .sheet(item: $viewingRecord) { record in
            ResultsView(record: record, isReadOnly: true)
        }
    }

    // Decodes the saved "0,1,2,3,..." string from Settings back into an [Int] of color
    // indexes. Stored as CSV text because @AppStorage can't hold arrays directly.
    private var decodedDefaultColors: [Int] {
        let parsed = defaultColorsCSV.split(separator: ",").compactMap { Int($0) }
        return parsed.isEmpty ? Array(0..<10) : parsed
    }

    // Launches an instant game with default names/colors and the saved default turn time.
    private func startQuickGame(playerCount: Int) {
        let colors = decodedDefaultColors
        let players = (0..<playerCount).map { seat in
            TimerPlayer(name: "Player \(seat + 1)", colorIndex: colors[seat % max(colors.count, 1)])
        }
        quickGame = TimerGameViewModel(
            players: players,
            gameName: "Quick Game",
            turnLimitSeconds: defaultTurnLimitSeconds,
            firstPlayerIndex: 0,
            soundAndHapticsEnabled: soundAndHapticsEnabled
        )
        isShowingQuickPicker = false
    }
}

// GameSetupDraft needs Identifiable to drive `.fullScreenCover(item:)` above; the class
// instance's object identity is a perfectly good id.
extension GameSetupDraft: Identifiable {}

#Preview {
    TimerHomeView()
        .modelContainer(for: GameRecord.self, inMemory: true)
        .preferredColorScheme(.dark)
}

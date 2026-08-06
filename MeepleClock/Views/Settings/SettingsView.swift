import SwiftUI
import SwiftData

// SettingsView is the redesigned settings tab (from the approved Claude Design prototype):
// the default per-turn time new games start with, the ten default meeple colors handed to
// new seats, one combined Sound & Haptics switch, version info, a link to the About
// screen, and a destructive Clear History action guarded by a confirmation dialog.
//
// Every preference is backed by `@AppStorage`, SwiftUI's built-in wrapper around
// UserDefaults — it reads/writes like `@State` but the value is saved to disk
// automatically and survives relaunches, with no manual persistence code.
struct SettingsView: View {
    // The turn limit (seconds) new games are seeded with on the setup screen.
    @AppStorage("defaultTurnLimitSeconds") private var defaultTurnLimitSeconds = 60

    // One switch covering both the turn-pass click/buzz and the overtime beep.
    @AppStorage("soundAndHapticsEnabled") private var soundAndHapticsEnabled = true

    // Whether the phone stays awake during a running game (carried over from the previous
    // design's settings — still genuinely useful mid-game).
    @AppStorage("keepScreenAwakeDuringGames") private var keepScreenAwakeDuringGames = true

    // The ten default seat colors, stored as comma-separated text ("0,1,2,...") because
    // @AppStorage can only hold simple types like String — not arrays directly.
    @AppStorage("defaultColorsCSV") private var defaultColorsCSV = "0,1,2,3,4,5,6,7,8,9"

    // For deleting all saved GameRecords when history is cleared.
    @Environment(\.modelContext) private var modelContext

    // Which default-color SLOT is being repicked in the sheet, or nil when closed.
    @State private var pickingSlot: Int?

    // Whether the "really clear all history?" confirmation is showing.
    @State private var isConfirmingClear = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Settings")
                    .font(.system(size: 30, weight: .heavy))
                    .foregroundStyle(.white)
                    .padding(.top, 6)

                // --- Default turn time ---
                VStack(alignment: .leading, spacing: 8) {
                    sectionHeader("Default turn time")
                    HStack {
                        Text(TimeInterval(defaultTurnLimitSeconds).asClockString)
                            .font(.system(size: 20, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white)
                        Spacer()
                        stepperButton("minus") {
                            defaultTurnLimitSeconds = max(10, defaultTurnLimitSeconds - 5)
                        }
                        stepperButton("plus") {
                            defaultTurnLimitSeconds = min(300, defaultTurnLimitSeconds + 5)
                        }
                    }
                    .padding(.vertical, 14)
                    .padding(.horizontal, 16)
                    .background(MeeplePalette.card, in: RoundedRectangle(cornerRadius: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(MeeplePalette.cardBorder, lineWidth: 1)
                    )
                }

                // --- Default player colors (tap a meeple to change that seat's default) ---
                VStack(alignment: .leading, spacing: 8) {
                    sectionHeader("Default player colors")
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 5), spacing: 10) {
                        ForEach(Array(decodedDefaultColors.enumerated()), id: \.offset) { slot, colorIndex in
                            Button {
                                pickingSlot = slot
                            } label: {
                                MeepleView(colorIndex: colorIndex)
                                    .frame(width: 38)
                            }
                        }
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity)
                    .background(MeeplePalette.card, in: RoundedRectangle(cornerRadius: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(MeeplePalette.cardBorder, lineWidth: 1)
                    )
                }

                // --- Toggles ---
                VStack(spacing: 0) {
                    toggleRow("Sound & Haptics", isOn: $soundAndHapticsEnabled)
                    Rectangle().fill(MeeplePalette.silver.opacity(0.1)).frame(height: 1)
                    toggleRow("Keep Screen Awake During Games", isOn: $keepScreenAwakeDuringGames)
                }
                .padding(.horizontal, 16)
                .background(MeeplePalette.card, in: RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(MeeplePalette.cardBorder, lineWidth: 1)
                )

                // --- Version + About ---
                VStack(spacing: 0) {
                    HStack {
                        Text("Version")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(.white)
                        Spacer()
                        Text(appVersionString)
                            .font(.system(size: 15))
                            .foregroundStyle(MeeplePalette.textSecondary)
                    }
                    .padding(.vertical, 14)

                    Rectangle().fill(MeeplePalette.silver.opacity(0.1)).frame(height: 1)

                    // Pushes to the existing About screen (developer credit, links, rating).
                    NavigationLink {
                        AboutView()
                    } label: {
                        HStack {
                            Text("About Meeple Clock")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(.white)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(MeeplePalette.textSecondary)
                        }
                        .padding(.vertical, 14)
                    }
                }
                .padding(.horizontal, 16)
                .background(MeeplePalette.card, in: RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(MeeplePalette.cardBorder, lineWidth: 1)
                )

                // --- Clear history (destructive, confirmed first) ---
                Button {
                    isConfirmingClear = true
                } label: {
                    Text("Clear History")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(MeeplePalette.dangerText)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(MeeplePalette.card, in: RoundedRectangle(cornerRadius: 14))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(Color(hex: 0xB4222B).opacity(0.4), lineWidth: 1)
                        )
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .background(MeeplePalette.background)
        // The meeple color sheet for whichever default slot was tapped.
        .sheet(item: $pickingSlot) { slot in
            ColorPickerSheet(
                selectedColorIndex: decodedDefaultColors[slot],
                onPick: { picked in
                    var colors = decodedDefaultColors
                    colors[slot] = picked
                    // Re-encode back into the CSV string @AppStorage can hold.
                    defaultColorsCSV = colors.map(String.init).joined(separator: ",")
                    pickingSlot = nil
                }
            )
        }
        // The system confirmation dialog guarding the destructive clear.
        .confirmationDialog(
            "Clear all history?",
            isPresented: $isConfirmingClear,
            titleVisibility: .visible
        ) {
            Button("Clear", role: .destructive) {
                clearHistory()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This permanently deletes all saved games. This cannot be undone.")
        }
    }

    // Decodes the stored "0,1,2,..." string back into an array of ten color indexes.
    private var decodedDefaultColors: [Int] {
        let parsed = defaultColorsCSV.split(separator: ",").compactMap { Int($0) }
        return parsed.count == 10 ? parsed : Array(0..<10)
    }

    // Deletes every saved GameRecord — this is what actually empties the Statistics tab.
    private func clearHistory() {
        // Counted before the delete, so the event records how much was actually thrown away.
        let gameCount = (try? modelContext.fetchCount(FetchDescriptor<GameRecord>())) ?? 0
        // `delete(model:)` is SwiftData's bulk "delete every object of this type" call.
        try? modelContext.delete(model: GameRecord.self)
        try? modelContext.save()
        AnalyticsService.historyCleared(gameCount: gameCount)
    }

    // Reads version/build straight from the app's own Info.plist so it never goes stale.
    private var appVersionString: String {
        let shortVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(shortVersion) (\(buildNumber))"
    }

    // The small uppercase gray section label used above each group.
    private func sectionHeader(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(MeeplePalette.textSecondary)
    }

    // A square minus/plus stepper button.
    private func stepperButton(_ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(MeeplePalette.silver)
                .frame(width: 34, height: 34)
                .background(MeeplePalette.control, in: RoundedRectangle(cornerRadius: 9))
        }
    }

    // A labeled toggle row, tinted with the silver accent when on.
    private func toggleRow(_ title: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            Text(title)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.white)
        }
        .tint(MeeplePalette.silverDark)
        .padding(.vertical, 14)
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
    .modelContainer(for: GameRecord.self, inMemory: true)
    .preferredColorScheme(.dark)
}

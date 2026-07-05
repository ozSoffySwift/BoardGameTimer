import SwiftUI

// PlayerSetupView is the full game-configuration screen from the redesign: pick how many
// players (chips), name each one and choose their meeple color, optionally name the game,
// set the per-turn time limit (stepper + slider), choose who goes first (including
// "Random"), then Start Game — which launches straight into the running timer.
struct PlayerSetupView: View {
    // The draft being edited. `@Bindable` lets text fields/sliders bind two-way into an
    // @Observable class's properties (the iOS-17 equivalent of ObservedObject bindings).
    @Bindable var draft: GameSetupDraft

    // Closes this whole setup cover (the back arrow).
    @Environment(\.dismiss) private var dismiss

    // Sound setting, read here so it can be handed to the game engine at start.
    @AppStorage("soundAndHapticsEnabled") private var soundAndHapticsEnabled = true

    // Which seat's color is being picked in the sheet, or nil when the sheet is closed.
    @State private var colorPickingSeat: Int?

    // The running game launched by Start Game; non-nil presents the timer cover.
    @State private var activeGame: TimerGameViewModel?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // --- Header: back arrow + title ---
                HStack(spacing: 10) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(MeeplePalette.silver)
                            .frame(width: 32, height: 32)
                            .background(Color(hex: 0x1C1D20), in: Circle())
                    }
                    Text("Player Setup")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.white)
                }
                .padding(.top, 4)

                // --- Player count chips (1-6) ---
                VStack(alignment: .leading, spacing: 8) {
                    sectionHeader("How many players?")
                    HStack(spacing: 6) {
                        ForEach(1...6, id: \.self) { count in
                            let isSelected = count == draft.playerCount
                            Button {
                                draft.setPlayerCount(count)
                            } label: {
                                Text("\(count)")
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundStyle(isSelected ? MeeplePalette.background : MeeplePalette.silver)
                                    .frame(maxWidth: .infinity)
                                    .aspectRatio(1, contentMode: .fit)
                                    .background(
                                        // Selected chip gets the silver gradient; the rest
                                        // stay as dark cards with a subtle border.
                                        Group {
                                            if isSelected {
                                                RoundedRectangle(cornerRadius: 10).fill(MeeplePalette.silverGradient)
                                            } else {
                                                RoundedRectangle(cornerRadius: 10).fill(MeeplePalette.card)
                                            }
                                        }
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(isSelected ? Color.clear : MeeplePalette.cardBorder, lineWidth: 1)
                                    )
                            }
                        }
                    }
                }

                // --- One editable row per player ---
                VStack(spacing: 10) {
                    // Enumerated so each row knows its seat index for the color sheet.
                    ForEach(Array(draft.players.enumerated()), id: \.element.id) { seat, _ in
                        HStack(spacing: 12) {
                            // Tapping the meeple opens the color picker for this seat.
                            Button {
                                colorPickingSeat = seat
                            } label: {
                                MeepleView(colorIndex: draft.players[seat].colorIndex)
                                    .frame(width: 40)
                            }

                            // The player's name, edited in place. `$draft.players[seat].name`
                            // binds the field directly to the draft's stored value.
                            TextField("Name", text: $draft.players[seat].name)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.white)
                                .autocorrectionDisabled()

                            Image(systemName: "pencil")
                                .font(.system(size: 13))
                                .foregroundStyle(MeeplePalette.silver.opacity(0.4))
                        }
                        .padding(.vertical, 10)
                        .padding(.horizontal, 12)
                        .background(MeeplePalette.card, in: RoundedRectangle(cornerRadius: 14))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(MeeplePalette.silver.opacity(0.12), lineWidth: 1)
                        )
                    }
                }

                // --- Game name (optional, free text) ---
                VStack(alignment: .leading, spacing: 8) {
                    sectionHeader("Game name")
                    TextField("e.g. Catan Night", text: $draft.gameName)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.white)
                        .padding(14)
                        .background(MeeplePalette.card, in: RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(MeeplePalette.cardBorder, lineWidth: 1)
                        )
                        .autocorrectionDisabled()
                }

                // --- Per-turn time limit ---
                VStack(alignment: .leading, spacing: 10) {
                    sectionHeader("Time per player")
                    VStack(spacing: 12) {
                        HStack {
                            // The big monospaced time readout, e.g. "1:00".
                            Text(TimeInterval(draft.turnLimitSeconds).asClockString)
                                .font(.system(size: 26, weight: .heavy, design: .monospaced))
                                .foregroundStyle(.white)
                            Spacer()
                            // Minus/plus step by 5 seconds, clamped to the 10-300 range.
                            stepperButton("minus") {
                                draft.turnLimitSeconds = max(10, draft.turnLimitSeconds - 5)
                            }
                            stepperButton("plus") {
                                draft.turnLimitSeconds = min(300, draft.turnLimitSeconds + 5)
                            }
                        }
                        // The slider binds through a Double conversion (Slider only speaks
                        // Double); `step: 5` keeps it on the same 5-second grid as the buttons.
                        Slider(
                            value: Binding(
                                get: { Double(draft.turnLimitSeconds) },
                                set: { draft.turnLimitSeconds = Int($0) }
                            ),
                            in: 10...300,
                            step: 5
                        )
                        .tint(MeeplePalette.silver)
                    }
                    .padding(16)
                    .background(MeeplePalette.card, in: RoundedRectangle(cornerRadius: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(MeeplePalette.cardBorder, lineWidth: 1)
                    )
                }

                // --- First player picker (hidden for solo games, where there's no choice) ---
                if draft.playerCount > 1 {
                    VStack(alignment: .leading, spacing: 8) {
                        sectionHeader("First player")
                        // A menu-style picker listing every player plus "Random First Player",
                        // matching the design's dropdown.
                        Picker("First player", selection: $draft.firstPlayerChoice) {
                            ForEach(Array(draft.players.enumerated()), id: \.offset) { seat, player in
                                Text(player.name).tag(GameSetupDraft.FirstPlayerChoice.player(seat))
                            }
                            Text("Random First Player").tag(GameSetupDraft.FirstPlayerChoice.random)
                        }
                        .pickerStyle(.menu)
                        .tint(.white)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 6)
                        .padding(.horizontal, 8)
                        .background(MeeplePalette.card, in: RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(MeeplePalette.cardBorder, lineWidth: 1)
                        )
                    }
                }

                // --- Start Game ---
                Button {
                    startGame()
                } label: {
                    Text("Start Game")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(MeeplePalette.background)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(MeeplePalette.silverGradient, in: RoundedRectangle(cornerRadius: 14))
                }
                .padding(.top, 8)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .background(MeeplePalette.background)
        // The color picker bottom sheet for whichever seat's meeple was tapped.
        .sheet(item: $colorPickingSeat) { seat in
            ColorPickerSheet(
                selectedColorIndex: draft.players[seat].colorIndex,
                onPick: { picked in
                    draft.players[seat].colorIndex = picked
                    colorPickingSeat = nil
                }
            )
        }
        // Start Game presents the running timer on top of this setup screen; when the
        // game finishes and its cover is dismissed, this dismisses too (back to Home).
        .fullScreenCover(item: $activeGame, onDismiss: { dismiss() }) { game in
            TimerActiveView(game: game)
        }
    }

    // The small uppercase gray section label used above each group, per the design.
    private func sectionHeader(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(MeeplePalette.textSecondary)
    }

    // One of the square minus/plus stepper buttons.
    private func stepperButton(_ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(MeeplePalette.silver)
                .frame(width: 36, height: 36)
                .background(MeeplePalette.control, in: RoundedRectangle(cornerRadius: 10))
        }
    }

    // Builds the real game engine from the draft and launches it.
    private func startGame() {
        activeGame = TimerGameViewModel(
            players: draft.players,
            gameName: draft.gameName,
            turnLimitSeconds: draft.turnLimitSeconds,
            firstPlayerIndex: draft.resolvedFirstPlayerIndex(),
            soundAndHapticsEnabled: soundAndHapticsEnabled
        )
    }
}

// `.sheet(item:)` needs its item to be Identifiable; wrapping a plain Int seat index this
// way lets the color sheet be driven by "which seat, or nil" directly.
extension Int: @retroactive Identifiable {
    public var id: Int { self }
}

#Preview {
    PlayerSetupView(draft: GameSetupDraft())
        .preferredColorScheme(.dark)
}

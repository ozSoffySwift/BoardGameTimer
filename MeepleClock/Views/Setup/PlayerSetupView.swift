import SwiftUI

// PlayerSetupView is the full game-configuration screen from the redesign: pick how many
// players (chips), name each one, choose their meeple color, reorder seats with the
// standard iOS drag handle, optionally name the game, set the per-turn time limit
// (stepper + slider), choose who goes first (including "Random"), then Start Game — which
// launches straight into the running timer.
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

    // How tall each player row's card is.
    private let rowHeight: CGFloat = 64

    var body: some View {
        // The WHOLE screen is one `List` (not a ScrollView): `.onMove` — the standard iOS
        // drag-to-reorder with the familiar ≡ handle — only behaves reliably when its rows
        // live directly in the List that owns the scrolling. Every other block on this
        // screen is just a styled, chrome-less list row (see `setupRow` below).
        List {
                // --- Header: back arrow + title (same 30pt heavy style as the
                //     Statistics/Settings screen titles, so all screens feel consistent) ---
                HStack(spacing: 12) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(MeeplePalette.silver)
                            .frame(width: 32, height: 32)
                            .background(Color(hex: 0x1C1D20), in: Circle())
                    }
                    .buttonStyle(.borderless)
                    Text("Player Setup")
                        .font(.system(size: 30, weight: .heavy))
                        .foregroundStyle(.white)
                }
                .setupRow(top: 4, bottom: 10)

                // --- Player count chips (1-6), spanning the full row width with big,
                //     easily-tappable numbers ---
                VStack(alignment: .leading, spacing: 8) {
                    sectionHeader("How many players?")
                    HStack(spacing: 8) {
                        ForEach(1...6, id: \.self) { count in
                            let isSelected = count == draft.playerCount
                            Button {
                                draft.setPlayerCount(count)
                            } label: {
                                Text("\(count)")
                                    .font(.system(size: 26, weight: .bold))
                                    .foregroundStyle(isSelected ? MeeplePalette.background : MeeplePalette.silver)
                                    // `maxWidth: .infinity` makes all six chips share the
                                    // full row equally; the square aspect ratio then makes
                                    // each one as TALL as it is wide, so bigger screens get
                                    // proportionally bigger chips automatically.
                                    .frame(maxWidth: .infinity)
                                    .aspectRatio(1, contentMode: .fit)
                                    .background(
                                        // Selected chip gets the silver gradient; the rest
                                        // stay as dark cards with a subtle border.
                                        Group {
                                            if isSelected {
                                                RoundedRectangle(cornerRadius: 12).fill(MeeplePalette.silverGradient)
                                            } else {
                                                RoundedRectangle(cornerRadius: 12).fill(MeeplePalette.card)
                                            }
                                        }
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(isSelected ? Color.clear : MeeplePalette.cardBorder, lineWidth: 1)
                                    )
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .setupRow()

                // --- One editable row per player, reorderable by dragging the STANDARD
                //     iOS ≡ handle on the right (drawn by the List's active edit mode). ---
                // Enumerated so each row knows its seat index for the color sheet.
                ForEach(Array(draft.players.enumerated()), id: \.element.id) { seat, _ in
                    HStack(spacing: 12) {
                        // Tapping the meeple opens the color picker for this seat.
                        // `.borderless` keeps the tap target JUST the meeple — a plain
                        // Button inside a List row would otherwise make the whole row
                        // tappable, swallowing taps meant for the name field.
                        Button {
                            colorPickingSeat = seat
                        } label: {
                            MeepleView(colorIndex: draft.players[seat].colorIndex)
                                .frame(width: 40)
                        }
                        .buttonStyle(.borderless)

                        // The player's name, edited in place. `$draft.players[seat].name`
                        // binds the field directly to the draft's stored value.
                        TextField("Name", text: $draft.players[seat].name)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                            .autocorrectionDisabled()
                    }
                    .padding(.horizontal, 12)
                    .frame(height: rowHeight)
                    .background(MeeplePalette.card, in: RoundedRectangle(cornerRadius: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(MeeplePalette.silver.opacity(0.12), lineWidth: 1)
                    )
                    .setupRow(top: 5, bottom: 5)
                }
                // The native reorder: iOS lifts the dragged row, shuffles the others out
                // of the way, and calls this ONCE with the final move when the user lets
                // go. `move(fromOffsets:toOffset:)` applies it to the draft.
                .onMove { fromOffsets, toOffset in
                    draft.players.move(fromOffsets: fromOffsets, toOffset: toOffset)
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
                .setupRow()

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
                .setupRow()

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
                    .setupRow()
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
                .buttonStyle(.borderless)
                .setupRow(top: 18, bottom: 24)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden) // hide the List's default background...
        .background(MeeplePalette.background) // ...so our dark theme shows instead
        // Edit mode "active" is what makes the ≡ reorder handles show all the time on the
        // player rows (only rows in a ForEach with .onMove get handles — nothing else on
        // this screen grows any edit controls).
        .environment(\.editMode, .constant(.active))
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

private extension View {
    // Strips a List row down to bare content — no default background, no separator line —
    // and applies this screen's standard 20pt side margins plus adjustable vertical
    // spacing. Every block on the setup screen goes through this, so the List looks like
    // the original custom layout while still providing native drag-to-reorder.
    func setupRow(top: CGFloat = 10, bottom: CGFloat = 10) -> some View {
        self
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: top, leading: 20, bottom: bottom, trailing: 20))
    }
}

#Preview {
    PlayerSetupView(draft: GameSetupDraft())
        .preferredColorScheme(.dark)
}

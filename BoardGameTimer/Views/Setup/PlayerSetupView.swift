import SwiftUI

// PlayerSetupView is the full game-configuration screen from the redesign: pick how many
// players (chips), name each one, choose their meeple color, drag rows by their left-side
// handle to change seat order, optionally name the game, set the per-turn time limit
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

    // --- Drag-to-reorder state (see the handle gesture on the player rows) ---

    // The id of the player row currently being dragged by its handle, or nil when no
    // reorder-drag is happening.
    @State private var draggingPlayerID: UUID?

    // Which position in the list the dragged row STARTED at — the visual-offset math
    // below needs it to know how far the row has already been re-slotted.
    @State private var dragStartIndex = 0

    // The finger's total vertical travel since the drag began, in points.
    @State private var dragTranslation: CGFloat = 0

    // Every player row is exactly this tall, and this far from its neighbor — fixed
    // numbers (rather than measuring) keep the "how many slots has the finger moved"
    // math simple and exact.
    private let rowHeight: CGFloat = 64
    private let rowSpacing: CGFloat = 10
    // The distance from one row's top to the next row's top.
    private var rowStride: CGFloat { rowHeight + rowSpacing }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
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
                    Text("Player Setup")
                        .font(.system(size: 30, weight: .heavy))
                        .foregroundStyle(.white)
                }
                .padding(.top, 4)

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
                        }
                    }
                    .frame(maxWidth: .infinity)
                }

                // --- One editable row per player (draggable by the left-side handle) ---
                VStack(spacing: rowSpacing) {
                    // Enumerated so each row knows its seat index for the color sheet.
                    ForEach(Array(draft.players.enumerated()), id: \.element.id) { seat, player in
                        let isDragging = draggingPlayerID == player.id

                        HStack(spacing: 12) {
                            // The drag handle: press and hold THIS icon, then drag up or
                            // down to move the row and change seat order (the long-press
                            // "lift" first is what stops the whole screen scrolling
                            // instead). See `handleDragChanged` for the reorder math.
                            Image(systemName: "line.3.horizontal")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(MeeplePalette.silver.opacity(0.5))
                                // A little extra invisible padding makes the handle easier
                                // to grab than the bare 16pt icon would be.
                                .padding(.vertical, 12)
                                .padding(.trailing, 4)
                                .contentShape(Rectangle())
                                .gesture(
                                    // `sequenced` = the drag only starts AFTER the press
                                    // has been held a moment — the standard "lift, then
                                    // move" reorder feel.
                                    LongPressGesture(minimumDuration: 0.15)
                                        .sequenced(before: DragGesture())
                                        .onChanged { value in
                                            switch value {
                                            case .first(true):
                                                // The lift: remember which row and where
                                                // it currently sits.
                                                beginDrag(of: player.id)
                                            case .second(true, let drag):
                                                if let drag {
                                                    handleDragChanged(drag)
                                                }
                                            default:
                                                break
                                            }
                                        }
                                        .onEnded { _ in endDrag() }
                                )

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
                        .padding(.horizontal, 12)
                        // The fixed height the reorder math relies on (see `rowHeight`).
                        .frame(height: rowHeight)
                        .background(MeeplePalette.card, in: RoundedRectangle(cornerRadius: 14))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(MeeplePalette.silver.opacity(0.12), lineWidth: 1)
                        )
                        // The dragged row visually follows the finger via this offset;
                        // every other row stays put (the array reorder is what moves them).
                        .offset(y: isDragging ? draggedRowOffset : 0)
                        // Lifted styling: slightly grown, slightly transparent, floating
                        // above its neighbors with a shadow.
                        .scaleEffect(isDragging ? 1.03 : 1)
                        .opacity(isDragging ? 0.85 : 1)
                        .shadow(color: .black.opacity(isDragging ? 0.5 : 0), radius: 10, y: 4)
                        .zIndex(isDragging ? 1 : 0)
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

// --- Drag-to-reorder mechanics ---
extension PlayerSetupView {
    // How far the LIFTED row should be drawn from its current slot: the finger's total
    // travel, minus the distance already "used up" by slots the row has hopped into.
    // Without that subtraction the row would drift further and further from the finger
    // after every live reorder.
    private var draggedRowOffset: CGFloat {
        guard let draggingPlayerID,
              let currentIndex = draft.players.firstIndex(where: { $0.id == draggingPlayerID }) else {
            return 0
        }
        return dragTranslation - CGFloat(currentIndex - dragStartIndex) * rowStride
    }

    // The "lift": remembers which row is being dragged and where it started.
    fileprivate func beginDrag(of playerID: UUID) {
        guard let index = draft.players.firstIndex(where: { $0.id == playerID }) else { return }
        draggingPlayerID = playerID
        dragStartIndex = index
        dragTranslation = 0
    }

    // Called continuously while the handle is dragged: once the lifted row has moved more
    // than HALF a slot past a neighbor, the two swap places in the draft (animated), and
    // the offset math above keeps the lifted row glued to the finger through the swap.
    fileprivate func handleDragChanged(_ drag: DragGesture.Value) {
        dragTranslation = drag.translation.height
        guard let draggingPlayerID,
              let currentIndex = draft.players.firstIndex(where: { $0.id == draggingPlayerID }) else {
            return
        }

        let offset = draggedRowOffset
        if offset > rowStride / 2, currentIndex < draft.players.count - 1 {
            // Dragged more than half a slot DOWN — swap with the row below.
            withAnimation(.easeInOut(duration: 0.15)) {
                draft.players.swapAt(currentIndex, currentIndex + 1)
            }
        } else if offset < -rowStride / 2, currentIndex > 0 {
            // Dragged more than half a slot UP — swap with the row above.
            withAnimation(.easeInOut(duration: 0.15)) {
                draft.players.swapAt(currentIndex, currentIndex - 1)
            }
        }
    }

    // The drop: clear the drag state (animated, so the lifted row settles into its slot).
    fileprivate func endDrag() {
        withAnimation(.easeInOut(duration: 0.2)) {
            draggingPlayerID = nil
            dragTranslation = 0
        }
    }
}

#Preview {
    PlayerSetupView(draft: GameSetupDraft())
        .preferredColorScheme(.dark)
}

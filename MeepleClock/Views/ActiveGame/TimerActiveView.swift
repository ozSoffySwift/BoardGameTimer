import SwiftUI
import SwiftData

// TimerActiveView is the redesigned live-game screen: a full-bleed radial pie where every
// player's wedge is filled with their meeple gradient, the ACTIVE wedge glows at full
// strength (white outline, bigger labels, gently pulsing) while the others sit dimmed, a
// silver-ringed center circle shows the whole game's running time, and a three-button bar
// (undo / pause / end) sits along the bottom. Tapping the ACTIVE wedge — and only the
// active wedge — passes the turn clockwise.
struct TimerActiveView: View {
    // The running game engine.
    let game: TimerGameViewModel

    // For saving the finished GameRecord into history when the game ends.
    @Environment(\.modelContext) private var modelContext

    // Closes this full-screen cover once the results screen's Done is tapped.
    @Environment(\.dismiss) private var dismiss

    // Whether the phone should stay awake during the game (Settings; default on).
    @AppStorage("keepScreenAwakeDuringGames") private var keepScreenAwakeDuringGames = true

    // The finished game's record — non-nil switches this screen to the results view.
    @State private var finishedRecord: GameRecord?

    var body: some View {
        // Once the game ends, this same cover swaps to the results screen (simpler than
        // presenting a second cover on top).
        if let finishedRecord {
            ResultsView(record: finishedRecord, isReadOnly: false, onDone: { dismiss() })
        } else {
            gameBody
        }
    }

    // The actual live-game layout, redrawn 5 times a second by TimelineView so all the
    // clock text visibly ticks (the underlying math is date-based, so redraw rate only
    // affects smoothness, never accuracy).
    private var gameBody: some View {
        TimelineView(.periodic(from: .now, by: 0.2)) { timeline in
            let now = timeline.date

            VStack(spacing: 0) {
                // --- The radial pie fills everything above the control bar ---
                GeometryReader { geometry in
                    let size = geometry.size
                    let center = CGPoint(x: size.width / 2, y: size.height / 2)
                    // A radius comfortably past the screen corners so wedges bleed
                    // fully edge-to-edge (the design uses an oversized circle too).
                    let radius = hypot(size.width, size.height) / 2 + 40

                    ZStack {
                        MeeplePalette.background

                        // Layer 1: the wedge shapes.
                        ForEach(Array(game.players.enumerated()), id: \.element.id) { seat, player in
                            let isActive = seat == game.activeIndex
                            DesignWedge(seat: seat, totalSeats: game.players.count, radius: radius)
                                .fill(MeeplePalette.gradient(player.colorIndex))
                                .opacity(isActive ? 1 : 0.62)
                                .overlay(
                                    // The thick white outline marking the active wedge.
                                    DesignWedge(seat: seat, totalSeats: game.players.count, radius: radius)
                                        .stroke(.white, lineWidth: isActive ? 5 : 0)
                                )
                                // Only the active wedge accepts taps — tapping it passes
                                // the turn. Inactive wedges ignore touches entirely, per
                                // the design (no jumping to arbitrary players in v2).
                                .allowsHitTesting(isActive)
                                .onTapGesture {
                                    guard !game.isPaused else { return }
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        game.nextTurn()
                                    }
                                }
                        }

                        // Layer 2: each wedge's meeple + name + running time label,
                        // positioned on an ellipse partway out from the center.
                        ForEach(Array(game.players.enumerated()), id: \.element.id) { seat, player in
                            let isActive = seat == game.activeIndex
                            WedgeLabel(
                                player: player,
                                // Counts up in stopwatch games, down in countdown ones —
                                // the engine decides, so the mode check stays out of here.
                                displaySeconds: game.displaySeconds(for: seat, at: now),
                                isCountdown: game.mode == .countdown,
                                isActive: isActive,
                                // Red for either alarm: this turn running long, or this
                                // player having spent their whole bank. A player who is out
                                // of time stays red on every later turn, not just the one
                                // they ran out on.
                                isAlarm: (isActive && game.isOvertime) || game.isOutOfTime(seat)
                            )
                            .position(labelPosition(seat: seat, totalSeats: game.players.count, in: size))
                            .allowsHitTesting(false) // labels are decoration; taps go to wedges
                        }

                        // Layer 3: the silver-ringed center circle with the game clock.
                        VStack(spacing: 5) {
                            Text(game.gameElapsed(at: now).asClockString)
                                .font(.system(size: 40, weight: .heavy, design: .monospaced))
                                .foregroundStyle(.white)
                            Text("\(activePlayerName) turn")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(MeeplePalette.textSecondary)
                            Text("Round \(game.round)")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(Color(hex: 0x6B7076))
                        }
                        .frame(width: 150, height: 150)
                        .background(MeeplePalette.background, in: Circle())
                        .overlay(Circle().stroke(MeeplePalette.silver.opacity(0.6), lineWidth: 2).padding(-4))
                        .overlay(Circle().stroke(MeeplePalette.silver, lineWidth: 2).padding(-11))
                        .shadow(color: .black.opacity(0.7), radius: 15)
                        .position(center)
                        .allowsHitTesting(false)

                        // Layer 4: the dimming overlay + PAUSED chip while paused.
                        if game.isPaused {
                            MeeplePalette.background.opacity(0.55)
                            Text("PAUSED")
                                .font(.system(size: 22, weight: .bold))
                                .kerning(1)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 28)
                                .padding(.vertical, 14)
                                .background(MeeplePalette.card.opacity(0.9), in: RoundedRectangle(cornerRadius: 14))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(MeeplePalette.silver.opacity(0.35), lineWidth: 1)
                                )
                                .position(center)
                        }
                    }
                    .clipped() // stop the oversized wedges painting outside this area
                }

                // --- Bottom control bar: undo / pause / end ---
                HStack(spacing: 12) {
                    // Undo (enabled only right after a turn pass).
                    controlButton(disabled: !game.canUndo) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            game.undoLastTurn()
                        }
                    } label: {
                        Image(systemName: "arrow.uturn.backward")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(MeeplePalette.silver)
                    }

                    // Pause / resume, icon swapping with state.
                    controlButton {
                        game.togglePause()
                    } label: {
                        Image(systemName: game.isPaused ? "play.fill" : "pause.fill")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(MeeplePalette.silver)
                    }

                    // End game — red gradient, saves history and shows results.
                    Button {
                        endGame()
                    } label: {
                        Image(systemName: "stop.fill")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(MeeplePalette.dangerGradient, in: RoundedRectangle(cornerRadius: 14))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 28)
                .background(MeeplePalette.backgroundElevated)
                .overlay(alignment: .top) {
                    Rectangle().fill(MeeplePalette.silver.opacity(0.15)).frame(height: 1)
                }
            }
            .background(MeeplePalette.background)
            .ignoresSafeArea(edges: [.top, .bottom])
        }
        // Keep the phone awake for the whole game (and ONLY the game — restored on exit).
        .onAppear {
            if keepScreenAwakeDuringGames {
                UIApplication.shared.isIdleTimerDisabled = true
            }
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
        }
    }

    // The active player's name for the center circle's "<name> turn" line.
    private var activePlayerName: String {
        game.players.indices.contains(game.activeIndex) ? game.players[game.activeIndex].name : ""
    }

    // Where a wedge's label sits: on an ellipse around the center (32% of the width
    // horizontally, 32% of the height vertically — matching the design's proportions),
    // at the wedge's middle angle. Two-player games are a special case in the design:
    // the halves are TOP and BOTTOM, with each label centered in its half.
    private func labelPosition(seat: Int, totalSeats: Int, in size: CGSize) -> CGPoint {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        guard totalSeats > 1 else { return CGPoint(x: center.x, y: center.y - size.height * 0.32) }

        let sliceDegrees = 360.0 / Double(totalSeats)
        // The design starts wedges at 12 o'clock (-90) for 3+ players, but at 3 o'clock
        // (0) for exactly 2 — which makes the two halves top/bottom instead of left/right,
        // so two players facing each other each get "their" half of the phone.
        let offsetDegrees: Double = totalSeats == 2 ? 0 : -90
        let midDegrees = offsetDegrees + (Double(seat) + 0.5) * sliceDegrees
        let midRadians = midDegrees * .pi / 180

        return CGPoint(
            x: center.x + size.width * 0.32 * cos(midRadians),
            y: center.y + size.height * 0.32 * sin(midRadians)
        )
    }

    // One of the two square silver control buttons (undo / pause).
    private func controlButton(disabled: Bool = false, action: @escaping () -> Void, label: () -> some View) -> some View {
        Button(action: action) {
            label()
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(Color(hex: 0x1C1D20), in: RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(MeeplePalette.silver.opacity(0.3), lineWidth: 1)
                )
        }
        .disabled(disabled)
        .opacity(disabled ? 0.35 : 1)
    }

    // Ends the game: saves the record into SwiftData history and swaps to results.
    private func endGame() {
        // Read the whole-game clock BEFORE endGame() freezes it.
        let durationSeconds = Int(game.gameElapsed().rounded())
        let record = game.endGame()
        AnalyticsService.gameEnded(record: record, durationSeconds: durationSeconds)
        modelContext.insert(record)
        // An explicit save guarantees the game is on disk before anything else happens —
        // good practice even though SwiftData usually autosaves.
        try? modelContext.save()
        finishedRecord = record
    }
}

// DesignWedge draws one pie slice using the redesign's angle convention: slices start at
// 12 o'clock and go clockwise for 3+ players, but at 3 o'clock for exactly 2 players (so
// the two halves are top/bottom). A single player gets the whole circle.
private struct DesignWedge: Shape {
    let seat: Int
    let totalSeats: Int
    let radius: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)

        // Solo game: the "wedge" is just the entire circle.
        guard totalSeats > 1 else {
            path.addEllipse(in: CGRect(
                x: center.x - radius, y: center.y - radius,
                width: radius * 2, height: radius * 2
            ))
            return path
        }

        let sliceDegrees = 360.0 / Double(totalSeats)
        let offsetDegrees: Double = totalSeats == 2 ? 0 : -90
        let startDegrees = offsetDegrees + Double(seat) * sliceDegrees
        let endDegrees = startDegrees + sliceDegrees

        // Center out to the arc and back — the standard pie-slice path. `clockwise: false`
        // is what produces a visually clockwise sweep in SwiftUI's flipped-Y coordinates
        // (same quirk documented in the original WedgeShape).
        path.move(to: center)
        path.addArc(
            center: center,
            radius: radius,
            startAngle: .degrees(startDegrees),
            endAngle: .degrees(endDegrees),
            clockwise: false
        )
        path.closeSubpath()
        return path
    }
}

// WedgeLabel is the meeple + name + running time stack shown inside each wedge. The active
// player's version is bigger, solid black, and gently pulses; inactive ones are smaller
// and translucent. Either alarm — this turn running long, or a countdown player's time bank
// running out — turns the time red.
private struct WedgeLabel: View {
    let player: TimerPlayer
    // Time used (counting up) in stopwatch games; time remaining (counting down, and going
    // negative once the bank is spent) in countdown games.
    let displaySeconds: TimeInterval
    let isCountdown: Bool
    let isActive: Bool
    let isAlarm: Bool

    // Drives the active label's continuous gentle pulse.
    @State private var isPulsing = false

    var body: some View {
        // The dark ink color the design uses on top of the bright gradient wedges.
        let ink = MeeplePalette.background
        let labelColor = isActive ? ink : ink.opacity(0.55)

        VStack(spacing: 2) {
            MeepleShape()
                .fill(isActive ? ink : ink.opacity(0.55))
                .aspectRatio(100.0 / 120.0, contentMode: .fit)
                .frame(width: isActive ? 46 : 28)
            Text(player.name)
                .font(.system(size: isActive ? 19 : 12, weight: .bold))
                .foregroundStyle(labelColor)
            // The signed format only matters in countdown games, where a spent bank keeps
            // counting into negative numbers; used-time can never be negative.
            Text(isCountdown ? displaySeconds.asSignedClockString : displaySeconds.asClockString)
                .font(.system(size: isActive ? 22 : 13, weight: .bold, design: .monospaced))
                .foregroundStyle(isAlarm ? MeeplePalette.overtimeRed : labelColor)
        }
        // The pulse: only the active label scales up and down forever.
        .scaleEffect(isActive && isPulsing ? 1.09 : 1.0)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                isPulsing = true
            }
        }
    }
}

#Preview("Stopwatch") {
    TimerActiveView(game: TimerGameViewModel(
        players: [
            TimerPlayer(name: "Alex", colorIndex: 0),
            TimerPlayer(name: "Sam", colorIndex: 1),
            TimerPlayer(name: "Riley", colorIndex: 2),
            TimerPlayer(name: "Drew", colorIndex: 3),
        ],
        gameName: "Preview Game",
        turnLimitSeconds: 60,
        firstPlayerIndex: 0,
        soundAndHapticsEnabled: false
    ))
    .modelContainer(for: GameRecord.self, inMemory: true)
}

#Preview("Countdown") {
    TimerActiveView(game: TimerGameViewModel(
        players: [
            TimerPlayer(name: "Alex", colorIndex: 0),
            TimerPlayer(name: "Sam", colorIndex: 1),
            TimerPlayer(name: "Riley", colorIndex: 2),
            TimerPlayer(name: "Drew", colorIndex: 3),
        ],
        gameName: "Preview Game",
        mode: .countdown,
        turnLimitSeconds: 60,
        // A tiny bank so the preview reaches the red negative state within seconds.
        totalTimePerPlayerSeconds: 20,
        firstPlayerIndex: 0,
        soundAndHapticsEnabled: false
    ))
    .modelContainer(for: GameRecord.self, inMemory: true)
}

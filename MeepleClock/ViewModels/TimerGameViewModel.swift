import Foundation
import AudioToolbox // For the "turn limit reached" beep.
import UIKit        // For the haptic buzz that accompanies the beep.

// TimerPlayer is one player's live state during a running game in the redesigned flow:
// their identity (name + meeple color) and how much total thinking time they've banked
// from finished turns. The ACTIVE player's on-screen time is this banked value PLUS
// however long their current turn has been running (see `secondsUsed(for:at:)` below) —
// the same drift-free "store when it started, compute elapsed on demand" approach the
// rest of the app's timers use.
struct TimerPlayer: Identifiable {
    // Stable identity for SwiftUI's ForEach.
    let id = UUID()
    // The player's editable display name, e.g. "Alex".
    var name: String
    // Which of the ten MeeplePalette gradients this player uses (0-9).
    var colorIndex: Int
    // Whole seconds banked from this player's FINISHED turns (not counting a turn that's
    // still running right now).
    var bankedSeconds: TimeInterval = 0
}

// TimerGameViewModel is the engine of the redesigned game flow (imported from the approved
// Claude Design prototype): a chess-clock where each player's clock counts UP, with a
// per-turn time limit that flips the display into red "overtime" (with a beep) when
// exceeded, a one-level undo, pause/resume, and a round counter.
//
// `@Observable` (iOS 17) makes every stored property below watchable by SwiftUI — views
// that read them redraw automatically when they change, with no extra plumbing.
@Observable
final class TimerGameViewModel: Identifiable {
    // Stable identity so this can drive `.fullScreenCover(item:)`.
    let id = UUID()

    // Everyone in the game, in seat order around the pie.
    private(set) var players: [TimerPlayer]

    // The game's display name, e.g. "Catan Night" — empty means untitled.
    let gameName: String

    // The per-turn limit in seconds. Turns aren't force-ended at the limit; the active
    // player's display just turns red (and a beep fires) so the table can apply social
    // pressure — matching the design's "overtime" behavior rather than a hard cutoff.
    let turnLimitSeconds: Int

    // Whose turn it is right now (index into `players`).
    private(set) var activeIndex: Int

    // Which seat took the game's very first turn — the round counter increments each time
    // the turn passes back around to this seat.
    private(set) var firstPlayerIndex: Int

    // The current round number, starting at 1.
    private(set) var round: Int = 1

    // Whether the game is currently paused (all clocks frozen).
    private(set) var isPaused = false

    // Whether the current turn has exceeded `turnLimitSeconds`. Stored (rather than only
    // computed) so views can animate/tint on its change, and so the beep can fire exactly
    // once on the moment it flips.
    private(set) var isOvertime = false

    // Whether Sound & Haptics is enabled — copied from Settings when the game starts.
    private let soundAndHapticsEnabled: Bool

    // --- Drift-free time bookkeeping (same pattern as everywhere else in the app) ---

    // When the ACTIVE player's current turn last started/resumed running. `nil` while
    // paused. Elapsed turn time = `turnAccumulated` + (now - this date).
    private var turnStartDate: Date?

    // Turn time banked from BEFORE the most recent pause, for the current turn only.
    private var turnAccumulated: TimeInterval = 0

    // Same two-piece bookkeeping for the WHOLE game's running clock (the center circle).
    private var gameStartDate: Date?
    private var gameAccumulated: TimeInterval = 0

    // The one-level undo snapshot: everything needed to put the game back exactly as it
    // was the moment before the most recent "next turn" tap. `nil` = nothing to undo.
    private struct Snapshot {
        var players: [TimerPlayer]
        var activeIndex: Int
        var round: Int
        var turnAccumulated: TimeInterval
        var turnStartDate: Date?
    }
    private var undoSnapshot: Snapshot?

    // Whether the Undo button should be enabled right now.
    var canUndo: Bool { undoSnapshot != nil }

    // The background task that waits for the current turn to hit the limit and fires the
    // overtime flip + beep. Stored so it can be cancelled whenever the turn changes,
    // pauses, or the game ends.
    private var overtimeWatchTask: Task<Void, Never>?

    // Builds and immediately STARTS a game (the design goes straight from "Start Game"
    // into a running clock — there's no separate "press start" step on the timer screen).
    init(players: [TimerPlayer], gameName: String, turnLimitSeconds: Int, firstPlayerIndex: Int, soundAndHapticsEnabled: Bool) {
        self.players = players
        self.gameName = gameName
        self.turnLimitSeconds = turnLimitSeconds
        // Wrap out-of-range first player indexes back into range rather than crashing.
        let safeFirst = players.isEmpty ? 0 : firstPlayerIndex % players.count
        self.activeIndex = safeFirst
        self.firstPlayerIndex = safeFirst
        self.soundAndHapticsEnabled = soundAndHapticsEnabled

        let now = Date()
        self.turnStartDate = now
        self.gameStartDate = now
        scheduleOvertimeWatch()
    }

    // --- Reading the clocks (called every TimelineView tick by the views) ---

    // Total seconds the whole game has been running (shown in the center circle),
    // excluding paused stretches.
    func gameElapsed(at now: Date = Date()) -> TimeInterval {
        guard let gameStartDate else { return gameAccumulated }
        return gameAccumulated + now.timeIntervalSince(gameStartDate)
    }

    // Seconds elapsed in the CURRENT turn only (what the overtime limit compares against).
    func turnElapsed(at now: Date = Date()) -> TimeInterval {
        guard let turnStartDate else { return turnAccumulated }
        return turnAccumulated + now.timeIntervalSince(turnStartDate)
    }

    // A player's total used time: banked turns, plus the live current turn if it's theirs.
    func secondsUsed(for index: Int, at now: Date = Date()) -> TimeInterval {
        guard players.indices.contains(index) else { return 0 }
        let banked = players[index].bankedSeconds
        return index == activeIndex ? banked + turnElapsed(at: now) : banked
    }

    // --- Game actions ---

    // Ends the active player's turn and starts the next seat clockwise. Saves an undo
    // snapshot first, banks the ending player's time, resets the turn clock, and bumps
    // the round counter when the turn wraps back to the first player.
    func nextTurn() {
        guard !players.isEmpty, !isPaused else { return }
        let now = Date()

        // Snapshot BEFORE changing anything, so Undo can restore this exact moment.
        // `turnAccumulated` is captured as the LIVE elapsed turn time (not the raw stored
        // value, which only updates on pauses) — so an undone pass hands the player back
        // their full in-progress turn time, exactly as it stood when the pass was tapped.
        undoSnapshot = Snapshot(
            players: players,
            activeIndex: activeIndex,
            round: round,
            turnAccumulated: turnElapsed(at: now),
            turnStartDate: turnStartDate
        )

        // Bank the ending player's full turn time into their total.
        players[activeIndex].bankedSeconds += turnElapsed(at: now)

        // Advance clockwise, wrapping past the last seat back to 0.
        let newIndex = (activeIndex + 1) % players.count
        if newIndex == firstPlayerIndex {
            round += 1
        }
        activeIndex = newIndex

        // Fresh turn clock for the new player.
        turnAccumulated = 0
        turnStartDate = now
        isOvertime = false
        scheduleOvertimeWatch()
        playTurnFeedback()
    }

    // Restores the exact pre-`nextTurn` state (one level only, per the design). The time
    // that ticked by since that tap is deliberately discarded — undo means "that tap was
    // a mistake, put everything back."
    func undoLastTurn() {
        guard let snapshot = undoSnapshot else { return }
        players = snapshot.players
        activeIndex = snapshot.activeIndex
        round = snapshot.round
        turnAccumulated = snapshot.turnAccumulated
        // Resume the restored turn from NOW (not its original start date), so the time
        // spent on the mistaken turn isn't silently charged to the restored player.
        turnStartDate = isPaused ? nil : Date()
        undoSnapshot = nil
        isOvertime = turnAccumulated >= Double(turnLimitSeconds)
        scheduleOvertimeWatch()
    }

    // Freezes/unfreezes both clocks (turn + whole game) together.
    func togglePause() {
        let now = Date()
        if isPaused {
            // Resuming: both clocks restart counting from this instant.
            turnStartDate = now
            gameStartDate = now
            isPaused = false
            scheduleOvertimeWatch()
        } else {
            // Pausing: fold whatever has run so far into the banked halves, then stop.
            turnAccumulated = turnElapsed(at: now)
            gameAccumulated = gameElapsed(at: now)
            turnStartDate = nil
            gameStartDate = nil
            isPaused = true
            overtimeWatchTask?.cancel()
        }
    }

    // Ends the game: freezes every clock (banking the active player's live turn) and
    // returns the finished results as a GameRecord, ready for the caller to insert into
    // SwiftData and show on the Results screen.
    func endGame() -> GameRecord {
        let now = Date()
        if !isPaused {
            players[activeIndex].bankedSeconds += turnElapsed(at: now)
            gameAccumulated = gameElapsed(at: now)
        }
        turnStartDate = nil
        gameStartDate = nil
        overtimeWatchTask?.cancel()

        return GameRecord(
            date: now,
            gameName: gameName.isEmpty ? "Untitled Game" : gameName,
            rounds: round,
            players: players.map {
                PlayerResult(name: $0.name, colorIndex: $0.colorIndex, secondsUsed: Int($0.bankedSeconds.rounded()))
            }
        )
    }

    // --- Overtime detection ---

    // Schedules (or reschedules) the background wait that flips `isOvertime` and beeps the
    // instant the current turn crosses the limit. Cancelling and recreating the task on
    // every turn change/pause is what keeps exactly ONE watcher alive for the current turn.
    private func scheduleOvertimeWatch() {
        overtimeWatchTask?.cancel()
        guard !isPaused else { return }

        // How much of the limit is left for this turn. Already over (e.g. after an undo
        // back into an overtime turn)? Mark it immediately, no beep replay.
        let remaining = Double(turnLimitSeconds) - turnElapsed()
        guard remaining > 0 else {
            isOvertime = true
            return
        }

        overtimeWatchTask = Task { [weak self] in
            // Sleep exactly until the limit moment. `try?` because cancellation (turn
            // changed first) just ends the task quietly — the guard below double-checks.
            try? await Task.sleep(nanoseconds: UInt64(remaining * 1_000_000_000))
            guard let self, !Task.isCancelled else { return }
            self.isOvertime = true
            self.playLimitAlert()
        }
    }

    // --- Feedback (respects the Sound & Haptics setting) ---

    // The double-beep + strong buzz fired the moment a turn goes into overtime.
    private func playLimitAlert() {
        guard soundAndHapticsEnabled else { return }
        // 1054 is a short, clear system "note" chime; played twice ~160ms apart to echo
        // the design's double beep. Using built-in system sounds means no audio files.
        AudioServicesPlaySystemSound(1054)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
            AudioServicesPlaySystemSound(1054)
        }
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }

    // The light click + buzz on every normal turn pass.
    private func playTurnFeedback() {
        guard soundAndHapticsEnabled else { return }
        AudioServicesPlaySystemSound(1104) // soft camera-style "tock"
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }
}

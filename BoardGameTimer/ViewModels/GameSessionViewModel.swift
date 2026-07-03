import Foundation

// GameSessionViewModel is the "brain" of the Live Game screen. It remembers what phase the
// game is in, runs the shared Setup/Explanation/Cleanup timer, and runs the chess-clock
// per-player timer during the Playing phase.
//
// `@Observable` is an iOS 17 macro (a compiler feature) that automatically makes every
// stored property below "watchable" by SwiftUI. Any view that reads one of these
// properties will automatically redraw itself whenever that property changes — we don't
// have to write any extra plumbing code for that to work. This replaces the older, more
// verbose `ObservableObject` + `@Published` pattern from before iOS 17.
//
// `final` means no other class can subclass this one — there's no need for subclassing
// here, and marking it `final` lets Swift generate slightly faster code.
@Observable
final class GameSessionViewModel: Identifiable {
    // A stable identity for this view model instance. Having this lets us present the Live
    // Game screen with SwiftUI's `.fullScreenCover(item:)`, which needs its item type to be
    // `Identifiable` (i.e. to have an `id`).
    let id = UUID()

    // Every player in this game, in seat order. `private(set)` means views elsewhere CAN
    // read this array, but only code inside THIS class is allowed to change it — that keeps
    // all the timer/turn-passing rules centralized here instead of scattered across views.
    private(set) var players: [PlayerRuntimeState]

    // Which stage of the game we're currently in (Setup, Explanation, Playing, Cleanup, or
    // Summary). Every game starts at `.setup`.
    private(set) var currentPhase: GamePhase = .setup

    // The index (position in the `players` array) of whoever's turn it is right now.
    // `nil` whenever we're not in the Playing phase — turns only make sense during Playing.
    private(set) var activePlayerIndex: Int?

    // When the CURRENT shared phase timer (Setup/Explanation/Cleanup) was last started.
    // `nil` means that timer is currently paused (or hasn't started yet). We deliberately do
    // NOT store "elapsed seconds so far" as a number that updates every tick — instead we
    // remember the moment it started, and calculate elapsed time fresh every time it's asked
    // for (see `currentPhaseElapsed`). This avoids "drift" bugs where repeatedly adding
    // small time slices builds up rounding errors.
    private(set) var phaseStartDate: Date?

    // How much time had already piled up for the CURRENT phase from previous start/pause
    // cycles, NOT counting whatever time is running right now. Added to the live
    // "time since phaseStartDate" to get the true total (see `currentPhaseElapsed`).
    private(set) var phaseAccumulated: TimeInterval = 0

    // Once a phase finishes (we call `advancePhase()`), its final total duration gets
    // stored here, keyed by which phase it was. Read back later for the Summary screen.
    private(set) var perPhaseDurations: [GamePhase: TimeInterval] = [:]

    // The exact moment this whole game session began — used later to compute the overall
    // total game duration for the Summary screen and saved history.
    let sessionStartDate = Date()

    // When the CURRENTLY ACTIVE player's turn last started running. Mirrors
    // `phaseStartDate`, but for whichever single player is "up" during the Playing phase,
    // rather than for a shared phase timer.
    private var activePlayerTurnStartDate: Date?

    // Sets up a brand new live game with the given players. Called once, right when the
    // user taps "Continue"/"Start Game".
    init(players: [PlayerRuntimeState]) {
        self.players = players
    }

    // Calculates how many seconds the CURRENT phase's shared timer has been running in
    // total, including time from before it was last paused. `now` defaults to the current
    // real-world time, but callers can pass in a specific moment (e.g. from a `TimelineView`
    // tick) so every piece of UI in that same redraw agrees on exactly the same "now."
    func currentPhaseElapsed(at now: Date = Date()) -> TimeInterval {
        // If the timer isn't currently running (`phaseStartDate` is nil), the total is just
        // whatever had already accumulated before it was paused.
        guard let phaseStartDate else { return phaseAccumulated }
        // Otherwise, add the time since it was last started to whatever was already banked.
        return phaseAccumulated + now.timeIntervalSince(phaseStartDate)
    }

    // Calculates how many seconds a SPECIFIC player has accumulated so far, including their
    // currently-running turn (if it's their turn right now). Used by the Playing-phase list
    // to show each player's live-updating time.
    func elapsedTime(for player: PlayerRuntimeState, at now: Date = Date()) -> TimeInterval {
        // Only the active player's clock is "live" right now; everyone else's time is just
        // whatever is already stored on them from previous turns.
        guard player.isActiveTurn, let activePlayerTurnStartDate else {
            return player.accumulatedPlayTime
        }
        return player.accumulatedPlayTime + now.timeIntervalSince(activePlayerTurnStartDate)
    }

    // Whether the shared Setup/Explanation/Cleanup timer is currently ticking (as opposed to
    // paused). Views use this to decide whether to show a "Pause" or "Start" button label.
    var isSharedTimerRunning: Bool {
        phaseStartDate != nil
    }

    // Starts the shared timer if it's paused, or pauses it if it's running. This is the ONLY
    // control for Setup/Explanation/Cleanup — there's no per-player concept during those
    // phases, just one clock for the whole group.
    func toggleSharedTimer() {
        if let phaseStartDate {
            // It was running: fold the time since it started into the banked total, then
            // clear the start date to mark it as paused.
            phaseAccumulated += Date().timeIntervalSince(phaseStartDate)
            self.phaseStartDate = nil
        } else {
            // It was paused: mark "now" as the new start time so elapsed time starts
            // counting again from this instant.
            self.phaseStartDate = Date()
        }
    }

    // Moves the game from the current phase to the next one in line (Setup -> Explanation ->
    // Playing -> Cleanup -> Summary). Freezes the phase that's ending into
    // `perPhaseDurations` first, so its final time is never lost.
    func advancePhase() {
        // Lock in exactly how long the phase we're LEAVING took, before switching away from
        // it, and reset the shared-timer bookkeeping so the next phase starts from zero.
        perPhaseDurations[currentPhase] = currentPhaseElapsed()
        phaseAccumulated = 0
        phaseStartDate = nil

        // `GamePhase.allCases` lists every case in the order they're declared in
        // GamePhase.swift (setup, explanation, playing, cleanup, summary). Finding the
        // current phase's position and adding 1 gives us "whatever comes next."
        let allPhases = GamePhase.allCases
        guard let currentIndex = allPhases.firstIndex(of: currentPhase),
              currentIndex + 1 < allPhases.count else {
            // Already at the last phase (.summary) — nothing further to advance to.
            return
        }
        currentPhase = allPhases[currentIndex + 1]

        // The moment we step INTO the Playing phase, automatically start the first seat's
        // turn clock so the game doesn't sit there with nobody "active."
        if currentPhase == .playing {
            selectPlayer(at: 0)
        }
    }

    // The core chess-clock action: stops whoever's clock is currently running (banking their
    // elapsed time), then starts the clock for the player at `index` and counts this as one
    // of their turns. Works identically whether `index` is "the next player in rotation" or
    // any arbitrary player tapped directly — both `passToNextPlayer()` and "tap any wedge"
    // (added in Milestone 4) call through this same method.
    func selectPlayer(at index: Int) {
        // Safety check: ignore requests for a seat that doesn't exist, rather than crashing.
        guard players.indices.contains(index) else { return }

        let now = Date()

        // If someone was already mid-turn, bank their elapsed time and un-highlight them
        // before we move on to the next player.
        if let previousIndex = activePlayerIndex,
           let activePlayerTurnStartDate,
           players.indices.contains(previousIndex) {
            players[previousIndex].accumulatedPlayTime += now.timeIntervalSince(activePlayerTurnStartDate)
            players[previousIndex].isActiveTurn = false
        }

        // Start the new player's clock: mark them active, count this as a new turn for them,
        // and remember exactly when this turn began.
        players[index].isActiveTurn = true
        players[index].turnCount += 1
        activePlayerIndex = index
        self.activePlayerTurnStartDate = now
    }

    // Convenience wrapper around `selectPlayer(at:)` that hands the turn to whoever comes
    // right after the currently active player, wrapping back to seat 0 after the last seat.
    // This is what a dedicated "Pass Turn" button calls, so the user doesn't have to
    // precisely tap the next player's exact wedge/row every time.
    func passToNextPlayer() {
        // No-op if there are no players at all (shouldn't normally happen, but keeps this
        // safe rather than crashing).
        guard !players.isEmpty else { return }

        guard let activePlayerIndex else {
            // Nobody has taken a turn yet somehow — just start with the first seat.
            selectPlayer(at: 0)
            return
        }

        // `%` ("modulo") wraps the index back to 0 once it would go past the last seat,
        // e.g. after seat 3 in a 4-player game, `(3 + 1) % 4` is 0.
        selectPlayer(at: (activePlayerIndex + 1) % players.count)
    }

    // Allowed from ANY phase: immediately freezes whatever timer is currently running (the
    // shared phase timer, or the active player's clock) and jumps straight to the Summary
    // phase. Real games get abandoned or interrupted, so this is the escape hatch — the user
    // is never stuck without a way out of a running game.
    func endGameEarly() {
        if currentPhase == .playing {
            // Bank whatever time the active player had racked up, then clear the "someone is
            // active" state entirely, since the game is ending.
            if let activePlayerIndex,
               let activePlayerTurnStartDate,
               players.indices.contains(activePlayerIndex) {
                players[activePlayerIndex].accumulatedPlayTime += Date().timeIntervalSince(activePlayerTurnStartDate)
                players[activePlayerIndex].isActiveTurn = false
            }
            self.activePlayerIndex = nil
            self.activePlayerTurnStartDate = nil
        } else {
            // We were in a shared-timer phase (Setup/Explanation/Cleanup) — bank its elapsed
            // time the same way `advancePhase()` would.
            perPhaseDurations[currentPhase] = currentPhaseElapsed()
            phaseAccumulated = 0
            phaseStartDate = nil
        }

        currentPhase = .summary
    }
}

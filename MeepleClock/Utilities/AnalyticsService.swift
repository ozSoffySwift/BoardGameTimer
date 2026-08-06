import Foundation
import FirebaseAnalytics

// AnalyticsService is the app's ONE point of contact with Firebase.
//
// Every screen logs through these typed methods rather than calling Firebase directly, which
// buys three things: `import FirebaseAnalytics` appears in exactly one file (so swapping or
// removing the SDK is a one-file change), event and parameter names are spelled once instead
// of scattered as string literals across views, and it's possible to see everything the app
// reports by reading a single screen of code — which is what the privacy policy has to
// describe accurately.
//
// What is deliberately NOT logged: anything the user typed. No player names, no game names,
// no saved history. Only counts, durations and which mode was used. See PRIVACY.md.
enum AnalyticsService {

    // MARK: - Games

    // A game started from the full Player Setup screen.
    static func gameStarted(
        mode: GameMode,
        playerCount: Int,
        turnLimitSeconds: Int,
        totalTimePerPlayerSeconds: Int,
        randomFirstPlayer: Bool
    ) {
        Analytics.logEvent("game_started", parameters: [
            "mode": mode.rawValue,
            "player_count": playerCount,
            "turn_limit_seconds": turnLimitSeconds,
            // Only meaningful in countdown games; zero keeps the parameter's type stable
            // across both modes, which keeps the Firebase console's charts usable.
            "total_time_seconds": mode == .countdown ? totalTimePerPlayerSeconds : 0,
            "random_first_player": randomFirstPlayer,
        ])
    }

    // A game started from the Home screen's Quick Timer, skipping setup entirely. Logged
    // separately from `game_started` so the two entry points can be compared — that's the
    // whole question of whether Quick Timer earns its place on the Home screen.
    static func quickGameStarted(playerCount: Int) {
        Analytics.logEvent("quick_game_started", parameters: [
            "player_count": playerCount,
        ])
    }

    // A game finished and was saved to history.
    static func gameEnded(record: GameRecord, durationSeconds: Int) {
        Analytics.logEvent("game_ended", parameters: [
            "mode": record.mode.rawValue,
            "player_count": record.players.count,
            "rounds": record.rounds,
            "duration_seconds": durationSeconds,
        ])
    }

    // A countdown player spent their entire time bank. Fires once per player per game, so
    // the count answers "does the default 30 minutes actually fit real games?"
    static func playerOutOfTime(playerCount: Int, totalTimePerPlayerSeconds: Int) {
        Analytics.logEvent("player_out_of_time", parameters: [
            "player_count": playerCount,
            "total_time_seconds": totalTimePerPlayerSeconds,
        ])
    }

    // MARK: - Other actions

    // The Share button on a results screen was tapped. (Whether the user then completed the
    // share is handled by the system sheet and is not visible to the app.)
    static func resultsShared(mode: GameMode) {
        Analytics.logEvent("results_shared", parameters: [
            "mode": mode.rawValue,
        ])
    }

    // Game history was cleared from Settings.
    static func historyCleared(gameCount: Int) {
        Analytics.logEvent("history_cleared", parameters: [
            "game_count": gameCount,
        ])
    }
}

// Turn-level events (every pass, every pause, every undo) are deliberately absent. A single
// long game would fire hundreds of them, which would swamp the far more useful game-level
// numbers above and burn through Firebase's per-app event quota for no real insight.
//
// Screen views need no code here: Firebase collects them automatically.

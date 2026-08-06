import Foundation
import SwiftUI
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

    // MARK: - Screens

    // Every screen worth counting, named once here so the strings can't drift apart between
    // views or be misspelled into a second, silently-empty row in the Firebase console.
    enum Screen: String {
        case home = "home"
        case playerSetup = "player_setup"
        case activeGame = "active_game"
        case results = "results"
        // A finished game re-opened from history, as opposed to one that just ended. Worth
        // separating: they mean very different things about how the app is used.
        case resultsHistory = "results_history"
        case statistics = "statistics"
        case settings = "settings"
        case about = "about"
    }

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

    // "Rate This App" was tapped on the About screen. That button exists for one purpose —
    // driving App Store ratings — so whether anyone actually presses it is worth knowing.
    //
    // This records the TAP, not that a rating happened. iOS decides on its own whether to
    // actually show the prompt (it throttles this to a few times a year per user regardless of
    // how often the app asks), and never tells the app what the user did with it. So a tap here
    // means "wanted to rate", not "rated".
    //
    // `gameCount` rides along to answer the obvious follow-up: are the people reaching for this
    // engaged users with a pile of games behind them, or curious first-timers?
    static func rateAppTapped(gameCount: Int) {
        Analytics.logEvent("rate_app_tapped", parameters: [
            "game_count": gameCount,
        ])
    }
}

// Marks a view as a screen, so Firebase logs a `screen_view` when it appears.
//
// THIS IS NOT OPTIONAL PLUMBING — without it the app reports no screens at all.
//
// Firebase's "automatic" screen tracking works by hooking `UIViewController.viewDidAppear`.
// That does nothing in a SwiftUI app like this one: every screen lives inside a single
// hosting controller, so there is nothing for it to tell apart. Measured on a real device
// build, the ONLY screens auto-collection ever reported were `UIActivityViewController` (the
// share sheet) and `PlatformAlertController` (the clear-history dialog) — both presented by
// the system, neither one of ours. Version 1.1 shipped with no usable screen data because of
// this. See Reports/Analytics-Coverage.md.
//
// Wrapping Firebase's own `.analyticsScreen` here rather than calling it from each view keeps
// `import FirebaseAnalytics` in this one file, which is the rule the whole service is built
// around.
extension View {
    func trackScreen(_ screen: AnalyticsService.Screen) -> some View {
        // `class:` would otherwise default to the literal string "View" for every screen,
        // which is useless in the console; the screen's own name is far more legible.
        analyticsScreen(name: screen.rawValue, class: screen.rawValue)
    }
}

// One thing to know before reading the numbers: `.analyticsScreen` fires on `onAppear`, so it
// counts APPEARANCES, not unique visits. Navigating away and back logs the screen a second
// time — which is usually what you want, but it means these are not distinct-user-journey
// counts. Measured over a ten-step walk through the app, it was exactly 1:1 with navigation
// (no spurious duplicates from tab switching or sheets); the only repeats were screens
// genuinely returned to.

// Turn-level events (every pass, every pause, every undo) are deliberately absent. A single
// long game would fire hundreds of them, which would swamp the far more useful game-level
// numbers above and burn through Firebase's per-app event quota for no real insight.

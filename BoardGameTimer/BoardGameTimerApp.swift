import SwiftUI

// `@main` marks this as the entry point of the whole app — the very first thing that runs
// when the app launches. Every SwiftUI app needs exactly one type marked `@main`.
@main
struct BoardGameTimerApp: App {
    // `body` describes the app's overall window/scene structure. For a simple, single-window
    // iPhone app like this one, that's almost always just one `WindowGroup`.
    var body: some Scene {
        WindowGroup {
            // NavigationStack manages "screen A pushes to screen B pushes to screen C"
            // navigation, including automatically showing a back button. PlayerCountView is
            // the very first screen the user sees when the app opens.
            NavigationStack {
                PlayerCountView()
            }
        }
    }
}

import SwiftUI

// `@main` marks this as the entry point of the whole app — the very first thing that runs
// when the app launches. Every SwiftUI app needs exactly one type marked `@main`.
@main
struct BoardGameTimerApp: App {
    // Whether the branded splash screen is currently covering the real app content.
    // `@State` here lives at the very top of the app, so it survives for as long as the app
    // is running (until the user force-quits it) — starting `true` means every fresh launch
    // shows the splash screen first.
    @State private var isShowingSplash = true

    // Read from the Settings screen (see SettingsView.swift) — whether to force light/dark
    // appearance everywhere, or just follow the system setting. Stored as a plain `String`
    // because `@AppStorage` only understands simple types directly; `AppearancePreference`
    // is what turns that string back into a real, usable value (see its own file for why).
    @AppStorage("appearancePreference") private var appearancePreferenceRawValue = AppearancePreference.system.rawValue

    // `body` describes the app's overall window/scene structure. For a simple, single-window
    // iPhone app like this one, that's almost always just one `WindowGroup`.
    var body: some Scene {
        WindowGroup {
            // `ZStack` layers views on top of each other (unlike VStack/HStack, which lay
            // views out side-by-side). The real app content goes in first (bottom layer),
            // and the splash screen is layered on top of it — so the moment the splash
            // fades away, the real app is already sitting there underneath, ready to show.
            ZStack {
                // MainTabView is the real root of the app once the splash is gone — a
                // Timer/Settings/About tab bar, with the Timer tab starting at
                // PlayerCountView exactly like before this tab bar existed.
                MainTabView()

                // Only actually present in the view hierarchy while `isShowingSplash` is
                // true — SwiftUI adds/removes it automatically as that flag changes.
                if isShowingSplash {
                    SplashScreenView()
                        // `.transition` describes HOW this view should animate in/out when
                        // it's added/removed from the hierarchy (as opposed to `.animation`,
                        // which animates a value that's already there). `.opacity` here means
                        // "cross-fade" rather than a hard cut when the splash disappears.
                        .transition(.opacity)
                }
            }
            // Applying this at the very root means EVERY screen in the app (including the
            // splash screen and all three tabs) respects the same appearance choice, not
            // just whichever screen happens to be on top when the setting changes.
            .preferredColorScheme(AppearancePreference(rawValue: appearancePreferenceRawValue)?.colorScheme)
            .onAppear {
                // Keep the splash screen up for a couple of seconds — long enough to read
                // the logo/name/credit, short enough that it never feels like the app is
                // slow to start. `DispatchQueue.main.asyncAfter` waits in the background
                // without freezing anything else, then runs the code inside its closure.
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
                    // Wrapping the flag change in `withAnimation` makes the splash screen's
                    // `.transition(.opacity)` actually animate (a smooth cross-fade) instead
                    // of instantly popping out of existence.
                    withAnimation(.easeInOut(duration: 0.5)) {
                        isShowingSplash = false
                    }
                }
            }
        }
    }
}

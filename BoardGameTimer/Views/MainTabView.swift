import SwiftUI

// MainTabView is the app's real root screen once the splash animation finishes: a
// three-tab bottom bar for switching between the actual game timer, app settings, and an
// About screen with developer/links info. Each tab gets its OWN `NavigationStack`, so
// pushing a screen in one tab (not that any currently do) wouldn't affect the others —
// the standard SwiftUI pattern for a multi-tab app.
struct MainTabView: View {
    var body: some View {
        TabView {
            NavigationStack {
                PlayerCountView()
            }
            .tabItem {
                Label("Timer", systemImage: "timer")
            }

            NavigationStack {
                SettingsView()
            }
            .tabItem {
                Label("Settings", systemImage: "gearshape.fill")
            }

            NavigationStack {
                AboutView()
            }
            .tabItem {
                Label("About", systemImage: "info.circle.fill")
            }
        }
    }
}

#Preview {
    MainTabView()
}

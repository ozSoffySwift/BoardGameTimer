import SwiftUI

// MainTabView is the app's root once the splash finishes — redesigned to match the Claude
// Design prototype's three tabs: Statistics (game history), Timer (the main flow, selected
// by default), and Settings. Each tab has its own NavigationStack so navigation in one
// never disturbs the others.
struct MainTabView: View {
    // Which tab is selected. Starts on Timer (the center tab) — the app's main purpose.
    @State private var selectedTab: Tab = .timer

    // The three tabs, named so the selection state reads clearly.
    enum Tab {
        case stats, timer, settings
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                StatisticsView()
            }
            .tabItem {
                Label("Statistics", systemImage: "chart.bar.fill")
            }
            .tag(Tab.stats)

            NavigationStack {
                TimerHomeView()
            }
            .tabItem {
                Label("Timer", systemImage: "timer")
            }
            .tag(Tab.timer)

            NavigationStack {
                SettingsView()
            }
            .tabItem {
                Label("Settings", systemImage: "gearshape.fill")
            }
            .tag(Tab.settings)
        }
        // The silver accent for the selected tab icon, matching the design's tab bar.
        .tint(.white)
    }
}

#Preview {
    MainTabView()
        .modelContainer(for: GameRecord.self, inMemory: true)
        .preferredColorScheme(.dark)
}

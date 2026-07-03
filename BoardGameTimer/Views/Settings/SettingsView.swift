import SwiftUI

// SettingsView lets the user tweak a handful of small preferences that change how the app
// behaves during a game. Every setting here is backed by `@AppStorage`, SwiftUI's built-in
// wrapper around `UserDefaults` — it works exactly like `@State` (read it, write it, the
// view updates automatically), except the value is also saved to disk automatically and is
// still there the next time the app launches, with zero manual file-reading/writing code.
struct SettingsView: View {
    // Whether the screen should be prevented from auto-locking while a game is in progress
    // — read by LiveGameView, which is where this setting actually takes effect. Defaults
    // to `true` since a timer that's constantly interrupted by the screen locking would be
    // pretty frustrating.
    @AppStorage("keepScreenAwakeDuringGames") private var keepScreenAwakeDuringGames = true

    // Whether turn changes trigger a haptic (vibration) buzz — read by PlayingPieView.
    @AppStorage("hapticFeedbackEnabled") private var hapticFeedbackEnabled = true

    // Whether turn changes play a short system sound — also read by PlayingPieView.
    @AppStorage("soundEffectsEnabled") private var soundEffectsEnabled = true

    // Which color scheme to force (or "system" to just follow the rest of iOS). Stored as
    // the enum's raw `String` because `@AppStorage` only understands simple types directly
    // — `rawValue`/`init?(rawValue:)` is how we translate between that plain string and the
    // real `AppearancePreference` enum everywhere else in the code.
    @AppStorage("appearancePreference") private var appearancePreferenceRawValue = AppearancePreference.system.rawValue

    // A computed property that reads/writes `appearancePreferenceRawValue` but as the real
    // enum type — lets the `Picker` below work directly with `AppearancePreference` values
    // instead of juggling raw strings itself.
    private var appearancePreference: Binding<AppearancePreference> {
        Binding(
            get: { AppearancePreference(rawValue: appearancePreferenceRawValue) ?? .system },
            set: { appearancePreferenceRawValue = $0.rawValue }
        )
    }

    var body: some View {
        Form {
            Section {
                Toggle(isOn: $keepScreenAwakeDuringGames) {
                    Label("Keep Screen Awake During Games", systemImage: "sun.max.fill")
                }
                Toggle(isOn: $hapticFeedbackEnabled) {
                    Label("Haptic Feedback", systemImage: "iphone.radiowaves.left.and.right")
                }
                Toggle(isOn: $soundEffectsEnabled) {
                    Label("Sound Effects", systemImage: "speaker.wave.2.fill")
                }
            } header: {
                Text("Gameplay")
            }

            Section {
                // A segmented picker (rather than a list of rows) since there are only
                // three short options — the standard, compact way to present "pick exactly
                // one of a few things" in a Settings screen.
                Picker("Appearance", selection: appearancePreference) {
                    ForEach(AppearancePreference.allCases) { preference in
                        Text(preference.displayName).tag(preference)
                    }
                }
                .pickerStyle(.segmented)
            } header: {
                Text("Appearance")
            }

            Section {
                Button(role: .destructive) {
                    // Setting each @AppStorage value back to its original default is all
                    // "reset" needs to do — there's no separate "factory settings" file to
                    // restore from, these three lines ARE the complete set of defaults.
                    keepScreenAwakeDuringGames = true
                    hapticFeedbackEnabled = true
                    soundEffectsEnabled = true
                    appearancePreferenceRawValue = AppearancePreference.system.rawValue
                } label: {
                    Text("Reset to Defaults")
                }
            }

            // A small, informational footer — common in Settings screens so users (and you,
            // debugging a bug report) can see exactly which build they're running.
            Section {
                HStack {
                    Text("Version")
                    Spacer()
                    Text(appVersionString)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Settings")
    }

    // Reads the app's version and build numbers directly out of its own Info.plist (filled
    // in automatically by Xcode from the project's MARKETING_VERSION/CURRENT_PROJECT_VERSION
    // build settings), so this text is never manually typed and never goes stale.
    private var appVersionString: String {
        let shortVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(shortVersion) (\(buildNumber))"
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
}

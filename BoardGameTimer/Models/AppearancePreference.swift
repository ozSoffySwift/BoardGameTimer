import SwiftUI

// AppearancePreference is the user's choice of light/dark/system appearance, set on the
// Settings screen. It's a plain enum (not a SwiftData @Model) because it's a tiny, single
// value saved with `@AppStorage` — SwiftUI's built-in way to persist a simple setting to
// disk automatically, no manual file-reading/writing code needed.
//
// `String` after the colon means each case is stored as readable text ("system", "light",
// "dark") rather than a raw number — handy for debugging, and required by `@AppStorage`
// anyway, which needs a plain, storable type like String/Int/Bool.
enum AppearancePreference: String, CaseIterable, Identifiable {
    // Follow whatever appearance the rest of iOS is currently using (Settings > Display).
    case system
    // Always use the light color scheme, regardless of the system setting.
    case light
    // Always use the dark color scheme, regardless of the system setting.
    case dark

    // `Identifiable` conformance, needed so SwiftUI's `Picker` can tell each case apart
    // when looping over `AppearancePreference.allCases`. The case's own raw text doubles
    // perfectly as a unique id — no separate UUID needed for a fixed, tiny enum like this.
    var id: String { rawValue }

    // The friendly label shown in the Settings picker for this case, e.g. "System".
    var displayName: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }

    // Converts this preference into the real `ColorScheme` value SwiftUI's
    // `.preferredColorScheme(_:)` view modifier expects. Returning `nil` for `.system` is
    // what tells SwiftUI "don't override anything, just follow the system setting" — passing
    // an actual `.light`/`.dark` value is what FORCES that specific appearance everywhere.
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

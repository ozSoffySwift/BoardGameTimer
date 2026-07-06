import SwiftUI

// MeeplePalette is the single source of truth for the app's redesigned look (imported from
// the approved Claude Design prototype): a dark, near-black background with silver accents,
// and ten fixed gradient colors used for player meeples and pie wedges. Every screen reads
// its colors from here rather than hardcoding hex values inline, so the whole app can be
// re-themed by editing this one file.
enum MeeplePalette {
    // The ten player gradients, each a (light stop, dark stop) pair — index 0 is blue,
    // 1 red, 2 yellow, 3 green, 4 purple, 5 black, 6 pink, 7 orange, 8 teal, 9 white.
    // These exact hex pairs come straight from the design file's SVG gradient definitions.
    static let gradientStops: [(start: Color, end: Color)] = [
        (Color(hex: 0x9FD8FF), Color(hex: 0x3B9EFF)), // 0 blue
        (Color(hex: 0xFFA3A3), Color(hex: 0xFF4D4D)), // 1 red
        (Color(hex: 0xFFF3A3), Color(hex: 0xFFD60A)), // 2 yellow
        (Color(hex: 0xB9F6CA), Color(hex: 0x34D399)), // 3 green
        (Color(hex: 0xE0B3FF), Color(hex: 0xA855F7)), // 4 purple
        (Color(hex: 0x6B7280), Color(hex: 0x1F2328)), // 5 black
        (Color(hex: 0xFFAFDD), Color(hex: 0xFF5CA8)), // 6 pink
        (Color(hex: 0xFFD199), Color(hex: 0xFF9F1C)), // 7 orange
        (Color(hex: 0xA0F0E8), Color(hex: 0x14C7BE)), // 8 teal
        (Color(hex: 0xFFFFFF), Color(hex: 0xD8DCE0)), // 9 white/silver
    ]

    // Returns the diagonal gradient for a player color index. `% count` wraps out-of-range
    // indexes back around instead of crashing (e.g. if an old saved game somehow stored 12).
    static func gradient(_ index: Int) -> LinearGradient {
        let stops = gradientStops[abs(index) % gradientStops.count]
        // `topLeading -> bottomTrailing` matches the design's 135-degree CSS gradients.
        return LinearGradient(
            colors: [stops.start, stops.end],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    // --- The dark theme's fixed colors, named after their role rather than their look ---

    // The near-black screen background behind everything.
    static let background = Color(hex: 0x0A0B0D)
    // A slightly lighter near-black used behind the bottom control bar and tab bar.
    static let backgroundElevated = Color(hex: 0x111214)
    // Card/panel surfaces sitting on top of the background.
    static let card = Color(hex: 0x18191C)
    // Smaller controls sitting on top of cards (steppers, chips, the +/- buttons).
    static let control = Color(hex: 0x232427)
    // The main silver accent — used for icons, borders, and the silver gradient buttons.
    static let silver = Color(hex: 0xC7CCD1)
    // The darker end of the silver gradient, also the muted/secondary text color base.
    static let silverDark = Color(hex: 0x8A8F94)
    // Muted gray for secondary text (dates, captions, section headers).
    static let textSecondary = Color(hex: 0x8A8F94)
    // The subtle silver border drawn around cards, at low opacity.
    static let cardBorder = Color(hex: 0xC7CCD1).opacity(0.18)

    // The silver "primary button" gradient (e.g. Start Game, Done).
    static let silverGradient = LinearGradient(
        colors: [Color(hex: 0xC7CCD1), Color(hex: 0x8A8F94)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // The red "danger" gradient used for the End Game button and destructive confirms.
    static let dangerGradient = LinearGradient(
        colors: [Color(hex: 0xFF9B85), Color(hex: 0xB4222B)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // The soft red used for overtime timer text and the Clear History label.
    static let dangerText = Color(hex: 0xFF9B85)
    // The bright red used for an active player's time once they're over the turn limit.
    static let overtimeRed = Color(hex: 0xFF3B3B)
}

extension Color {
    // Builds a Color from a hex number like 0x9FD8FF — the same 6-digit RGB notation the
    // design file uses — so the palette above can be copied from the design verbatim.
    // Each pair of hex digits is one channel: 0x9F red, 0xD8 green, 0xFF blue, each 0-255,
    // divided by 255 because SwiftUI colors want 0.0-1.0 fractions.
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0
        )
    }
}

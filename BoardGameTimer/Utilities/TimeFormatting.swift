import Foundation

// This file has one job: turn a raw number of seconds (a `TimeInterval`) into a friendly
// "M:SS" string like "1:07" or "12:34" to show on screen. Keeping this in one place means
// every screen that shows a time (pie wedges, phase banner, summary, history) formats it
// exactly the same way, instead of each screen writing its own slightly-different version.
extension TimeInterval {
    // Converts this TimeInterval (a number of seconds, e.g. 67.0) into a "M:SS" string
    // (e.g. "1:07"). It's a computed property, so it's used like `someDuration.asClockString`
    // rather than `someDuration.asClockString()` — no parentheses needed.
    var asClockString: String {
        // TimeInterval is measured in seconds (as a Double), so first round it and convert
        // to a whole number of seconds — we don't need to show tenths of a second on screen.
        let totalSeconds = Int(self.rounded())

        // Integer division by 60 gives the number of whole minutes (Swift's `/` on two Ints
        // truncates/drops any remainder automatically).
        let minutes = totalSeconds / 60

        // The remainder after removing those minutes gives the leftover seconds (0 through 59).
        let seconds = totalSeconds % 60

        // `%02d` pads the seconds with a leading zero when needed (e.g. "05" instead of "5"),
        // which is how clocks are normally displayed. Minutes are deliberately NOT
        // zero-padded, so we show "1:07" rather than "01:07".
        return String(format: "%d:%02d", minutes, seconds)
    }
}

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

    // The same "M:SS" format, but correct for NEGATIVE times: "-1:07" rather than "-1:-07".
    //
    // Countdown games need this because a player who spends their whole time bank keeps
    // counting past zero into the red — running out is deliberately soft, so the clock has to
    // be able to say how far over they are. `asClockString` can't do it on its own: Swift's
    // integer division and remainder both keep the sign, so -67 seconds would come out as
    // minutes = -1 and seconds = -7, printing "-1:-07". Stripping the sign first and putting
    // a single "-" on the front is the whole fix.
    var asSignedClockString: String {
        // `< -0.5` rather than `< 0` so a value a hair under zero (say -0.2 of a second,
        // which rounds to "0:00") isn't labelled "-0:00".
        let isNegative = self < -0.5
        return (isNegative ? "-" : "") + abs(self).asClockString
    }

    // A friendly duration for the setup fields that deal in minutes rather than seconds,
    // e.g. "30 min", "1 hr", "1 hr 30 min".
    //
    // The M:SS clock format above is right for a running game clock but wrong for a time
    // BUDGET: a 90-minute bank would render as "90:00", which reads like ninety seconds at
    // a glance. Spelling out the units removes the ambiguity.
    var asMinutesLabel: String {
        let totalMinutes = Int((self / 60).rounded())
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60

        switch (hours, minutes) {
        case (0, _): return "\(minutes) min"
        case (_, 0): return "\(hours) hr"
        default: return "\(hours) hr \(minutes) min"
        }
    }
}

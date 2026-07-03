import SwiftUI

// FirstPlayerPickerView is the "everybody put a finger on the screen" mini-game shown right
// after game setup, before the real timer starts. Each player rests one finger anywhere on
// the screen; once at least two fingers have been down and HELD STILL for a moment, a
// little animated "wave" hops between the fingers, gradually slowing down, and finally
// lands on one — that finger's owner goes first.
//
// Which SEAT that corresponds to (seat 0, 1, 2, ...) is worked out from the ANGLE of the
// winning finger relative to the center of the screen, using the exact same "-90 degrees,
// clockwise-increasing" convention as WedgeShape/PieLayoutView — so whichever pie wedge the
// winning finger happens to be resting closest to is the seat that goes first. This means
// players don't need to know their seat NUMBER ahead of time; they just touch near where
// they're sitting and the math figures out the rest.
struct FirstPlayerPickerView: View {
    // How many players are in this game — used both to decide which seat a touch maps to,
    // and to cap how many fingers we bother tracking.
    let playerCount: Int

    // Called once a winner has been chosen, with the SEAT INDEX (0-based) that should take
    // the first turn.
    let onPicked: (Int) -> Void

    // Called if the user backs out of this screen entirely (e.g. they opened it by mistake).
    let onCancel: () -> Void

    // Every finger currently touching the screen, as last reported by MultiTouchDetectorView.
    @State private var activeTouches: [FingerTouchPoint] = []

    // A stable color assigned to each finger the first time we see it, so a finger's dot
    // doesn't change color while it's still down. Keyed by the same `ObjectIdentifier`
    // FingerTouchPoint uses.
    @State private var colorByTouchID: [ObjectIdentifier: Color] = [:]

    // Once true, we've locked in a fixed snapshot of fingers and are running the "wave"
    // reveal animation — new touches are ignored until this whole screen is dismissed.
    @State private var isResolving = false

    // The frozen list of fingers the wave animation plays out over, captured the instant we
    // started resolving (see `beginResolving`).
    @State private var lockedTouches: [FingerTouchPoint] = []

    // Which finger (by id) is currently lit up as the wave "visits" it during the
    // animation, and which one it finally lands on.
    @State private var highlightedTouchID: ObjectIdentifier?
    @State private var winningTouchID: ObjectIdentifier?

    // The currently-running "wait for stillness" countdown, if any. Kept as a `Task` (not a
    // Bool) so we can actually CANCEL it — every time the set of fingers changes, we cancel
    // whatever countdown was running and start a fresh one, which naturally means the
    // countdown only ever finishes once fingers stop changing for a full 1.2 seconds.
    @State private var countdownTask: Task<Void, Never>?

    // The on-screen size of the detector surface, needed to convert a finger's raw pixel
    // position into an angle-from-center for the seat-mapping math.
    @State private var screenSize: CGSize = .zero

    // Fingers must be held for this long, unchanged, before we lock in and start picking.
    private let requiredStillnessSeconds = 1.2

    // At least this many fingers must be down before the countdown even starts — one lonely
    // finger isn't a "pick who goes first" moment.
    private let minimumTouchesToStart = 2

    // The same sample color list used elsewhere (PlayerRuntimeState.sampleData), reused here
    // so a finger's color feels consistent with the rest of the app's palette.
    private let colorPalette: [Color] = [.red, .teal, .orange, .purple, .mint, .blue, .pink, .green]

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color(.systemBackground)

                // The invisible UIKit surface doing the actual multi-finger detection,
                // covering the whole screen so a finger can rest ANYWHERE.
                MultiTouchDetectorView { touches in
                    handleTouchesChanged(touches)
                }

                // One colored dot per finger currently down (or, once we're resolving, per
                // finger in the frozen `lockedTouches` snapshot, so dots don't disappear
                // mid-animation if someone lifts their finger early).
                ForEach(isResolving ? lockedTouches : activeTouches) { touch in
                    Circle()
                        .fill(color(for: touch.id))
                        .frame(width: 60, height: 60)
                        .overlay(
                            // A bright ring appears around the eventual winner once chosen.
                            Circle().stroke(Color.white, lineWidth: winningTouchID == touch.id ? 4 : 0)
                        )
                        // Grows briefly whenever the wave animation is "visiting" this
                        // finger, so it visibly pulses as the pick sweeps past it.
                        .scaleEffect(highlightedTouchID == touch.id ? 1.4 : 1.0)
                        .position(touch.location)
                }
                .animation(.easeInOut(duration: 0.15), value: highlightedTouchID)

                VStack {
                    HStack {
                        Button(action: onCancel) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 18, weight: .semibold))
                                .padding(12)
                        }
                        Spacer()
                    }
                    Spacer()
                    Text(instructionText)
                        .font(.system(.title3, design: .rounded).weight(.semibold))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                        .padding(.bottom, 60)
                }
            }
            // `GeometryReader`'s `geometry.size` is how big this whole screen is, in
            // points — we need it to work out each finger's angle from the exact center.
            .onAppear { screenSize = geometry.size }
            .onChange(of: geometry.size) { _, newSize in screenSize = newSize }
        }
        .ignoresSafeArea()
    }

    // The instruction text shown at the bottom, describing whatever's happening right now.
    private var instructionText: String {
        if isResolving {
            return "Picking who goes first\u{2026}"
        } else if activeTouches.count < minimumTouchesToStart {
            return "Everyone place one finger on the screen"
        } else {
            return "Hold still\u{2026}"
        }
    }

    // Looks up (or assigns, the first time we see a finger) that finger's stable color.
    private func color(for id: ObjectIdentifier) -> Color {
        colorByTouchID[id] ?? .gray
    }

    // Called every time MultiTouchDetectorView reports a change in who's touching the
    // screen (a finger went down, moved, or lifted).
    private func handleTouchesChanged(_ touches: [FingerTouchPoint]) {
        // Once we've already locked in and started the reveal animation, further finger
        // changes don't matter anymore — ignore them so the animation isn't disrupted.
        guard !isResolving else { return }

        activeTouches = touches

        // Give any brand-new finger a color from the palette, cycling back to the start if
        // there are ever more fingers down than colors (shouldn't happen at 8 players and 8
        // colors, but wrapping around is safer than crashing or showing no color at all).
        for touch in touches where colorByTouchID[touch.id] == nil {
            colorByTouchID[touch.id] = colorPalette[colorByTouchID.count % colorPalette.count]
        }

        if touches.count >= minimumTouchesToStart {
            restartCountdown(with: touches)
        } else {
            // Not enough fingers down (anymore) — cancel any countdown in progress so we
            // don't pick a winner from a set of fingers that's no longer accurate.
            countdownTask?.cancel()
            countdownTask = nil
        }
    }

    // (Re)starts the "wait for stillness" timer. Called on EVERY touch change while enough
    // fingers are down, which means any change at all pushes the countdown back — it can
    // only finish if the fingers stop changing for a full `requiredStillnessSeconds`.
    private func restartCountdown(with touches: [FingerTouchPoint]) {
        countdownTask?.cancel()
        countdownTask = Task {
            let nanoseconds = UInt64(requiredStillnessSeconds * 1_000_000_000)
            try? await Task.sleep(nanoseconds: nanoseconds)
            // If this task was cancelled (because fingers changed again) while sleeping,
            // `Task.isCancelled` becomes true and we bail out without picking anyone.
            guard !Task.isCancelled else { return }
            beginResolving(with: touches)
        }
    }

    // Locks in the current fingers as a fixed snapshot and kicks off the reveal animation.
    private func beginResolving(with touches: [FingerTouchPoint]) {
        guard !isResolving else { return }
        isResolving = true
        lockedTouches = touches
        Task { await runWaveAnimation() }
    }

    // Plays the "hop between fingers, slowing down, land on one" reveal, then reports the
    // winning seat back to whoever presented this screen.
    private func runWaveAnimation() async {
        guard let winner = lockedTouches.randomElement() else { return }

        // Build a sequence of fingers to visit before the final landing — a handful of
        // quick, evenly-spaced hops around the group, so it reads as "randomly picking"
        // rather than jumping straight to the answer.
        let extraHops = Int.random(in: (lockedTouches.count * 2)...(lockedTouches.count * 3))
        var hopSequence: [FingerTouchPoint] = (0..<extraHops).map { lockedTouches[$0 % lockedTouches.count] }
        hopSequence.append(winner)

        for (index, touch) in hopSequence.enumerated() {
            let isFinalHop = index == hopSequence.count - 1
            withAnimation(.easeInOut(duration: isFinalHop ? 0.5 : 0.12)) {
                highlightedTouchID = touch.id
            }
            // Each hop waits a little longer than the last, so the wave visibly slows down
            // before landing — the same "roulette wheel coming to a stop" feeling as the
            // mockup's CSS animation, just built with real delays instead.
            let hopNanoseconds = UInt64(90_000_000 + index * 12_000_000)
            try? await Task.sleep(nanoseconds: isFinalHop ? 500_000_000 : hopNanoseconds)
        }

        withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
            winningTouchID = winner.id
        }

        // Pause a moment so the highlighted winner is actually visible before we move on.
        try? await Task.sleep(nanoseconds: 900_000_000)

        let seat = seatIndex(for: winner.location, in: screenSize)
        onPicked(seat)
    }

    // Works out which pie seat (0-based) is closest to the given point, measured as an
    // angle from the center of the screen — using the EXACT SAME "-90 degrees start,
    // increasing clockwise" convention as WedgeShape.swift and PieLayoutView.swift. This is
    // what lets a finger placed anywhere near "the top" or "the bottom" of the phone
    // correctly map onto whichever wedge will end up there once the real pie is shown.
    private func seatIndex(for point: CGPoint, in size: CGSize) -> Int {
        guard playerCount > 0 else { return 0 }

        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let dx = point.x - center.x
        let dy = point.y - center.y

        // `atan2` gives the angle of this point from the center, in the standard math
        // convention (0 degrees = due east/3 o'clock, increasing counter-clockwise).
        let rawAngleDegrees = atan2(dy, dx) * 180 / .pi

        // Converts that into WedgeShape's convention: 0 degrees = 12 o'clock, increasing
        // CLOCKWISE. Adding 360 before the modulo guarantees a positive result regardless
        // of whether `rawAngleDegrees` was negative.
        let adjustedAngleDegrees = (rawAngleDegrees + 90 + 360).truncatingRemainder(dividingBy: 360)

        let anglePerWedge = 360.0 / Double(playerCount)
        let seat = Int(adjustedAngleDegrees / anglePerWedge)
        return seat % playerCount
    }
}

#Preview {
    FirstPlayerPickerView(playerCount: 4, onPicked: { _ in }, onCancel: {})
}

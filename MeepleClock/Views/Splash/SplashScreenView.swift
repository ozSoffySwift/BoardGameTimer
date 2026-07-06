import SwiftUI

// SplashScreenView is the very first thing shown when the app launches — a brief branding
// moment (logo animating in, the app's name, and a "Developed by" credit) before the real
// app appears. This is DIFFERENT from iOS's built-in static "Launch Screen"
// (the blank instant placeholder Apple shows while the app is still loading, configured via
// `INFOPLIST_KEY_UILaunchScreen_Generation` in the Xcode project settings) — that one can't
// animate or show custom text, so this view exists purely inside our own SwiftUI code,
// shown for a couple of seconds by MeepleClockApp before it swaps to the main tab bar.
struct SplashScreenView: View {
    // These four `@State` values all start "hidden"/"small" and get animated to their final
    // values once this view appears on screen (see `.onAppear` below). Splitting the logo,
    // the app name, and the credit line into separate booleans/numbers lets each one animate
    // in at a slightly different moment, instead of everything popping in all at once.

    // How big the logo is drawn, as a multiplier (1.0 = full size). Starts small so it can
    // animate up to full size, like it's "popping in."
    @State private var logoScale: CGFloat = 0.4

    // How see-through the logo is (0 = invisible, 1 = fully visible). Starts invisible so it
    // can fade in at the same time it scales up.
    @State private var logoOpacity: Double = 0

    // A slight starting tilt (in degrees) that animates back to 0, so the logo looks like it
    // "settles" into place rather than just growing straight on.
    @State private var logoRotationDegrees: Double = -18

    // Whether the app name text below the logo is visible yet. Kept separate from the logo's
    // own animation state so the name can fade in slightly AFTER the logo, not at the exact
    // same instant — that staggering is what makes the intro feel designed rather than abrupt.
    @State private var showAppName = false

    // Whether the small "Developed by Oz Soffy" credit at the bottom is visible yet. This is
    // the last thing to appear, timed slightly after the app name.
    @State private var showCredit = false

    var body: some View {
        // A plain VStack stacks the logo, app name, and credit vertically, with Spacers
        // above and below so everything sits centered with the credit pinned toward the
        // bottom rather than glued to the very edge of the screen.
        VStack {
            Spacer()

            logoMark
                // Animate scale/opacity/rotation using the @State values above — because
                // these are plain modifiers (not wrapped in their own `withAnimation`), they
                // automatically animate smoothly whenever the underlying @State numbers
                // change, using whatever animation was active at the time (set in onAppear).
                .scaleEffect(logoScale)
                .opacity(logoOpacity)
                .rotationEffect(.degrees(logoRotationDegrees))

            // The app's name, in the same rounded/bold style used elsewhere in the app.
            Text("Meeple Clock")
                .font(.system(.title, design: .rounded).weight(.bold))
                .padding(.top, 24)
                // Only visible once `showAppName` flips to true; fades in/out rather than
                // snapping instantly, thanks to `.animation` further down.
                .opacity(showAppName ? 1 : 0)
                // A small upward slide alongside the fade — starts 8pt lower and rises into
                // place, a common, subtle "arriving" motion for splash-screen text.
                .offset(y: showAppName ? 0 : 8)

            Spacer()

            // The developer credit line, small and muted so it reads as a signature rather
            // than competing with the app name for attention.
            Text("Developed by Oz Soffy")
                .font(.system(.footnote, design: .rounded))
                .foregroundStyle(.secondary)
                .padding(.bottom, 32)
                .opacity(showCredit ? 1 : 0)
        }
        // Without this, the VStack only takes up as much width/height as its content
        // actually needs (just wide enough for the "Meeple Clock" text) — the
        // background color below would then only fill THAT small box, leaving the real
        // screen underneath visible at the edges. `.frame(maxWidth: .infinity, maxHeight:
        // .infinity)` stretches the VStack to fill all available space first, so the
        // background actually covers the entire screen.
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // A plain system background so the splash screen matches light/dark mode
        // automatically, exactly like every other screen in the app.
        .background(Color(.systemBackground))
        // `.ignoresSafeArea()` lets the background fill the whole screen edge-to-edge, the
        // same full-bleed treatment used on the Live Game screen.
        .ignoresSafeArea()
        // Runs once, the moment this view first appears on screen — this is where all the
        // "starting hidden/small" state above gets animated to its final, fully-visible form.
        .onAppear {
            // `withAnimation` tells SwiftUI "animate any @State changes made inside this
            // block smoothly," instead of just snapping to the new values instantly.
            // `.spring(...)` gives the logo a gentle bounce/overshoot as it settles, which
            // reads as a lively "pop" rather than a flat fade.
            withAnimation(.spring(response: 0.6, dampingFraction: 0.65)) {
                logoScale = 1.0
                logoOpacity = 1.0
                logoRotationDegrees = 0
            }

            // `DispatchQueue.main.asyncAfter` schedules code to run after a delay, without
            // freezing/blocking anything else on screen in the meantime — the standard way
            // to say "wait, then do this" in Swift. Here it staggers the app name in shortly
            // after the logo starts animating, so the two don't compete for attention at
            // the exact same instant.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                withAnimation(.easeOut(duration: 0.4)) {
                    showAppName = true
                }
            }

            // The credit line fades in last of all, once the name has mostly settled.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.65) {
                withAnimation(.easeOut(duration: 0.4)) {
                    showCredit = true
                }
            }
        }
    }

    // The little four-wedge "pie + clock" logo mark — a live SwiftUI recreation of the
    // app's Dark Radial Clock icon (same MeeplePalette gradients, same silver-ringed
    // center), drawn as real shapes rather than a flat picture so it can be scaled,
    // rotated, and animated smoothly during the splash.
    private var logoMark: some View {
        // Fixed pixel size for the logo, independent of screen size — a splash screen logo
        // should look the same on every device, unlike the pie layout which fills the screen.
        let markSize: CGFloat = 160

        return ZStack {
            // Four quarter-circle wedges in the icon's palette order (blue, red, yellow,
            // green — MeeplePalette gradients 0-3), standing in for "players" in the
            // abstract, logo sense.
            ForEach(0..<4, id: \.self) { index in
                SplashQuarterWedge(quarter: index)
                    .fill(MeeplePalette.gradient(index))
                    .overlay(
                        SplashQuarterWedge(quarter: index)
                            .stroke(MeeplePalette.background, lineWidth: 3)
                    )
            }

            // The dark center circle with the silver ring, standing in for the active-game
            // screen's center clock (and matching the app icon).
            Circle()
                .fill(MeeplePalette.background)
                .frame(width: markSize * 0.44, height: markSize * 0.44)
            Circle()
                .stroke(MeeplePalette.silver, lineWidth: 2.5)
                .frame(width: markSize * 0.37, height: markSize * 0.37)

            // The shorter "hour" hand, pointing straight up from the center.
            RoundedRectangle(cornerRadius: 2)
                .fill(.white)
                .frame(width: 5, height: markSize * 0.14)
                .offset(y: -markSize * 0.07)

            // The longer "minute" hand, pointing sideways from the center — rotated 90
            // degrees from a vertical rectangle rather than drawn as a separate horizontal
            // shape, just to reuse the same RoundedRectangle code.
            RoundedRectangle(cornerRadius: 2)
                .fill(.white)
                .frame(width: 4, height: markSize * 0.11)
                .rotationEffect(.degrees(90))
                .offset(x: markSize * 0.055)

            // The small dot at the very center where both hands pivot from.
            Circle()
                .fill(.white)
                .frame(width: 7, height: 7)
        }
        .frame(width: markSize, height: markSize)
    }
}

// SplashQuarterWedge draws one quarter of the logo's pie: quarter 0 is the top-right slice
// (12 o'clock to 3 o'clock), and each next quarter continues clockwise. Kept private to
// the splash screen — the real game screens have their own wedge math sized to the screen.
private struct SplashQuarterWedge: Shape {
    // Which quarter (0-3), clockwise from 12 o'clock.
    let quarter: Int

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2

        // -90 degrees is 12 o'clock in SwiftUI's angle convention; each quarter spans 90.
        let startDegrees = Double(quarter) * 90 - 90
        path.move(to: center)
        path.addArc(
            center: center,
            radius: radius,
            startAngle: .degrees(startDegrees),
            endAngle: .degrees(startDegrees + 90),
            // `false` gives a visually clockwise sweep in SwiftUI's flipped-Y coordinates.
            clockwise: false
        )
        path.closeSubpath()
        return path
    }
}

#Preview {
    SplashScreenView()
}

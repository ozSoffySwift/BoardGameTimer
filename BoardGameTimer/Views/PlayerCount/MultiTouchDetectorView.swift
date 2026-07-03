import SwiftUI
import UIKit

// FingerTouchPoint remembers ONE finger currently touching the screen: a stable ID so
// SwiftUI can tell fingers apart across updates (for `ForEach`), plus where that finger
// currently is.
struct FingerTouchPoint: Identifiable {
    // `ObjectIdentifier` gives a unique, stable identity for the underlying `UITouch`
    // object for as long as that specific finger stays down — perfect as an `id`, since a
    // real UITouch instance conveniently already exists once per finger, for its whole
    // press-move-lift lifetime.
    let id: ObjectIdentifier

    // Where this finger currently is, measured in points from the top-left of the detector
    // view (which we size to fill the whole screen — see FirstPlayerPickerView).
    var location: CGPoint
}

// MultiTouchDetectorView bridges a plain UIKit `UIView` into SwiftUI so we can detect
// SEVERAL fingers touching the screen AT THE SAME TIME. Plain SwiftUI gestures
// (`.onTapGesture`, `DragGesture`, etc.) are built around tracking ONE touch per gesture at
// a time — there's no built-in SwiftUI way to say "tell me about every single finger
// currently down, however many there are." UIKit's `UIView`, on the other hand, has always
// supported this via its `touchesBegan`/`touchesMoved`/`touchesEnded` methods, so we write a
// small UIKit view that does the real touch-tracking, then wrap it for use inside SwiftUI.
struct MultiTouchDetectorView: UIViewRepresentable {
    // Called every time the set of active fingers changes (one is added, moved, or lifted),
    // with the full up-to-date list of everyone currently touching the screen.
    let onTouchesChanged: ([FingerTouchPoint]) -> Void

    // `UIViewRepresentable` requires this method: it builds the actual UIKit view ONCE, the
    // first time this SwiftUI view appears.
    func makeUIView(context: Context) -> TouchTrackingView {
        let view = TouchTrackingView()
        view.onTouchesChanged = onTouchesChanged
        view.backgroundColor = .clear
        return view
    }

    // `UIViewRepresentable` also requires this method, called whenever SwiftUI re-renders
    // this view — we don't have any settings that can change after creation, so there's
    // nothing to update here.
    func updateUIView(_ uiView: TouchTrackingView, context: Context) {}

    // TouchTrackingView is the actual UIKit view doing the real work. It's a genuine
    // `UIView` subclass (not SwiftUI) so it can override UIKit's raw touch-handling methods.
    final class TouchTrackingView: UIView {
        // The closure `MultiTouchDetectorView` hands us, called every time we have fresh
        // touch data to report.
        var onTouchesChanged: (([FingerTouchPoint]) -> Void)?

        // Every finger currently down, keyed by its stable `ObjectIdentifier`. A dictionary
        // (rather than a plain array) makes it easy to update or remove ONE specific
        // finger's entry when UIKit tells us it moved or lifted, without having to search
        // through the whole list.
        private var touchesByID: [ObjectIdentifier: UITouch] = [:]

        override init(frame: CGRect) {
            super.init(frame: frame)
            // This is the one line that actually turns on multi-finger tracking — without
            // it, UIKit only reports the FIRST finger that touches this view and silently
            // ignores any others, exactly like a single SwiftUI gesture would.
            isMultipleTouchEnabled = true
        }

        // Every UIView subclass needs this initializer for Interface-Builder/storyboard
        // loading; we don't use storyboards here, so it's fine to just crash if it's ever
        // called — it never will be in this SwiftUI-only app.
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        // Called by UIKit the instant one or more NEW fingers touch down on this view.
        override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
            for touch in touches {
                touchesByID[ObjectIdentifier(touch)] = touch
            }
            reportCurrentTouches()
        }

        // Called continuously as any already-down finger slides around.
        override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
            for touch in touches {
                touchesByID[ObjectIdentifier(touch)] = touch
            }
            reportCurrentTouches()
        }

        // Called when a finger lifts back up off the screen.
        override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
            for touch in touches {
                touchesByID.removeValue(forKey: ObjectIdentifier(touch))
            }
            reportCurrentTouches()
        }

        // Called if iOS itself interrupts a touch (e.g. an incoming phone call alert pops
        // up mid-gesture) — treated the same as the finger lifting, so it isn't left
        // "stuck" in our tracked list forever.
        override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
            for touch in touches {
                touchesByID.removeValue(forKey: ObjectIdentifier(touch))
            }
            reportCurrentTouches()
        }

        // Converts our internal `[ObjectIdentifier: UITouch]` dictionary into the plain
        // `[FingerTouchPoint]` array format the rest of the app (plain SwiftUI, no UIKit
        // types) understands, then hands it to whoever's listening.
        private func reportCurrentTouches() {
            let points = touchesByID.map { id, touch in
                FingerTouchPoint(id: id, location: touch.location(in: self))
            }
            onTouchesChanged?(points)
        }
    }
}

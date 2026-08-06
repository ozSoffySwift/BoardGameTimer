import SwiftUI
import StoreKit // Needed for the native "request an App Store review" action below.

// AboutView is a simple, mostly-static screen: what this app is, who made it, and a couple
// of links out to the developer's other profiles — the standard "About" screen found in
// most polished apps' Settings area.
struct AboutView: View {
    // SwiftUI's built-in action for asking iOS to show its native "Enjoying this app? Tap a
    // star to rate it" popup. This is Apple's own recommended way to collect App Store
    // ratings — notably, it does NOT need the app to be published yet, or need us to know
    // its App Store ID, unlike a direct link to an App Store listing page (which can't
    // exist until the app actually ships). iOS also silently limits how often this popup is
    // allowed to appear to any one user (a few times a year), regardless of how often the
    // app calls it — that throttling is handled entirely by the system, not by this code.
    @Environment(\.requestReview) private var requestReview

    var body: some View {
        Form {
            Section {
                VStack(spacing: 12) {
                    Image("AppIconPreview")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 88, height: 88)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .shadow(radius: 4)

                    Text("Meeple Clock")
                        .font(.system(.title2, design: .rounded).weight(.bold))

                    Text("A chess-clock style board game timer for up to 6 players. Set the phone flat in the middle of the table: every player gets their own gradient wedge of a full-screen radial layout, and tapping your wedge passes the turn to the next player.")
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                // No visible section header/background for this one — it reads more like a
                // title card than a settings group.
                .listRowBackground(Color.clear)
            }

            Section {
                LabeledContent("Developer") {
                    Text("Oz Soffy")
                }

                Link(destination: URL(string: "https://www.linkedin.com/in/ozsoffy/")!) {
                    Label("LinkedIn", systemImage: "person.crop.rectangle")
                }

                Link(destination: URL(string: "https://github.com/ozSoffySwift/MeepleClock")!) {
                    Label("GitHub Repository", systemImage: "chevron.left.forwardslash.chevron.right")
                }
            } header: {
                Text("Developer")
            }

            Section {
                Button {
                    requestReview()
                } label: {
                    Label("Rate This App", systemImage: "star.fill")
                }
            } footer: {
                Text("Shows Apple's built-in rating prompt. iOS limits how often this can appear, so it may not show up every time.")
            }
        }
        .navigationTitle("About")
        .trackScreen(.about)
    }
}

#Preview {
    NavigationStack {
        AboutView()
    }
}

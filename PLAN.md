# Board Game Timer — iOS App Implementation Plan

Greenfield SwiftUI app. Built on Windows (project files only), compiled/run on a Mac.
No code yet — this is the buildable, milestone-based plan.

---

## 1. Xcode Project Setup

- **Product Name:** `BoardGameTimer` (working name; renaming an Xcode project later is
  doable but annoying, so lock this in now if possible).
- **Bundle Identifier placeholder:** `com.ozsoffy.boardgametimer` (reverse-DNS; swap the
  prefix for your real Apple Developer team identifier later — doesn't matter for
  simulator-only work, only matters once real device signing is set up).
- **Interface:** SwiftUI (not Storyboard).
- **Life Cycle:** SwiftUI App life cycle (`@main struct BoardGameTimerApp: App`), not the
  old UIKit AppDelegate life cycle. This is the default when "SwiftUI" interface is chosen.
- **Language:** Swift.
- **Minimum Deployment Target: iOS 17.0.**
  - Why 17: SwiftData requires iOS 17+. iOS 17 also has the `@Observable` macro
    (replacement for `ObservableObject`/`@Published`, less boilerplate), the
    `.sensoryFeedback()` SwiftUI modifier for haptics (no manual UIKit generator needed),
    and improved `TimelineView`.
  - **Trade-off to flag explicitly:** iOS 17+ excludes iPhone 8/8 Plus/X and earlier
    (devices that cannot update past iOS 16). For a hobby/small-group app this is a
    reasonable, common trade-off — iOS adoption stats show 17+ covers the large majority
    of active devices within about a year of release. If older devices ever need support,
    the fallback is Core Data + `ObservableObject` + manual
    `UINotificationFeedbackGenerator`, which is more boilerplate and NOT recommended as
    the beginner starting point.
- **Testing:** leave "Include Tests" checked (default) — not the focus now, but free to
  have scaffolded for later.
- No Core Data / CloudKit checkboxes at project creation — persistence is added
  deliberately in Milestone 5 using SwiftData directly.

### Folder / Group Structure

Create these as real filesystem folders (blue folders, via File > New > Group Without
Folder unchecked) so the structure is visible in Finder too, since the user works across
Windows/Mac.

```
BoardGameTimer/
  BoardGameTimerApp.swift          <- @main entry point
  Models/
    Player.swift                   <- SwiftData @Model
    GameSession.swift              <- SwiftData @Model
    PhaseRecord.swift              <- SwiftData @Model (setup/explanation/cleanup durations)
    TurnRecord.swift               <- SwiftData @Model (one row per player-turn taken)
    GamePhase.swift                <- plain enum, not persisted directly
  ViewModels/
    GameSessionViewModel.swift     <- @Observable, drives the live game screen
    PlayerSetupViewModel.swift     <- @Observable, drives player-count/name/icon screen
  Views/
    PlayerCount/
      PlayerCountView.swift
    PlayerSetup/
      PlayerSetupView.swift
      PlayerEditRow.swift
    LiveGame/
      LiveGameView.swift           <- top-level container, phase controls
      PieLayoutView.swift          <- radial wedge container (GeometryReader)
      WedgeShape.swift             <- Shape struct, draws one pie slice
      PlayerWedgeView.swift        <- content inside a wedge (name/icon/time), rotated
      CenterHubView.swift          <- circular center timer display
      PhaseBannerView.swift        <- Setup/Explanation/Cleanup single-timer bar
    Summary/
      SummaryView.swift
      SummaryRow.swift
    History/
      PastGamesListView.swift
      PastGameDetailView.swift
    Components/
      IconPickerView.swift
      ColorSwatchPickerView.swift
      TimeFormatting.swift         <- helper: TimeInterval -> "MM:SS" string
  Persistence/
    PersistenceController.swift   <- SwiftData ModelContainer setup
  Resources/
    Assets.xcassets               <- AccentColor + extra color sets
  Utilities/
    Extensions.swift              <- small Date/TimeInterval helpers
```

Rationale: separates **data** (Models/Persistence) from **flow logic** (ViewModels) from
**presentation** (Views), and groups Views by screen — the easiest mental model for a
beginner ("I'm working on the Live Game screen" -> one folder). `Components/` holds only
things reused across 2+ screens, so it stays small.

---

## 2. Data Model (SwiftData)

SwiftData models are plain Swift classes annotated `@Model`. Field sketch below (not full
code) — flagged for the eventual coding step that every property needs an inline `//`
comment for a total beginner.

### `Player`
- `id: UUID` — stable identity, also satisfies `Identifiable` used constantly by
  SwiftUI's `ForEach`.
- `name: String`
- `colorName: String` — a name/key like `"tealAccent"` mapping to a Color asset, since
  SwiftData cannot natively persist a `Color` value.
- `sfSymbolName: String` — e.g. `"crown.fill"`, `"leaf.fill"` (see SF Symbols list below).
- `seatIndex: Int` — 0-based position around the table/pie, determines wedge angle.
- relationship: `session: GameSession?` — inverse relationship back to its session;
  SwiftData wires the inverse automatically once declared on both sides.

### `GameSession`
- `id: UUID`
- `date: Date` — when played; used to sort the Past Games list.
- `gameTitle: String?` — optional free-text (e.g. "Catan"); can be left blank in v1.
- `playerCount: Int`
- `totalDuration: TimeInterval` — computed once at game end and stored, rather than
  recomputed from children every display.
- relationship: `players: [Player]` (one-to-many)
- relationship: `phaseRecords: [PhaseRecord]` (one-to-many; expect exactly 3: setup,
  explanation, cleanup)
- relationship: `turnRecords: [TurnRecord]` (one-to-many; one row per turn taken during
  Playing phase)

### `PhaseRecord`
(covers Setup / Explanation / Cleanup — one of each per game)
- `id: UUID`
- `phaseName: String` — store as a String (e.g. `"setup"`) rather than the enum directly
  (see note below).
- `duration: TimeInterval`
- relationship back to `session: GameSession?`

### `TurnRecord`
(one row every time a player's clock ran for a stretch during Playing phase — lets
Summary compute both total time AND turn count per player with no extra bookkeeping)
- `id: UUID`
- `player: Player?` — a direct relationship (cleaner in SwiftData than storing a raw
  `UUID` and looking it up manually).
- `startedAt: Date`
- `duration: TimeInterval`
- relationship back to `session: GameSession?`

### Why `GamePhase` is a plain enum, not a `@Model`
`GamePhase` (`.setup, .explanation, .playing, .cleanup, .summary`) describes **runtime
state** of the live game screen, not something needing its own persisted row — it's
transient. Persisted history only needs the *durations* (`PhaseRecord.phaseName` +
`duration`), not "what phase is active right now." Keep the live-flow enum in
`Models/GamePhase.swift` as a plain `enum GamePhase: String, CaseIterable` so it is easy
to `switch` over in views — it is just a Swift type, not a database table.

### Persistence notes
- One `ModelContainer` for the whole app, created once in `BoardGameTimerApp.swift` and
  injected via `.modelContainer(...)` on the root view — this makes `@Query` and
  `@Environment(\.modelContext)` available anywhere down the view tree. This is the
  standard, minimal-boilerplate SwiftData setup and beginner-friendly because there is no
  separate "Core Data stack" object graph to understand.
- `PastGamesListView` uses `@Query(sort: \GameSession.date, order: .reverse)` for a live,
  auto-updating list — no manual fetch-and-refresh code needed.
- Even though SwiftData relationships mostly auto-save, it is still good beginner
  practice to call `try? modelContext.save()` explicitly right after building the final
  `GameSession` object at game end, to guarantee the write happens before navigating away.

### Core Data fallback (only if targeting < iOS 17 later)
The same four entities (`Player`, `GameSession`, `PhaseRecord`, `TurnRecord`) map directly
onto a Core Data `.xcdatamodeld` with the same fields/relationships. The view-model layer
(`GameSessionViewModel`) would change less than expected because persistence is
deliberately treated as "hand a finished `GameSession`-shaped bundle of data to a save
function" rather than manipulating the database directly from timer logic — see Section 3.

---

## 3. State Machine / GameSessionViewModel Design

### `GamePhase` enum
```
enum GamePhase: String, CaseIterable {
    case setup, explanation, playing, cleanup, summary
}
```
Linear progression, one direction, no skipping backward in v1 — "Next Phase" advances one
step; no back button needed for a beginner build (could be added later if playtesting
shows mis-taps).

### Timer approach: `TimelineView`, not manual `Timer` + Combine
Recommend SwiftUI's `TimelineView(.periodic(from:by:))` over classic
`Timer.publish(...).autoconnect()` Combine pipelines, because:
- No manual `Timer.TimerPublisher` plumbing, no `.onReceive` wiring, no cancellation bugs
  (a classic beginner Combine pitfall is forgetting to invalidate a `Timer` and leaking it).
- `TimelineView` re-renders its content closure on schedule automatically and is Apple's
  own recommended modern pattern for "redraw a view every fraction of a second" — the
  literal stopwatch/timer use case.
- The elapsed-time math should NOT live inside the timer tick itself. Store
  `phaseStartDate: Date?` and `accumulatedBeforePause: TimeInterval` on the view model,
  and compute `elapsed = accumulatedBeforePause + Date().timeIntervalSince(phaseStartDate)`
  fresh every time the `TimelineView` closure fires. This avoids drift from repeatedly
  adding "+1 second" per tick — a common bug in naive timer implementations.

### `GameSessionViewModel`
Mark it `@Observable` (iOS 17 macro, replaces `ObservableObject` + `@Published` with less
boilerplate). Referenced in views via `@State private var viewModel = GameSessionViewModel(...)`,
or passed down and read via `@Bindable` where two-way binding is needed (e.g. text fields).

Stored state:
- `players: [PlayerRuntimeState]` — a lightweight in-memory struct per player (NOT the
  SwiftData `Player` directly during live play, to avoid touching the database on every
  turn tap; only persisted at game end). Fields: `id`, `name`, `colorName`,
  `sfSymbolName`, `seatIndex`, `accumulatedPlayTime: TimeInterval`, `turnCount: Int`,
  `isActiveTurn: Bool`.
- `currentPhase: GamePhase`
- `activePlayerIndex: Int?` — meaningful only during `.playing`.
- `phaseStartDate: Date?`, `phaseAccumulated: TimeInterval` — for the single shared timer
  during setup/explanation/cleanup.
- `perPhaseDurations: [GamePhase: TimeInterval]` — filled in as each of
  setup/explanation/cleanup completes, read back at Summary/save time.
- `sessionStartDate: Date` — set once at the very start, used for total game duration.

Key methods (behavior, not code):
- `advancePhase()` — freezes the current phase's elapsed time into
  `perPhaseDurations[currentPhase]`, moves `currentPhase` to the next case; if the new
  phase is `.playing`, sets `activePlayerIndex = 0` and starts that player's clock; if the
  new phase is `.summary`, triggers "build final GameSession and save."
- `toggleSharedTimer()` — pause/resume for Setup/Explanation/Cleanup (single shared
  clock, start/stop only, no per-player concept).
- `selectPlayer(at index:)` — the core chess-clock action for Playing phase. Stops the
  currently active player's clock (folds elapsed time into their `accumulatedPlayTime`),
  starts the tapped player's clock, increments **their** `turnCount` by 1, and sets
  `activePlayerIndex = index`. Works identically whether the tapped player is "next in
  rotation" or any arbitrary player — this single method serves BOTH the "pass to next"
  gesture and "tap any wedge directly" gesture; "pass to next" is UI sugar that calls
  `selectPlayer(at: (activePlayerIndex + 1) % players.count)`.
- `passToNextPlayer()` — the convenience wrapper described above, invoked by a dedicated
  "Pass Turn" button/gesture so the user is not forced to precisely tap the next wedge
  when following strict rotation order.
- `endGameEarly()` — allowed from any phase; freezes whatever timer is currently running
  into its bucket, jumps straight to `.summary`. Important for real-world use — games get
  abandoned/interrupted and the user needs an escape hatch, not just the happy path.
- `buildGameSessionForPersistence() -> (GameSession, [Player], [PhaseRecord], [TurnRecord])`
  — a pure function that takes the in-memory runtime state and produces the SwiftData
  model objects to insert. Keeping this as a separate, isolated step (rather than writing
  to `modelContext` throughout the game) preserves the option to swap in Core Data later,
  and means nothing touches the database until the game actually finishes — better
  performance, no partial/corrupt-looking rows if the app is killed mid-game.

### Turn-passing UX — patterns borrowed from chess clocks / turn-timer apps
- **Chess clocks** (2-player) use "tap your own side to end your turn / start opponent's"
  — the direct analog of "tap the wedge whose turn is starting," extended from 2 to N.
- Multi-player turn-timer / party-game clock apps commonly add a **big, unmissable
  "pass" affordance** (large button or edge-swipe) because tapping a precise small target
  under time pressure is error-prone — this justifies keeping BOTH: (a) tap any wedge
  directly (flexible, handles out-of-turn-order board games) and (b) one obvious "Pass
  Turn" control near the center hub (fast, low-precision, matches strict rotation).
- Such apps almost always give strong, immediate feedback on turn change — highlighting
  the newly active side plus a haptic buzz — because players glance at the device quickly
  and need to instantly confirm whose turn it is now. This directly motivates the
  "highlight active wedge + haptic on pass" polish item in M4/M6.
- A common pitfall is ambiguity about **whose clock is running right now** when the phone
  is glanced at mid-game after being ignored for a while — mitigate with a persistent,
  obvious visual state (glow/border/scale-up on the active wedge, not just center-hub
  text) rather than relying on the center timer number alone.

---

## 4. Radial Pie-Wedge Layout — Concrete SwiftUI Approach

This is the signature visual and the trickiest part for a beginner, so it gets its own
milestone (M3) and the most detail here.

### Core math
Given `N` = number of players:
- `anglePerWedge = 360.0 / Double(N)` degrees (convert to radians for trig functions:
  `radians = degrees * .pi / 180`, since Foundation/CoreGraphics `cos`/`sin` expect
  radians).
- Player at `seatIndex` (0-based) occupies the angular range from
  `seatIndex * anglePerWedge` to `(seatIndex + 1) * anglePerWedge`, measured from a chosen
  zero-reference (e.g. straight up = 12 o'clock, with a fixed offset from standard math
  convention where 0° = 3 o'clock/east and angles increase clockwise). Decide this
  convention once and keep it consistent everywhere — inconsistency here is the #1 source
  of "why is my wedge in the wrong place" bugs for beginners.
- The **center angle** of a wedge (used to rotate its content upright) is
  `seatIndex * anglePerWedge + anglePerWedge / 2`.

### `WedgeShape: Shape`
A custom `Shape` struct storing `startAngle`/`endAngle` (or `seatIndex` + `totalPlayers`),
implementing `func path(in rect: CGRect) -> Path` by:
1. Finding the center point of `rect`.
2. Finding the radius (typically `min(rect.width, rect.height) / 2`, minus a small margin
   so wedges don't touch the very screen edge).
3. Building a `Path` that moves to center, draws a line to the circle edge at
   `startAngle`, adds an arc from `startAngle` to `endAngle` around the center, then
   closes back to center — exactly `Path.addArc(center:radius:startAngle:endAngle:
   clockwise:)` plus `move(to:)`/`closeSubpath()`. This is the same technique used in
   classic SwiftUI pie-chart tutorials, applied here per-player instead of per-data-value.
- Fill each `WedgeShape` with the player's `Color` (from `colorName`), and add a thin
  `.stroke()` in a system background color between wedges so they read as visually
  separate "table seats," not one blob.

### Container: `PieLayoutView`
- Wrapped in a `GeometryReader` to get available `size` (the screen area given to the
  pie) — the standard SwiftUI way to get pixel dimensions for math-driven custom layouts.
- A `ZStack` containing:
  1. One `WedgeShape` per player, laid out via `ForEach(players)`, each pre-shaped to its
     own angular slice (the wedges themselves do NOT need `.rotationEffect` — the shape's
     path already encodes the right slice, avoiding compounding rotation bugs).
  2. On top of each wedge, a `PlayerWedgeView` (name/icon/time content) placed via
     `.position(...)` at a point computed from the wedge's center angle at roughly 60-75%
     of the way from center to edge (content sits mid-wedge, not crammed at the rim or
     overlapping the center hub), then rotated upright via
     `.rotationEffect(.degrees(centerAngleForSeat + fixedOffset))` (the offset accounts
     for whichever zero-reference convention was chosen). Key beginner takeaway: **the
     position is computed with trig using the wedge's center angle, and the content is
     then separately rotated by roughly that same angle** so text/icons read right-side-up
     from that seat's point of view around the table, like a lazy Susan.
  3. `CenterHubView` layered last (drawn on top, in the middle) — a plain circular view
     showing the current shared/active-player timer text, sized independently of the
     wedges (fixed diameter or a fraction of the smaller screen dimension), with
     `.background(Circle().fill(Color(.systemBackground)))` so it visually punches
     through where wedges meet at the center, plus a border/shadow for the "elegant"
     polish goal.

### Known pitfalls to flag ahead of coding
- **Hit-testing rotated views:** rotating a view with `.rotationEffect` rotates its visual
  content, but tap targets can behave unexpectedly if rotation is applied at the wrong
  layer. Safe pattern: put `.onTapGesture` (or wrap in a `Button`) on the **wedge shape
  itself** (not rotated — its geometry already encodes its slice), not on the rotated
  text/icon overlay. The tappable area is then the full, correctly-shaped pie slice, and
  the rotated `PlayerWedgeView` is purely decorative content positioned on top.
- **Text/icon "upside down" readability:** for players on the far side of the pie
  (roughly the bottom half if the phone is flat on the table), their rotation angle will
  be upside-down relative to the phone's fixed top edge — and that IS the desired
  behavior for a lazy-Susan layout (it looks upside down to someone at the "top" seat but
  right-side-up to the person actually sitting there). Beginners may initially think this
  is a bug and try to "fix" it by clamping rotation to never exceed 90°, which would
  defeat the entire point of the feature. Flag this explicitly in a code comment when
  implemented so it isn't "fixed" away.
- **Safe area / notch avoidance:** since the layout is meant to use the whole screen,
  deliberately wrap `LiveGameView`'s content in `.ignoresSafeArea()` (a conscious choice),
  but keep `CenterHubView` and any phase control buttons comfortably inset by a manual
  margin so they are never obscured by a Dynamic Island/notch/home indicator — i.e. don't
  `ignoresSafeArea()` blindly; explicitly pad the content that must remain
  tappable/readable, even though the background wedge shapes extend edge-to-edge.
- **GeometryReader sizing pitfalls:** `GeometryReader` greedily takes all offered space,
  which is fine here since the pie is meant to be full-screen, but nesting it inside
  other layout containers later (e.g. a settings sheet) can produce surprising sizing —
  keep `PieLayoutView`'s `GeometryReader` as close to the top of this screen's view
  hierarchy as possible to avoid nested-GeometryReader confusion, a common beginner
  stumbling block.
- **Very small wedges at N=7 or 8:** at 8 players each wedge is only 45°, leaving less
  room for name + icon + time text without truncation. Plan for `PlayerWedgeView` to
  degrade gracefully at high player counts — icon always shown, name truncates with
  `.lineLimit(1)` + `.minimumScaleFactor(0.6)`, exact time always shown in compact
  "MM:SS" format. Test this visually at N=8 specifically, not just N=2-4 (see M3).

### SF Symbols recommendations for player icons (no custom art needed)
Board-game/game-piece-flavored, all standard SF Symbols, no custom assets required:
`crown.fill`, `shield.fill`, `flame.fill`, `bolt.fill`, `leaf.fill`, `star.fill`,
`drop.fill`, `moon.stars.fill`, `paperplane.fill`, `pawprint.fill`,
`circle.hexagongrid.fill`, `diamond.fill`, `hexagon.fill`, `suit.spade.fill`,
`suit.club.fill`. Offer these as a fixed picker grid in `PlayerSetupView` (via the
`IconPickerView` component) rather than free-text symbol entry — much friendlier for a
beginner and for end users alike.

---

## 5. Screen-by-Screen Flow & Navigation

- **Root:** `NavigationStack`, with `PlayerCountView` as the actual root of one tab (see
  `TabView` note below), rather than the old `NavigationView`.
- **PlayerCountView** (stepper/segmented picker 1-8) → pushes **PlayerSetupView** via
  `NavigationStack` push (`.navigationDestination`), since this is a forward, back-able
  step in a linear setup flow.
- **PlayerSetupView** (per-player name text field + `IconPickerView` +
  `ColorSwatchPickerView`, one `PlayerEditRow` per player) → on "Start Game," presents
  **LiveGameView** as a **`.fullScreenCover`**, not a normal push. Reasoning: once the
  game starts, an accidental swipe-back gesture or nav-bar back button should not be able
  to interrupt a running timer — a full-screen cover with an explicit "End Game Early"
  affordance inside `LiveGameView` is safer, and visually signals "you're now in a
  different mode" (matches how camera/recording-style full-immersion screens are
  typically presented per HIG).
- **LiveGameView** internally swaps its body based on `viewModel.currentPhase`:
  - `.setup`, `.explanation`, `.cleanup` → shows `PhaseBannerView` (big single shared
    timer, start/pause button, "Next Phase" button) using a simple centered layout —
    the full pie visual is reserved specifically for `.playing`, where the multi-player
    concept actually matters. (Optional M6 polish: fade/morph toward the pie earlier for
    visual consistency — not required for v1.)
  - `.playing` → shows `PieLayoutView` + `CenterHubView` overlay + a "Pass Turn" control +
    "End Game Early" control (a small toolbar-style button, not a giant tappable area, to
    avoid accidental early termination).
  - `.summary` → the same full-screen-cover context switches its content to
    **SummaryView** (simplest to keep the same cover and switch content again rather than
    trigger a second presentation transition).
- **SummaryView**: shows total duration, each of setup/explanation/cleanup duration, and a
  sorted per-player total time + turn count visualization — horizontal bars sized
  proportionally, colored per player's chosen color, using a simple `Chart` from the
  **Swift Charts** framework (native since iOS 16, appropriate for this "simple bar
  comparison," no third-party dependency needed). Has a "Done" button dismissing the
  `fullScreenCover` back to `PlayerCountView`; this is also the point where
  `buildGameSessionForPersistence()` + `modelContext.insert(...)` + `modelContext.save()`
  actually runs, right as Summary appears, so the finished game is immediately visible if
  the user then checks Past Games.
- **PastGamesListView**: reachable via a second `TabView` tab. Uses `@Query` sorted by
  date descending; each row summarizes date + player count + total duration. Tapping a
  row pushes (regular `NavigationStack` push — a standard back button is fine here since
  nothing is "live") **PastGameDetailView**, which redisplays the same kind of summary
  breakdown as `SummaryView` but reading from persisted data instead of the live view
  model. This is a strong argument for factoring the "per-player time breakdown
  visualization" into a shared reusable component (e.g. a shared results view used by
  both `SummaryView` and `PastGameDetailView`) rather than duplicating that UI.

### Navigation summary
```
TabView
 |-- Tab 1: NavigationStack
 |     PlayerCountView -> (push) PlayerSetupView
 |       PlayerSetupView -> (fullScreenCover) LiveGameView
 |         LiveGameView internally cycles phases, ends at Summary content
 |         "Done" dismisses cover back to PlayerCountView
 `-- Tab 2: NavigationStack
       PastGamesListView -> (push) PastGameDetailView
```

A 2-tab `TabView` ("New Game" / "Past Games") is recommended over a single-stack-with-
toolbar-button approach, since "start a new game" and "browse history" are genuinely
parallel activities, not hierarchically nested ones.

---

## 6. Design Language / HIG Application (concrete choices)

- **Typography:** exclusively `Font.system(.largeTitle/.title/.headline/.body/.caption,
  design: .rounded)` (rounded design leans "friendly/game-like" while staying fully
  system-native, no custom font files) using Dynamic Type text styles, never fixed point
  sizes, so accessibility text-size settings are respected automatically.
- **Color:**
  - Define a custom **AccentColor** in `Assets.xcassets` (light + dark variants) as the
    app's primary brand color.
  - Define a small curated named color set for player assignment (e.g. 8 named colors:
    Coral, Teal, Amber, Violet, Mint, Sky, Rose, Lime), each its own Color Set in
    `Assets.xcassets` with explicit light/dark variants so they stay vibrant and legible
    in both modes — this is the concrete mechanism behind `Player.colorName` from Section 2.
  - Everywhere else (backgrounds, dividers, secondary text) use semantic system colors —
    `Color(.systemBackground)`, `.primary`, `.secondary`, `Color(.separator)` — so light/
    dark mode and increased-contrast accessibility settings are respected for free.
- **Icon-forward, minimal text:** every screen leads with an SF Symbol before/above any
  text label (player wedges, phase banner icons e.g. `wrench.and.screwdriver` for setup,
  `text.bubble` for explanation, `trash` for cleanup, `flag.checkered` for summary).
- **Large tap targets:** each pie wedge is a naturally large tappable region (100+ points
  across even at N=8 on a modern iPhone); "Pass Turn" and phase-advance buttons should
  comfortably meet the ~44x44pt HIG minimum, ideally larger given this app is tapped
  quickly mid-game, possibly without looking closely at the screen.
- **Animated timer transitions:** wrap phase changes and active-wedge changes in
  `withAnimation(.easeInOut)` so the active wedge's highlight/scale change and the center
  hub's phase-icon swap feel smooth rather than an abrupt cut.
- **Haptics:** use SwiftUI's `.sensoryFeedback(.selection, trigger: activePlayerIndex)`
  (and e.g. `.success` triggered on `currentPhase` reaching `.summary`) — the modern iOS
  17 SwiftUI-native replacement for manually instantiating
  `UINotificationFeedbackGenerator`, so no UIKit bridging code is needed. Trigger a light
  haptic on every turn pass, and a slightly stronger one on phase advance, so the physical
  sensation reinforces "something changed" for people not staring at the screen.

---

## 7. Beginner Code-Comment Requirement (carried forward, not implemented now)

Flag for the future coding milestones: every property, function, and non-trivial line in
every Swift file must have an inline `//` comment written for a total beginner (what the
variable holds, why the function exists, what a parameter means) — applies from
Milestone 1 onward, including "throwaway" hardcoded milestone-1 code, since that code gets
built on rather than replaced. Re-state this constraint at the start of each future coding
session/milestone, not just once.

---

## 8. Build Order — Milestones

Each milestone should be independently runnable/viewable in Xcode (on the Mac) before
moving to the next, so there is always something working to look at.

### M1 — Static Project Skeleton + Player Count + Hardcoded Pie
- Create the Xcode project with the settings/folder structure from Section 1.
- Build `PlayerCountView` with a working stepper (1-8), no persistence, no view model yet
  — just local `@State var playerCount: Int`.
- Build `WedgeShape` + a **hardcoded** `PieLayoutView` fed a fixed fake array of e.g. 4
  players (fixed names/colors/icons in code, no data model yet) to prove out the
  angle-math and rotation approach in isolation, with a static (non-running) fake time
  string per wedge.
- Goal: see the radial layout rendering correctly, rotated per-seat, before any timer
  logic or persistence complexity is introduced. This isolates the highest-risk, most
  novel visual work (Section 4) as early as possible.

### M2 — Real GameSessionViewModel + Working Phase Timers (Simple List Layout First)
- Introduce the `GamePhase` enum and `GameSessionViewModel` (`@Observable`).
- Implement Setup/Explanation/Cleanup shared-timer logic (`TimelineView`-driven,
  start/pause, "Next Phase" button) using a **plain vertical list/VStack layout**, not the
  pie yet — deliberately deferring visual complexity so the timer/phase state machine can
  be gotten correct and testable on its own first.
- For the Playing phase at this stage, also use a simple list of players with a
  highlighted "active" row and a basic "tap row to make active" / "pass" button, instead
  of the pie — proves out `selectPlayer`/`passToNextPlayer`/turn-counting logic without
  compounding it with rotation math.
- Goal: correct, drift-free timers and correct chess-clock turn logic, fully working,
  just visually plain.

### M3 — Implement the Radial Pie Wedge Visual (Real Data)
- Swap the Playing-phase list layout from M2 for the real `PieLayoutView` built in M1,
  now wired to the live `GameSessionViewModel.players` (real names/colors/icons from
  Player Setup, real running times).
- Add `CenterHubView` showing the currently active player's running time and name/icon,
  layered on top.
- Specifically test at N=2, N=5, and N=8 to catch the "small wedge / text truncation at
  high N" pitfall called out in Section 4 early.

### M4 — Chess-Clock Turn Logic Layered onto the Pie
- Wire actual tap gestures on each wedge (the wedge shape itself, not the rotated content
  — per the hit-testing pitfall note) to `selectPlayer(at:)`.
- Add the "Pass Turn" button/gesture calling `passToNextPlayer()`.
- Add visual "active wedge" highlighting (scale/glow/border change) with `withAnimation`.
- Add "End Game Early" control, wired to `endGameEarly()`, available from any phase.
- Goal: the full live-game interaction loop (setup through playing, with real turn
  passing) is feature-complete end-to-end, still without persistence — a full mock game
  should be playable, reaching a (not-yet-saved) Summary screen.

### M5 — SwiftData Persistence + History Screens
- Add the four `@Model` classes (`Player`, `GameSession`, `PhaseRecord`, `TurnRecord`).
- Set up `ModelContainer` in `BoardGameTimerApp.swift`, inject via `.modelContainer(...)`.
- Implement `buildGameSessionForPersistence()` in the view model and call it (plus
  `modelContext.insert` + `save`) when Summary appears.
- Build real `SummaryView` (reading from the just-finished in-memory session, with the
  Swift Charts bar breakdown) and `PastGamesListView`/`PastGameDetailView` (reading from
  `@Query` against saved `GameSession`s).
- Wire up the `TabView` (New Game / Past Games) as the app's root.
- Goal: a full game can be played and it reliably shows up, correctly, in Past Games
  afterward.

### M6 — Visual / Color / Polish Pass
- Add the custom AccentColor + per-player Color Sets to `Assets.xcassets` (light + dark
  variants), replace any placeholder `Color` usage with these.
- Add `.sensoryFeedback` haptics on turn-pass and phase-advance.
- Refine animations (phase transitions, active-wedge highlight, Summary appearance).
- Pass over every screen at larger Dynamic Type accessibility sizes, and in dark mode, to
  confirm nothing clips or goes illegible.
- Confirm safe-area handling around the notch/Dynamic Island/home indicator specifically
  on the Live Game screen, per the pitfall in Section 4.
- Re-check SF Symbol choices for visual consistency/weight (consistent `.fill` variants,
  consistent `.symbolRenderingMode` if using multicolor symbols).

---

## Feature Additions (post-M2, ahead of formal M5/M6)

Four features added directly on top of Milestones 1-2, based on competitor research
(see repo discussion) and user request — mocked up first, approved, then built:

### Game setup: name + BoardGameGeek search
`PlayerCountView` now also has a "Game" text field. Typing debounces (400ms) into a call
to `BoardGameGeekService.searchWithThumbnails(query:)`, which hits BGG's public XML API2
(`xmlapi2/search` then a batched `xmlapi2/thing?id=...` for thumbnails/player counts),
parsed with `XMLParser` (no third-party dependencies). Picking a result shows its real
cover art via `AsyncImage`. Naming the game is optional — BGG failures/no-matches fall
back silently to a free-text name, never blocking Continue.

**Known blocker:** as of late 2025, BGG requires all XML API requests to come from a
registered, authenticated application (`Authorization: Bearer <token>`) — anonymous
requests get `401 Unauthorized`. `BoardGameGeekService.apiToken` is the single insertion
point for a token once one is obtained (apply at
[boardgamegeek.com/using_the_xml_api](https://boardgamegeek.com/using_the_xml_api),
~1 week approval). Never commit a real token — this repo is public.

### First-player picker (multitouch finger-picker)
`FirstPlayerPickerView`, shown after game setup and before the real timer starts:
everyone rests one finger on the screen; once 2+ fingers are down and held still for
1.2s, an animated "wave" hops between them and lands on one at random. Real simultaneous
multi-finger detection needed a small UIKit bridge (`MultiTouchDetectorView`, a
`UIViewRepresentable` wrapping a `UIView` with `isMultipleTouchEnabled = true`) since
plain SwiftUI gestures only track one touch at a time. The winning finger's ANGLE from
the screen's center (using the exact same "-90 degrees, clockwise" convention as
`WedgeShape`) determines which pie seat goes first — players don't need to know their
seat number, they just touch near where they're sitting.

### Real radial pie gameplay (M3/M4, now wired to live data)
`PlayingPieView` replaces `PlayingPhaseListView` as what `.playing` actually shows:
`PieLayoutView` reconnected to the live `GameSessionViewModel`, with a pulsing white
indicator (`ActiveSeatPulseView`) marking whichever seat is active. Tapping the ACTIVE
wedge passes the turn clockwise (`passToNextPlayer()`); tapping any OTHER wedge jumps
directly to that player (`selectPlayer(at:)`) — both behaviors coexist, per the original
M3/M4 design in Section 3. `Pass Turn` and `End Game Early` controls float above the
full-bleed pie, inset from the edges per the safe-area pitfall noted in Section 4.

---

## V2 Redesign (imported from Claude Design)

**Naming note (July 2026):** the app's public name is **Meeple Clock** (full App Store
name "Meeple Clock: Board Game Timer") — "Board Game Timer" was already taken on the App
Store. Internal identifiers (bundle id `com.ozsoffy.boardgametimer`, Xcode target, repo
name) deliberately keep the old name.

The app's UI was rebuilt against an approved Claude Design prototype
("Board Game Timer.dc.html" in the user's Claude Design project) — a dark-only visual
language (near-black `#0A0B0D` backgrounds, silver accents, ten fixed meeple gradients)
replacing the earlier system-styled screens. The new flow:

- **Tabs:** Statistics / Timer / Settings (`MainTabView`), Timer selected by default.
- **Timer home** (`TimerHomeView`): split "New Timer" button — main area opens
  `PlayerSetupView`, chevron opens a quick-start grid (1-6 players, saved defaults,
  straight into a running game) — plus a Recent Games list from history.
- **Player setup** (`PlayerSetupView` + `ColorPickerSheet`): count chips (1-6), per-player
  name + meeple color, optional game name (free text — BGG search dropped in this design),
  per-turn time limit (10s-300s stepper+slider), first-player menu incl. "Random"
  (replacing the multitouch finger-picker).
- **Active game** (`TimerActiveView` + `TimerGameViewModel`): full-bleed gradient wedges
  (2-player games split top/bottom; solo = full circle), active wedge at full opacity with
  white stroke + pulsing label, others dimmed; ONLY the active wedge is tappable and
  passes clockwise. Center silver-ringed circle: whole-game clock, "<name> turn",
  "Round N". Per-turn limit flips the active time red + double-beep ("overtime" — no
  forced turn end). Bottom bar: one-level undo / pause / end. No Setup/Explanation/
  Cleanup phases in this design.
- **Results** (`ResultsView`): per-player totals, crown on the LEAST-time player,
  ShareLink plain-text summary, Done — or Close when opened read-only from history.
- **Statistics** (`StatisticsView`): SwiftData-backed history (`GameRecord` @Model —
  the app's first persistent storage, fulfilling M5's persistence goal), empty state.
- **Settings** (`SettingsView`): default turn time, ten default meeple colors, combined
  Sound & Haptics toggle, keep-screen-awake, version, About link, Clear History
  (confirmation-guarded bulk delete).

Pre-redesign flow files (PlayerCountView, GameSessionViewModel, phase views, pie views,
FirstPlayerPickerView/MultiTouchDetectorView, BGG service/views) remain in the repo,
compiled but unreferenced, as reference material.

---

## Summary of Key Design Decisions (quick reference)

| Decision | Choice | Why |
|---|---|---|
| Min iOS version | 17.0 | SwiftData + `@Observable` + `.sensoryFeedback` + modern `TimelineView` |
| Persistence | SwiftData | Native, less boilerplate than Core Data, Apple's recommended path at this scale |
| State container | `@Observable` class | Less boilerplate than `ObservableObject`/`@Published`, iOS 17-native |
| Timer mechanism | `TimelineView` + Date math | Avoids manual `Timer`/Combine plumbing and cumulative drift bugs |
| Game-start presentation | `.fullScreenCover` | Prevents accidental swipe-back out of a running game |
| Pie wedge hit-testing | Tap on unrotated `WedgeShape`, rotate only the content overlay | Avoids rotated-hit-test confusion |
| Turn passing | Both direct-tap-any-wedge AND a dedicated "Pass Turn" control | Matches real chess-clock/turn-timer UX patterns; supports non-strict turn order |
| Top-level nav | 2-tab `TabView` (New Game / Past Games) | The two flows are parallel activities, not nested |

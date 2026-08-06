# Analytics coverage report

**App:** Meeple Clock · **SDK:** Firebase Analytics 12.17.0 · **Written against:** `feature/analytics-coverage`

What this app measures, where each measurement fires, and — the part that usually goes
undocumented — **what it does not measure and why**.

Everything here was verified by running the app with `-FIRAnalyticsDebugEnabled` and reading
the events off the device log, not by reading the source alone. The recipe to re-check it
yourself is in the last section.

---

## 1. At a glance

| Event | Fires when | Live in 1.1? |
|---|---|---|
| `game_started` | Start Game tapped on Player Setup | ✅ |
| `quick_game_started` | A Quick Timer number is tapped on Home | ✅ |
| `game_ended` | End (stop) tapped during a game | ✅ |
| `player_out_of_time` | A countdown player's bank hits zero | ✅ |
| `results_shared` | Share Summary tapped | ✅ |
| `history_cleared` | Clear History confirmed in Settings | ✅ |
| `screen_view` × 8 screens | Each screen appears | ❌ **added after 1.1 — see §4** |

Plus Firebase's own automatic events (`first_open`, `session_start`, `user_engagement`,
`app_update`, …), which need no code.

**The one thing to know:** version 1.1 — the build currently on the App Store — reports **no
usable screen data at all**. §4 explains why and what was done about it.

---

## 2. How it is wired

```
MeepleClockApp.init()
    └── FirebaseApp.configure()          ← must be here, not in .onAppear

AnalyticsService  (MeepleClock/Utilities/AnalyticsService.swift)
    └── the ONLY file that imports FirebaseAnalytics
            ├── 6 typed event methods
            ├── Screen enum (8 names)
            └── View.trackScreen(_:) modifier
```

**Why `configure()` is in `init`.** `Analytics.logEvent` silently drops anything logged before
`FirebaseApp.configure()` runs — no warning, no error, the event simply never exists. `init` is
the only point guaranteed to precede every screen and every event.

**Why one file.** `import FirebaseAnalytics` appears in exactly one place. That means event and
parameter names are spelled once rather than as string literals scattered across views (where a
typo creates a second, silently-empty row in the console), swapping or removing the SDK is a
one-file change, and — most relevant here — everything the app reports can be read on a single
screen, which is what makes the privacy policy checkable rather than aspirational.

**A note on the build warnings.** Firebase ships as *static* xcframeworks
(`file` reports `current ar archive`). Their code is linked directly into the app binary, so no
separate `FirebaseAnalytics.framework` exists in the shipped app and no standalone dSYM can
exist for it. That is the cause of the "Upload Symbols Failed" warnings at validation. They are
harmless: your own code symbolicates normally via `MeepleClock.app.dSYM`; only crash frames
originating *inside* Firebase would show as raw addresses.

---

## 3. Event reference

Every parameter sent by this app is a number, a boolean, or a fixed enum string. **Nothing the
user typed is ever included** — see §8.

### `game_started`
Fires in `startGame()` — [PlayerSetupView.swift:353](../MeepleClock/Views/Setup/PlayerSetupView.swift#L353), the moment Start Game is tapped.

| Parameter | Type | Meaning |
|---|---|---|
| `mode` | `stopwatch` \| `countdown` | Which clock mode was chosen |
| `player_count` | Int 1–6 | Seats configured |
| `turn_limit_seconds` | Int 10–300 | Per-turn limit; applies in both modes |
| `total_time_seconds` | Int | Countdown bank. **`0` in stopwatch games** — deliberately not omitted, so the parameter's type stays stable and the console's charts remain usable |
| `random_first_player` | Bool | Whether "Random First Player" was picked |

*Answers:* which mode people actually use, whether the 30-minute default bank and 60-second turn
limit are right, and typical table size.

### `quick_game_started`
Fires in `startQuickGame(playerCount:)` — [TimerHomeView.swift:204](../MeepleClock/Views/Home/TimerHomeView.swift#L204).

| Parameter | Type | Meaning |
|---|---|---|
| `player_count` | Int 1–6 | Seats |

*Answers:* does Quick Timer earn its place on the Home screen, versus the full setup flow? Kept
as a separate event rather than a parameter on `game_started` precisely so the two entry points
can be compared directly.

### `game_ended`
Fires in `endGame()` — [TimerActiveView.swift:246](../MeepleClock/Views/ActiveGame/TimerActiveView.swift#L246).

| Parameter | Type | Meaning |
|---|---|---|
| `mode` | `stopwatch` \| `countdown` | |
| `player_count` | Int | |
| `rounds` | Int | Completed rounds |
| `duration_seconds` | Int | Wall-clock game length, read *before* `endGame()` freezes the clock |

*Answers:* how long real games run, and — paired with `game_started` — the completion rate.

### `player_out_of_time`
Fires inside the bank-exhaustion watcher — [TimerGameViewModel.swift:367](../MeepleClock/ViewModels/TimerGameViewModel.swift#L367). **Once per player per game**, never repeated (the
`exhaustedSeats` set guarantees this).

| Parameter | Type | Meaning |
|---|---|---|
| `player_count` | Int | |
| `total_time_seconds` | Int | The bank they exhausted |

*Answers:* the single most useful countdown question — does the default 30 minutes actually fit
real games, or is it wrong?

### `results_shared`
Fires from a `simultaneousGesture` on the ShareLink — [ResultsView.swift:107](../MeepleClock/Views/Results/ResultsView.swift#L107).

| Parameter | Type | Meaning |
|---|---|---|
| `mode` | `stopwatch` \| `countdown` | |

⚠️ **This records that sharing was *started*, not completed.** `ShareLink` has no action closure,
and what happens after the system sheet opens is invisible to the app. A user who opens the
sheet and cancels is counted identically to one who sends the summary.

### `history_cleared`
Fires in `clearHistory()` — [SettingsView.swift:203](../MeepleClock/Views/Settings/SettingsView.swift#L203), after the confirmation dialog.

| Parameter | Type | Meaning |
|---|---|---|
| `game_count` | Int | How many games were deleted, counted before the delete |

---

## 4. Screen views — the gap that 1.1 shipped with

### What was wrong

Firebase's automatic screen tracking works by hooking `UIViewController.viewDidAppear`. **That
does nothing in a pure SwiftUI app.** Every screen here lives inside a single hosting
controller, so there is nothing for it to tell apart.

Measured against the shipped 1.1 code across two full sessions that visited every screen, the
only `screen_view` events auto-collection produced were:

```
ga_screen_class = UIActivityViewController   ← the system share sheet
ga_screen_class = PlatformAlertController    ← the "Clear all history?" dialog
```

Both presented by the *system*. **Zero** for Home, Player Setup, Active Game, Results,
Statistics or Settings.

### What was done

An `AnalyticsService.Screen` enum names the eight screens once, and a `View.trackScreen(_:)`
wrapper around Firebase's own `.analyticsScreen(name:class:)` modifier applies them. The wrapper
lives in `AnalyticsService.swift` so the one-file rule survives.

| Screen name | View | Line |
|---|---|---|
| `home` | `TimerHomeView` | [179](../MeepleClock/Views/Home/TimerHomeView.swift#L179) |
| `player_setup` | `PlayerSetupView` | [261](../MeepleClock/Views/Setup/PlayerSetupView.swift#L261) |
| `active_game` | `TimerActiveView` | [195](../MeepleClock/Views/ActiveGame/TimerActiveView.swift#L195) |
| `results` | `ResultsView` (game just ended) | [145](../MeepleClock/Views/Results/ResultsView.swift#L145) |
| `results_history` | `ResultsView` (re-opened from history) | [145](../MeepleClock/Views/Results/ResultsView.swift#L145) |
| `statistics` | `StatisticsView` | [81](../MeepleClock/Views/Stats/StatisticsView.swift#L81) |
| `settings` | `SettingsView` | [161](../MeepleClock/Views/Settings/SettingsView.swift#L161) |
| `about` | `AboutView` | [70](../MeepleClock/Views/About/AboutView.swift#L70) |

Two deliberate choices worth knowing:

- **Results is two names.** A game that just finished and one re-opened from history are the
  same view but completely different signals about how the app is used.
- **Active Game is tagged on `gameBody`, not `body`.** The same full-screen cover swaps over to
  the results view when a game ends; tagging `body` would re-log `active_game` at that moment.

### How to read the numbers

`.analyticsScreen` fires on `onAppear`, so it counts **appearances, not unique visits**.
Navigating away and back logs the screen again.

Measured over a ten-step walk through the app, this was exactly **1:1 with navigation** — no
spurious duplicates from tab switching or sheet dismissal:

```
home → settings → about → settings → statistics → home → player_setup → active_game
     → results → results_history
```

The only repeats (`home` ×2, `settings` ×2) were screens genuinely returned to. So the counts
are trustworthy as "times this screen was shown"; just don't read them as distinct users or
distinct sessions.

### ⚠️ This is not in the App Store build

1.1 was submitted before this fix. Screen data starts only when the next build ships.

---

## 5. Coverage map

Every screen, every interactive control, and whether anything is recorded.

### Splash
| Control | Tracked | Note |
|---|---|---|
| — (no controls) | ❌ | Deliberate. 2.2s, always first, identical for everyone — it would only inflate counts. |

### Home
| Control | Tracked | Note |
|---|---|---|
| Screen appears | ✅ `screen_view: home` | |
| **New Timer** (main) | ❌ | Covered indirectly — `screen_view: player_setup` fires immediately after |
| Chevron (open/close Quick Timer) | ❌ | Pure UI toggle, no decision recorded |
| **Quick Timer 1–6** | ✅ `quick_game_started` | |
| Recent Games row | ❌ | Covered indirectly by `screen_view: results_history` |

### Player Setup
| Control | Tracked | Note |
|---|---|---|
| Screen appears | ✅ `screen_view: player_setup` | |
| Mode chips | ❌ | Final choice captured in `game_started.mode` |
| Player count chips | ❌ | Final value in `game_started.player_count` |
| Meeple tap → colour sheet | ❌ | See gaps §7 |
| Player name field | ❌ | **Deliberate — user content, never sent** |
| Game name field | ❌ | **Deliberate — user content, never sent** |
| Total time stepper / slider | ❌ | Final value in `game_started.total_time_seconds` |
| Turn limit stepper / slider | ❌ | Final value in `game_started.turn_limit_seconds` |
| First player picker | ❌ | Random-or-not in `game_started.random_first_player` |
| Drag to reorder seats | ❌ | |
| **Start Game** | ✅ `game_started` | |
| Back chevron (abandon setup) | ❌ | **Now derivable** — see gaps §7 |

Only *final committed values* are recorded, never the fiddling in between. A user who drags the
turn-limit slider twenty times produces one event with the value they settled on.

### Colour Picker sheet
| Control | Tracked | Note |
|---|---|---|
| Sheet appears | ❌ | Deliberate — transient picker, not a destination |
| Colour chosen | ❌ | See gaps §7 |

### Active Game
| Control | Tracked | Note |
|---|---|---|
| Screen appears | ✅ `screen_view: active_game` | |
| Tap wedge to pass turn | ❌ | **Deliberate — see §6** |
| Undo | ❌ | Deliberate |
| Pause / Resume | ❌ | Deliberate |
| **End game** | ✅ `game_ended` | |
| Countdown bank hits zero | ✅ `player_out_of_time` | Not a control — a state change |
| Turn exceeds limit (overtime) | ❌ | See gaps §7 |

### Results
| Control | Tracked | Note |
|---|---|---|
| Screen appears | ✅ `screen_view: results` / `results_history` | |
| **Share Summary** | ✅ `results_shared` | Start only, not completion |
| Done / Close | ❌ | |

### Statistics
| Control | Tracked | Note |
|---|---|---|
| Screen appears | ✅ `screen_view: statistics` | |
| Tap a game card | ❌ | Covered indirectly by `screen_view: results_history` |

### Settings
| Control | Tracked | Note |
|---|---|---|
| Screen appears | ✅ `screen_view: settings` | |
| Default turn time ± | ❌ | See gaps §7 |
| Default colour slot | ❌ | See gaps §7 |
| Sound & Haptics toggle | ❌ | See gaps §7 |
| Keep Screen Awake toggle | ❌ | See gaps §7 |
| About row | ❌ | Covered indirectly by `screen_view: about` |
| **Clear History** | ✅ `history_cleared` | Fires only after confirmation |

### About
| Control | Tracked | Note |
|---|---|---|
| Screen appears | ✅ `screen_view: about` | |
| LinkedIn link | ❌ | |
| GitHub link | ❌ | |
| **Rate This App** | ❌ | **Highest-value gap — see §7** |

---

## 6. Deliberately not tracked

**Turn-level events** — every pass, pause, resume, undo.

A six-player game running an hour would fire several hundred events. They would swamp the
game-level numbers in every console view, burn through Firebase's per-app event quota, and
answer nothing the aggregate `rounds` and `duration_seconds` on `game_ended` don't already
answer more cheaply. If turn-level behaviour ever becomes a real question, the right shape is a
*summary* on `game_ended` (e.g. `undo_count`), not one event per tap.

**Anything the user typed** — player names, game names, saved history.

Never sent, by design, not by omission. This is the claim `PRIVACY.md` makes and the one that
would be most damaging to get wrong. The typed-value fields on Player Setup are the only place
this could leak, and they are simply not instrumented.

---

## 7. Gaps worth closing next

Ranked by value per unit of effort.

**1. `rate_app_tapped` — About screen.** The Rate This App button exists solely to drive App
Store ratings, and right now there is zero visibility into whether anyone presses it. One line.
(iOS throttles whether the prompt actually appears, which the app can't observe — but the *tap*
is the interesting signal anyway.)

**2. Settings changes** — `setting_changed(name, value)` on the turn-time stepper, both toggles,
and the colour slots. These are the defaults every new game inherits. If most people immediately
change the 60-second turn limit, the default is wrong — and today that is invisible. Four small
call sites.

**3. `turn_overtime_reached`** — fires when a turn crosses the per-turn limit. Directly answers
whether 60 seconds is a sensible default, and how much the limit actually bites in practice.
Bounded volume if capped at once per turn. Pairs naturally with `player_out_of_time`, which
already covers the countdown equivalent.

**4. Colour customisation** — whether anyone changes meeple colours at all. Justifies (or
retires) the ten-colour palette, the picker sheet, and the default-colours grid in Settings.

**5. Setup abandonment** — *no new code needed.* Now that `screen_view: player_setup` exists,
this is derivable in the console as `player_setup` views minus `game_started` events. Worth
building as a funnel once the next build has data.

**6. Share completion** — would need replacing `ShareLink` with a custom presentation to observe
the outcome. Meaningful cost for a modest signal; listed for completeness, not recommended.

Explicitly **not** recommended: per-turn events (§6), and anything capturing typed text (§8).

---

## 8. Privacy alignment

The complete set of values this app can send:

```
mode                  stopwatch | countdown
player_count          1–6
rounds                Int
turn_limit_seconds    10–300
total_time_seconds    Int
duration_seconds      Int
random_first_player   Bool
game_count            Int
screen name           one of 8 fixed strings
```

Numbers and fixed enums. No free text, therefore no player names, game names or history — which
is exactly what `PRIVACY.md` claims.

**No advertising identifier.** Confirmed by the SDK itself at launch:

```
[FirebaseAnalytics][I-ACS044003] GoogleAppMeasurementIdentitySupport dependency is not
currently linked. IDFA will not be accessible.
```

**Worth knowing:** `GoogleAdsOnDeviceConversion` appears in the dependency tree. It is pulled in
transitively by `GoogleAppMeasurement` and cannot be excluded while keeping Analytics. None of
its APIs are called and no IDFA is collected, so it does not change the declaration — but it is
the explanation if an App Store reviewer ever asks about an ads-named library in a
not-used-for-tracking app.

**App Store Connect declaration** (see `Marketing/AppStoreConnect-1.1.md`):

| Data type | Purpose | Linked to identity | Tracking |
|---|---|---|---|
| Usage Data → Product Interaction | Analytics | No | No |
| Identifiers → Device ID | Analytics | No | No |

Because nothing is used for tracking, no App Tracking Transparency prompt is required, and none
is implemented.

**There is no in-app opt-out.** A deliberate decision. `PRIVACY.md` says so plainly and states
that deleting the app stops collection.

---

## 9. Verify it yourself

Don't trust this document — re-run it. Build to a simulator, then:

```bash
UDID=$(xcrun simctl list devices booted | grep -o "[0-9A-F-]\{36\}" | head -1)
xcrun simctl spawn "$UDID" log stream --level debug --predicate 'process == "MeepleClock"' > fb.log &
xcrun simctl launch "$UDID" com.ozsoffy.meepleclock -FIRAnalyticsDebugEnabled
```

Use the app, then read back every event with its parameters:

```bash
python3 - fb.log <<'PY'
import sys, re
raw = open(sys.argv[1], errors="ignore").read()
for m in re.finditer(r"Logging event: origin, name, params: app, ([a-z_]+)[^,]*, \{", raw):
    name, i = m.group(1), raw.index("{", m.end() - 1)
    depth, j = 0, i
    while j < len(raw):
        if raw[j] == "{": depth += 1
        elif raw[j] == "}":
            depth -= 1
            if depth == 0: break
        j += 1
    p = re.findall(r"^\s*([a-zA-Z_]+)[^=]*=\s*(.+?);?\s*$", raw[i+1:j], re.M)
    p = [(k, v.strip().rstrip(";")) for k, v in p if not k.startswith(("ga_", "_"))]
    print(f"{name}: " + ", ".join(f"{k}={v}" for k, v in p))
PY
```

Events also appear in the Firebase console under **DebugView** within about a minute.

To confirm this report has not gone stale, every documented call site should match:

```bash
grep -rn "AnalyticsService\.\|trackScreen(" MeepleClock --include="*.swift"
```

---

## Appendix — change history

| Date | Change |
|---|---|
| 2026-08-06 | Six custom events added; shipped in 1.1 |
| 2026-08-06 | `screen_view` gap found and fixed (§4); **not in 1.1** |

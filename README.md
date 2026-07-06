# Board Game Timer

<img src="BoardGameTimer/Assets.xcassets/AppIconPreview.imageset/AppIconPreview.png" width="100" height="100" alt="Board Game Timer app icon: a dark four-color radial pie with a silver-ringed clock in the center" align="left">

A native SwiftUI iOS app for timing tabletop board games with up to 6 players —
chess-clock style. Set the phone flat in the middle of the table: every player gets their
own gradient wedge of a full-screen radial layout, tapping your own wedge passes the turn
clockwise, and a per-turn time limit calls out slowpokes with a red overtime warning.

<br clear="left">

Built with a dark, silver-accented design language imported from an approved
[Claude Design](https://claude.ai/design) prototype. See [PLAN.md](PLAN.md) for the full
design history.

## Features

- 1–6 players, each with an editable name and one of ten gradient meeple colors
- Drag-to-reorder seats, first-player picker (or random), optional game name
- Full-screen radial timer: active wedge glows and pulses, only it is tappable, and
  tapping passes the turn clockwise; 2-player games split the screen into facing halves
- Per-turn time limit (10s–5min) with red overtime warning, double-beep, and haptics
- Whole-game clock, round counter, one-level undo, pause/resume
- Results with a crown for the fastest player and a shareable plain-text summary
- Game history saved with SwiftData — browse past games in the Statistics tab
- Quick Timer: launch a 1–6 player game with saved defaults in two taps
- Settings: default turn time, default meeple colors, sound & haptics, keep-screen-awake

## Screenshots

| Home | Player setup | Live game | Results |
|---|---|---|---|
| ![Home screen](Marketing/Screenshots/01-home.png) | ![Player setup](Marketing/Screenshots/02-player-setup.png) | ![Active radial timer](Marketing/Screenshots/03-active-game.png) | ![Results with winner crown](Marketing/Screenshots/04-results.png) |

App Store-ready marketing assets (6.9" screenshots at 1320x2868 and app icon exports)
live in [Marketing/](Marketing).

## Tech stack

- Swift & SwiftUI only (no UIKit view controllers, no third-party dependencies)
- iOS 17.0 minimum deployment target
- `@Observable` view models, `TimelineView`-driven drift-free timers (date math, never
  accumulated ticks)
- SwiftData for persisted game history
- Fixed dark theme with a shared palette (`MeeplePalette`) and a custom meeple `Shape`
  ported from the design's SVG

## Project structure

```
BoardGameTimer/
  BoardGameTimerApp.swift    App entry: splash -> tab bar, SwiftData container
  Models/                    MeeplePalette, MeepleShape, GameRecord, GameSetupDraft
  ViewModels/                TimerGameViewModel (chess-clock engine)
  Utilities/                 TimeFormatting
  Views/
    Home/                    Timer tab landing (split New Timer button, recents)
    Setup/                   Player setup + color picker sheet
    ActiveGame/              The radial live-game screen
    Results/                 Post-game summary
    Stats/                   History tab
    Settings/                Settings tab
    About/                   About screen (developer, links, rating)
    Splash/                  Animated launch splash
```

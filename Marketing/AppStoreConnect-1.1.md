# App Store Connect — v1.1 submission checklist

Everything below has to be done by hand in App Store Connect (it needs your Apple ID and
two-factor authentication). Work top to bottom.

---

## 1. Create the version

**App Store Connect → Meeple Clock → (+) next to iOS App → New version: `1.1`**

| Field | Value |
|---|---|
| Version | `1.1` |
| Build | `2` |

Both are already set in the Xcode project (`MARKETING_VERSION = 1.1`,
`CURRENT_PROJECT_VERSION = 2`), so Xcode's archive will match.

## 2. What's New in This Version

Paste the contents of [`ReleaseNotes/1.1.txt`](ReleaseNotes/1.1.txt).

## 3. ⚠️ App Privacy — this MUST change

Version 1.0 is currently declared as **"Data Not Collected."** Adding Firebase Analytics makes
that false, and shipping it unchanged is a review rejection and a policy violation.

**App Store Connect → Meeple Clock → App Privacy → Edit**

First answer **"Yes"** to "Do you or your third-party partners collect data from this app?"
Then declare exactly these two types and nothing else:

### Data type 1 — Usage Data › Product Interaction

| Question | Answer |
|---|---|
| Is this data used for tracking? | **No** |
| Is this data linked to the user's identity? | **No** |
| Purposes | **Analytics** only |

### Data type 2 — Identifiers › Device ID

| Question | Answer |
|---|---|
| Is this data used for tracking? | **No** |
| Is this data linked to the user's identity? | **No** |
| Purposes | **Analytics** only |

(This covers the Firebase app instance ID — a random per-install identifier. Note it is *not*
the advertising identifier; the app does not collect IDFA.)

**Do NOT declare:** Contact Info, Health, Financial, Location, Contacts, User Content,
Browsing History, Search History, Purchases, Diagnostics, or Advertising Data. None are
collected.

Because nothing is used for tracking, **no App Tracking Transparency prompt is required** and
none is implemented.

## 4. ⚠️ Privacy policy URL

**App Store Connect → App Information → Privacy Policy URL**

`PRIVACY.md` has been rewritten in this repo to describe the analytics collection. Check what
URL is currently on file for 1.0 and make sure it now serves the **updated** text.

Note that the repository has no GitHub Pages site and no `docs/` folder, so if the existing
URL points at a rendered GitHub view of `PRIVACY.md`, it will update automatically once this
branch merges to `main`. If it points anywhere else, that destination has to be updated by
hand. **Do not submit with a privacy policy that still says "no analytics".**

## 5. Screenshots

Replace all screenshots — every existing one shows the old blocky player figures, and the
Player Setup shot no longer matches the screen (it gains the Mode chips and, in Countdown, a
Total Time Per Player field).

**Done.** Regenerated at **1320 × 2868 (6.9")** from an iPhone 17 Pro Max simulator — the size
App Store Connect wants as the primary iPhone set (it scales down for smaller devices). All
five are in [`Screenshots/`](Screenshots/), captured with a clean 9:41 status bar:

| File | Shows |
|---|---|
| `01-home.png` | Home with recent games |
| `02-player-setup.png` | Player Setup with **Countdown** selected — the new Mode chips and Total Time Per Player field |
| `03-active-game.png` | The radial live game, 4 players, stopwatch |
| `04-results.png` | Countdown results with the mode caption and per-player time remaining |
| `05-countdown.png` | A countdown game in progress, all four clocks counting down |

Note the 1.0 screenshots were 1242 × 2688 — the **6.5"** size — even though `README.md`
claimed 6.9". Both have now been corrected.

## 6. Export compliance

Unchanged — `ITSAppUsesNonExemptEncryption` is already `NO` in the build settings, and that
stays correct. Firebase communicates over standard HTTPS, which is exempt.

## 7. Before you hit Submit

- [ ] Version `1.1`, build `2` uploaded and selected
- [ ] Release notes pasted
- [ ] App Privacy changed off "Data Not Collected" (section 3)
- [ ] Privacy policy URL serves the updated text (section 4)
- [ ] Screenshots replaced (section 5)
- [ ] `GoogleService-Info.plist` is in the archived build — otherwise Analytics ships dead.
      Confirm events arrive in Firebase console → **DebugView** before archiving.

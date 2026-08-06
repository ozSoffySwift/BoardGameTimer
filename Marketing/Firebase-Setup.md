# Firebase Analytics — console setup (manual, one time)

This is the one part of v1.1 that can't be done from the codebase: creating the Firebase
project needs your Google login. Work through it once, drop the file it gives you into the
project, and everything after that is code.

**Time:** about 5 minutes.

---

## 1. Create the Firebase project

1. Go to <https://console.firebase.google.com> and sign in with your Google account.
2. Click **Create a project** (or **Add project**).
3. Name it **`Meeple Clock`**. Accept the terms.
4. On the **Google Analytics** step, leave it **ENABLED**.
   ⚠️ This is the step that matters — Analytics *is* the feature. If you switch it off here,
   you get a Firebase project with no Analytics property and the SDK will have nothing to
   report to.
5. Choose an existing Google Analytics account, or let it create a **Default Account for
   Firebase**. Either is fine.
6. Click **Create project**, and wait for it to finish provisioning.

## 2. Register the iOS app

1. On the project's overview page, click the **iOS+** button ("Add an app to get started").
2. **Apple bundle ID** — enter exactly:

   ```
   com.ozsoffy.meepleclock
   ```

   This must match character for character. It's the `PRODUCT_BUNDLE_IDENTIFIER` in the Xcode
   project, and Firebase routes data by it — a typo here means the app reports nothing, silently.
3. **App nickname:** `Meeple Clock` (optional, only shown in the console).
4. **App Store ID:** you can leave this blank, or paste the numeric ID from your app's App
   Store Connect URL. It's optional.
5. Click **Register app**.

## 3. Download the config file

1. The next screen offers **`GoogleService-Info.plist`** — download it.
2. Move it to exactly this path:

   ```
   /Users/ozsoffy/Documents/MeepleClock/MeepleClock/GoogleService-Info.plist
   ```

   (Inside the inner `MeepleClock` folder, next to `MeepleClockApp.swift` — not the repo root.)

3. **Stop there.** Skip the console's remaining steps — "Add Firebase SDK", "Add
   initialization code", and "Next steps"/"Verify installation". Those are all done in code:
   the Swift Package, the `FirebaseApp.configure()` call, and the analytics event wrapper.

## 4. Tell me it's in place

Then I'll add the SDK, wire up the events, and we'll confirm they arrive in the console's
**DebugView** before this ships.

---

## Notes

**Is it safe to commit `GoogleService-Info.plist` to a public repo?**

Yes. Despite the `API_KEY` field, it is not a credential — it's a bundle of client
identifiers, and Google's own documentation treats it as shippable inside the app binary
(where anyone can extract it anyway). Firebase security comes from server-side rules, not
from this file being secret. For Analytics-only usage there is nothing sensitive in it at
all. Say the word if you'd rather gitignore it anyway, and I'll set that up instead — the
tradeoff is that a fresh clone then won't build until the file is added by hand.

**What this changes about the app's privacy story**

Meeple Clock 1.0 collected nothing and had no network code at all. Once Analytics ships,
that stops being true, and two things must change in the same release:

- `PRIVACY.md` gets rewritten (I've done this — see the file).
- The **App Privacy** section in App Store Connect must change from "Data Not Collected".
  The exact answers to select are in `Marketing/AppStoreConnect-1.1.md`.

No App Tracking Transparency prompt is required, because the data isn't used to track you
across other companies' apps or websites.

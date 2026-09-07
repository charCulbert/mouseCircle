# Releasing Mouse Circle

## Before any release

1. Bump the version in Xcode: select the **Mouse Circle** target → **General**.
   - **Version** (`MARKETING_VERSION`) is what users see, e.g. `1.0`, `1.1`.
   - **Build** (`CURRENT_PROJECT_VERSION`) must go up with every upload, e.g. `1`, `2`, `3`.
2. Build and run once. Check the circle appears, the menu works, and ⌃⌥⌘M hides and shows it.

## GitHub release (free build)

1. **Product → Archive**.
2. In the Organizer choose **Distribute App → Direct Distribution**. This signs with your Developer ID and notarises, so users don't get a Gatekeeper warning.
3. Zip the exported `Mouse Circle.app` and attach it to a new GitHub release with a short changelog.

## Mac App Store

### One-time setup

1. Sign in at [App Store Connect](https://appstoreconnect.apple.com) with your paid developer account.
2. **Certificates, Identifiers & Profiles → Identifiers → +** and register the App ID `com.charlieculbert.MouseCircle` (the project already uses this bundle ID).
3. **Apps → +** → **New App**. Platform macOS, name **Mouse Circle**, primary language, bundle ID from step 2, SKU anything unique like `mousecircle-mac`. If the name is taken, pick a variant and change `INFOPLIST_KEY_CFBundleDisplayName` in the project to match.
4. Fill in the listing (all in the app's page in App Store Connect):
   - **Category**: Utilities.
   - **Description** and **Keywords**: cursor, highlight, pointer, presentation, screen recording, demo, accessibility.
   - **Privacy Policy URL**: required even for apps that collect nothing. A GitHub Pages or gist page saying "Mouse Circle does not collect, store or transmit any data" is enough.
   - **App Privacy** questionnaire: answer that no data is collected.
   - **Pricing**: Free, or Tier 2 for $1.99 / £1.99.
   - **Screenshots**: at least one per size class; 2880×1800 or 2560×1600 PNGs are accepted. Suggested set: the circle over a slide or code editor, the dropdown menu, and the shortcut window.
   - **Age rating**: answer the questionnaire; it will come out as 4+.

### Each submission

1. In Xcode make sure the scheme is set to **Any Mac (Apple Silicon, Intel)** and run **Product → Archive**.
2. In the Organizer select the archive → **Distribute App → App Store Connect → Upload**. Accept the defaults for signing (automatic). Xcode validates and uploads.
3. Wait for the "build has completed processing" email (usually 5–30 minutes).
4. In App Store Connect open the app version, click **+ Build** and pick the uploaded build.
5. Fill in **What's New** (for updates) and **App Review Information** (contact details; no login needed, so leave the demo account blank). Add a review note along the lines of:

   > Mouse Circle is a menu bar utility. After launch, click the ring icon in the menu bar to see the controls. The circle follows the cursor over all apps. Press ⌃⌥⌘M to hide or show it. No permissions or account are required.

6. Click **Add for Review**, then **Submit to App Review**. Review typically takes 1–3 days.

### Already in place for review

- App Sandbox and Hardened Runtime are enabled; the only entitlement is the sandbox itself.
- The global shortcut uses the Carbon hot key API, which is allowed in the sandbox and needs no Accessibility or Input Monitoring permission.
- `PrivacyInfo.xcprivacy` declares the UserDefaults access (reason CA92.1), which App Store Connect requires.
- `LSApplicationCategoryType` is Utilities and `ITSAppUsesNonExemptEncryption` is `NO`, so no export compliance questions.
- The app collects no data and asks for no permissions, so the privacy questionnaire is all "No".
- Full app icon set is included.

## Listing copy

Description:

> Mouse Circle is a menu bar app that draws a circle around your mouse.
>
> The circle is customizable in color, size and thickness. Animations of variable intensity can optionally be applied on left and right clicks.
>
> Useful for keeping track of your mouse, especially during presentations or screen recordings.
>
> • Works across all displays and over full-screen apps
> • Global keyboard shortcut to hide and show the circle
> • Remembers your settings

Subtitle: "Highlight your cursor". Keywords: cursor, highlight, pointer, mouse, presentation, screen recording, demo, spotlight.

## Licensing note

The GitHub source is GPL-3.0. As the sole copyright holder you can also sell the same code on the App Store without conflict, since the licence binds recipients, not you. If you ever accept outside contributions, either keep them out of App Store builds or switch the repo to a permissive licence like MIT first.

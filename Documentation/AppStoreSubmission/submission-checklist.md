# Submission pre-flight checklist

Run through this list once before clicking **Submit for Review** in
App Store Connect. Every item maps to a concrete check that can be
performed locally; together they cover the rejection reasons we have
seen for small menu-bar utilities.

## Build hygiene

- [ ] `project.yml` has the correct `MARKETING_VERSION` and a build
      number (`CURRENT_PROJECT_VERSION`) higher than any previously
      uploaded build.
- [ ] `xcodegen generate` was run after editing `project.yml`.
- [ ] `scripts/release-app-store-archive.sh` produced
      `build/AppStore/cpMan.xcarchive` and `build/AppStore/Export/cpMan.pkg`
      with no warnings.
- [ ] `./scripts/verify-sandbox-release.sh /path/to/cpMan.app` prints
      "✅ All required checks passed.":
  - App Sandbox enabled.
  - Hardened Runtime enabled.
  - `codesign --verify --deep --strict` clean.
  - `PrivacyInfo.xcprivacy` present.
  - `NSAccessibilityUsageDescription` **absent**.
  - `LSUIElement` true.

## `Info.plist`

- [ ] `CFBundleIdentifier` = `com.cpman.app`.
- [ ] `CFBundleShortVersionString` matches what you intend to ship.
- [ ] `LSMinimumSystemVersion` ≥ `14.0`.
- [ ] `LSApplicationCategoryType` = `public.app-category.productivity`.
- [ ] `ITSAppUsesNonExemptEncryption` = `false`.
- [ ] **No** `NSAccessibilityUsageDescription`, `NSAppleEventsUsageDescription`,
      `NSCameraUsageDescription`, `NSMicrophoneUsageDescription`, etc.
- [ ] `NSHumanReadableCopyright` set to the year and the legal owner.

## Entitlements (Release)

- [ ] `com.apple.security.app-sandbox` = true.
- [ ] **No** `com.apple.security.network.client` / `.network.server`.
- [ ] **No** `com.apple.security.cs.*` (hardened-runtime exemptions).
- [ ] **No** `com.apple.security.automation.apple-events`.
- [ ] **No** TCC-related temporary-exception keys.

## App Store Connect — App Information

- [ ] Primary category = Productivity, Secondary = Utilities.
- [ ] Content rights → "Does NOT contain, show, or access third-party
      content."
- [ ] Age rating questionnaire saved → result is **4+**
      (see `age-rating.md`).
- [ ] Encryption answer → **No** (matches `ITSAppUsesNonExemptEncryption`).

## App Store Connect — App Privacy

- [ ] "Data Not Collected" label confirmed
      (see `privacy-labels.md`).

## App Store Connect — Version 1.0.0

- [ ] App name and subtitle from `metadata.md` pasted.
- [ ] Promotional text pasted (≤170 chars).
- [ ] Description pasted (≤4000 chars).
- [ ] Keywords pasted (≤100 chars).
- [ ] Support URL working and reachable from a browser.
- [ ] Privacy Policy URL working and reachable from a browser.
- [ ] At least one screenshot (preferably four, per
      `screenshots.md`) uploaded at 2880×1800 or an accepted size.
- [ ] Build attached (the `.pkg` uploaded via Transporter or Xcode
      Organizer, then selected in App Store Connect after it finishes
      processing — usually 5–30 minutes).
- [ ] Release option chosen (Automatic / Manual).

## App Store Connect — App Review Information

- [ ] Contact name, phone, email filled in with values you actually
      monitor.
- [ ] Notes filled in from `review-notes.md`.
- [ ] (Optional but recommended) 20–40s demo video attached, per
      `screenshots.md` → "Optional review video".
- [ ] "Sign-in required" = No.

## Final smoke test on a clean Mac

- [ ] Install the signed `.pkg` (or run the same binary that was
      uploaded) on a separate Mac account / VM.
- [ ] Launch → menu-bar icon appears within ~2 seconds, no Dock icon.
- [ ] ⌃⌥V opens the picker; copy/paste round-trip works.
- [ ] No TCC prompts of any kind.
- [ ] Activity Monitor → cpMan does not appear under Network.

When every box is checked, click **Submit for Review** and walk away.
The next time you have to think about cpMan is when Apple emails you.

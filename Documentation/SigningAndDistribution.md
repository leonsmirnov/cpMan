# Signing & Distribution — cpMan

cpMan ships through two channels from one source tree:

| Channel | Signing | Script |
|---------|---------|--------|
| Mac App Store | Apple Distribution + Mac App Store provisioning profile | `scripts/release-app-store-archive.sh` |
| Direct DMG | Developer ID Application + notarization | `scripts/build-release-dmg-and-install.sh` (with env vars) |
| Local testing | Ad-hoc | `scripts/build-release-dmg-and-install.sh` (no env vars) |

`MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` are centralized in `project.yml` and resolved through `Info.plist` (`$(MARKETING_VERSION)` / `$(CURRENT_PROJECT_VERSION)`).

---

## 1) One-time Apple setup

1. **Enroll** in the Apple Developer Program.
2. **Create the App ID**: bundle ID `com.cpman.app` (must match `Info.plist`).
3. **Create signing certificates** in Xcode → Settings → Accounts → *Manage Certificates*:
   - **Apple Distribution** (Mac App Store).
   - **Developer ID Application** (direct download / DMG).
4. **Provisioning profiles**:
   - For App Store: a profile of type *Mac App Store* tied to `com.cpman.app` and the Apple Distribution certificate. Note its **name or UUID**.
5. **Notarization credentials** (for direct DMG):
   - Create an **app-specific password** at appleid.apple.com.
   - Store it once locally:
     ```bash
     xcrun notarytool store-credentials cpman-notary \
       --apple-id "you@example.com" \
       --team-id "TEAMID" \
       --password "app-specific-password"
     ```
     The script will use this profile name (`cpman-notary`).

---

## 2) Mac App Store release

### Required env vars

```bash
export CPMAN_DEVELOPMENT_TEAM="TEAMID"
export CPMAN_APPSTORE_IDENTITY="Apple Distribution: Your Name (TEAMID)"
export CPMAN_APPSTORE_PROVISIONING_PROFILE="cpMan App Store"   # name or UUID
```

### Build & export

```bash
./scripts/release-app-store-archive.sh
```

This produces:

- `build/AppStore/cpMan.xcarchive`
- `build/AppStore/Export/cpMan.pkg`

### Upload

Open the archive in **Xcode → Organizer** and choose **Distribute App → App Store Connect**, or upload `cpMan.pkg` with **Transporter** / `xcrun altool`.

In **App Store Connect** for cpMan:

- Set **Version** to `1.0.0`, **Build** to whatever `CURRENT_PROJECT_VERSION` was used (`1` initially; bump for every new upload).
- Fill **App Privacy** (cpMan does not collect data).
- **App Review Information → Notes**: paste the contents of `Documentation/AppStoreReviewNotes.txt`.
- **Screenshots**, description, support URL, privacy policy URL.

---

## 3) Direct DMG (Developer ID + notarization)

### Required env vars

```bash
export CPMAN_DEVELOPMENT_TEAM="TEAMID"
export CPMAN_DEVID_IDENTITY="Developer ID Application: Your Name (TEAMID)"
export CPMAN_NOTARY_PROFILE="cpman-notary"   # from `notarytool store-credentials`
```

(Alternative: `CPMAN_NOTARY_APPLE_ID`, `CPMAN_NOTARY_APP_PASSWORD`, `CPMAN_DEVELOPMENT_TEAM`.)

### Build, sign, notarize, install

```bash
./scripts/build-release-dmg-and-install.sh
```

The script auto-detects mode:

- `CPMAN_DEVID_IDENTITY` set → **Developer ID** signing (+ notarization if a notary profile is present).
- Otherwise → **ad-hoc** (local-only) build.

The output DMG is signed and stapled when notarization succeeds, so Gatekeeper accepts it on any user’s Mac.

---

## 4) Sandbox / signing verification

After any Release build, run:

```bash
./scripts/verify-sandbox-release.sh /Applications/cpMan.app
# or any path to a built cpMan.app
```

It checks:

- App Sandbox enabled in entitlements
- Hardened Runtime flag
- `codesign --verify --deep --strict`
- Privacy manifest present
- `NSAccessibilityUsageDescription` set
- Menu-bar-only (`LSUIElement`)
- Gatekeeper acceptance (informational only)

A clean run prints `✅ All required checks passed.`.

---

## 5) Versioning policy

- **`MARKETING_VERSION`** (visible to users): bump on each release (`1.0.0` → `1.0.1`, `1.1.0`, ...).
- **`CURRENT_PROJECT_VERSION`** (build number): **strictly increases** for every binary uploaded to App Store Connect; the same version may have many builds.
- Both DMG and App Store builds for the same release should share the same `MARKETING_VERSION`.

To bump for the next release, edit those two values in `project.yml` and re-run `xcodegen generate`.

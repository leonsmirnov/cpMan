# Signing & Distribution — cpMan

cpMan ships through two channels from one source tree:

| Channel | Signing | Script |
|---------|---------|--------|
| Mac App Store | Apple Distribution (app) + **Mac Installer Distribution** (`.pkg`) + Mac App Store profile | `scripts/release-app-store-archive.sh` |
| Direct DMG | Developer ID Application + notarization | `scripts/build-release-dmg-and-install.sh` (with env vars) |
| Local testing | Ad-hoc | `scripts/build-release-dmg-and-install.sh` (no env vars) |

`MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` are centralized in `project.yml` and resolved through `Info.plist` (`$(MARKETING_VERSION)` / `$(CURRENT_PROJECT_VERSION)`).

**App Store archives** use the **`AppStore`** build configuration: same optimizations as **Release**, but **Manual** signing applies only to the **cpMan** app target. SwiftPM packages (KeyboardShortcuts) remain **Automatic**, which avoids `KeyboardShortcuts does not support provisioning profiles` when manual profile settings would otherwise be applied to every target.

---

## 1) One-time Apple setup

1. **Enroll** in the Apple Developer Program.
2. **Create the App ID**: bundle ID `com.cpman.app` (must match `Info.plist`).
3. **Create signing certificates** in Xcode → Settings → Accounts → *Manage Certificates*:
   - **Apple Distribution** (signs the **app** embedded in the archive).
   - **Mac Installer Distribution** (signs the **`.pkg`** when exporting for App Store Connect — without this, `exportArchive` fails with *No signing certificate "Mac Installer Distribution" found*).
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

If Xcode reports **No profile matching …** (name or UUID):

1. In **developer.apple.com → Profiles**, confirm the type is **Mac App Store Connect** (distribution for the **Mac App Store**), **not** “Mac Development” and **not** “Developer ID”. It must list **App ID** `com.cpman.app` and your **Apple Distribution** certificate.
2. Download the `.provisionprofile`. **Do not double-click** (macOS opens System Settings, which rejects distribution profiles). **Drag the file onto the Xcode Dock icon** with Xcode running so it imports into  
   `~/Library/Developer/Xcode/UserData/Provisioning Profiles/`.
3. **`CPMAN_APPSTORE_PROVISIONING_PROFILE`** must be the profile **Name** exactly as in the portal, or its **UUID** (from the profile’s detail page — not the App ID).
4. **Xcode → Settings → Accounts**: sign in with the **same Apple ID** that owns the team; select the team → **Download Manual Profiles** if needed.
5. The release script passes **`-allowProvisioningUpdates`** so `xcodebuild` can pull a missing profile from Apple **if** you are signed into Xcode with that account (Step 4).

Verify a profile is installed and matches your team + bundle ID (replace `7d7dbd41-…` with your UUID):

```bash
PROFILE="$HOME/Library/Developer/Xcode/UserData/Provisioning Profiles/7d7dbd41-9cd9-4a9a-a637-94bec5457baa.mobileprovision"
security cms -D -i "$PROFILE" 2>/dev/null | plutil -extract TeamIdentifier raw -o - -
security cms -D -i "$PROFILE" 2>/dev/null | plutil -extract UUID raw -o - -
security cms -D -i "$PROFILE" 2>/dev/null | plutil -extract Entitlements.application-identifier raw -o - -
```

You should see team `6MXNY43D6S`, the same UUID, and `application-identifier` **`6MXNY43D6S.com.cpman.app`**. If `ls` says “No such file”, the profile never imported — repeat Step 2.

### If `exportArchive` fails: *No signing certificate "Mac Installer Distribution" found*

Archiving only signs the **app**. Exporting an App Store **`.pkg`** also requires a **Mac Installer Distribution** certificate in your keychain (separate from **Apple Distribution**).

1. Open [Certificates](https://developer.apple.com/account/resources/certificates/list) → **+** → **Software** → **Mac Installer Distribution**.
2. In **Keychain Access**: **Keychain Access** → Certificate Assistant → **Request a Certificate From a Certificate Authority…** — save a CSR, upload it on the portal, **download** the `.cer`, double‑click to install.
3. In **Keychain Access → login → My Certificates**, confirm **Mac Installer Distribution: … (TEAMID)** appears.
4. Re-run `./scripts/release-app-store-archive.sh`, or **export only** if the archive already exists:

   ```bash
   ./scripts/release-app-store-archive.sh --export-only
   ```

If export says **No certificate … matching 'Mac Installer Distribution'** but Keychain shows **3rd Party Mac Developer Installer** (legacy name for the same cert), `installerSigningCertificate` must use that **exact** string. The release script **auto-picks** the first installer line from `security find-identity`; override manually if needed:

```bash
export CPMAN_APPSTORE_INSTALLER_IDENTITY="3rd Party Mac Developer Installer: Leon Rubin (6MXNY43D6S)"
./scripts/release-app-store-archive.sh
```

### Build & export

```bash
./scripts/release-app-store-archive.sh
```

Full run produces `build/AppStore/cpMan.xcarchive` and `build/AppStore/Export/cpMan.pkg`.

**Export only** (after a successful archive — writes `ExportOptions.plist` for you):

```bash
./scripts/release-app-store-archive.sh --export-only
```

Requires the same `CPMAN_*` environment variables. Do **not** run bare `xcodebuild -exportArchive` unless you have already created `build/AppStore/ExportOptions.plist` (the script generates it).

### Upload

Open the archive in **Xcode → Organizer** and choose **Distribute App → App Store Connect**, or upload `cpMan.pkg` with **Transporter** / `xcrun altool`.

In **App Store Connect** for cpMan:

- Set **Version** to `1.0.0`, **Build** to whatever `CURRENT_PROJECT_VERSION` was used (`1` initially; bump for every new upload).
- Fill **App Privacy** (cpMan does not collect data — see `Documentation/AppStoreSubmission/privacy-labels.md`).
- **App Review Information → Notes**: paste the contents of `Documentation/AppStoreSubmission/review-notes.md`.
- **Screenshots**, description, support URL, privacy policy URL — all sourced from `Documentation/AppStoreSubmission/` (see `README.md` in that folder for the index).

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
- `NSAccessibilityUsageDescription` **absent** — the app does not request
  Accessibility, and the verifier fails the build if the key is reintroduced
  by accident.
- Menu-bar-only (`LSUIElement`)
- Gatekeeper acceptance (informational only)

A clean run prints `✅ All required checks passed.`.

---

## 5) Versioning policy

- **`MARKETING_VERSION`** (visible to users): bump on each release (`1.0.0` → `1.0.1`, `1.1.0`, ...).
- **`CURRENT_PROJECT_VERSION`** (build number): **strictly increases** for every binary uploaded to App Store Connect; the same version may have many builds.
- Both DMG and App Store builds for the same release should share the same `MARKETING_VERSION`.

To bump for the next release, edit those two values in `project.yml` and re-run `xcodegen generate`.

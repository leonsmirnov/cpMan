# App Store Connect — Text Metadata

All fields below are ready to paste verbatim into App Store Connect.
Character counts (including spaces) are shown after each value so you
can edit confidently. Apple's hard limits are noted in parentheses.

> Localization: English (U.S.) only for the first submission. Add
> additional locales later if needed — Apple does not require multiple
> locales.

---

## 1. App information (does not change per version)

| Field | Value |
|-------|-------|
| **Bundle ID** | `com.cpman.app` |
| **SKU** | `cpman-macos-1` (any unique string — never visible to users) |
| **Primary language** | English (U.S.) |
| **Primary category** | Productivity |
| **Secondary category** | Utilities |
| **Content rights** | "Does NOT contain, show, or access third-party content." |
| **Age rating** | 4+ (see `age-rating.md`) |

---

## 2. App name  *(limit: 30 chars)*

```
cpMan – Clipboard History
```
*(25 characters)*

> If "cpMan" alone is preferred, just use:
> ```
> cpMan
> ```
> *(5 characters)*

---

## 3. Subtitle  *(limit: 30 chars)*

```
Quick clipboard history
```
*(22 characters)*

Alternative options:

- `Menu-bar clipboard history` (26)
- `Clipboard history, on a key` (27)

---

## 4. Promotional text  *(limit: 170 chars; can be edited without a new review)*

```
A tiny menu-bar clipboard manager. Press ⌃⌥V to bring back the last 100 things you copied. No accounts, no network, no permissions — your clipboard stays on your Mac.
```
*(168 characters)*

---

## 5. Description  *(limit: 4000 chars)*

```
cpMan is a minimal clipboard history for macOS. It lives in your menu bar, remembers the last 100 things you copied, and brings any of them back with a single keystroke.

Press ⌃⌥V (or your own shortcut) and a small picker opens right where you're working. Type to filter, press Return to copy the selected item back to the clipboard, then paste with ⌘V as usual. That's the whole app.

WHAT IT DOES
• Watches the system clipboard for text you copy.
• Keeps the most recent 100 text clips on disk, inside the app's sandbox.
• Opens a fast floating picker from anywhere via a global hotkey.
• Filter the list as you type. Press Return to copy. Press Space to preview a long clip. Press 1–9 to grab one of the top items instantly.
• Delete any item from the list with a single keystroke.

WHAT IT DOESN'T DO
• No accounts. No sign-in. No subscription.
• No network access of any kind. Nothing leaves your Mac.
• No analytics, no telemetry, no crash reporters.
• No Accessibility, Full Disk Access, Screen Recording, or other special permissions. cpMan only uses the standard clipboard APIs that every Mac app has access to.
• No images, files, or rich-text in history — plain text only, on purpose.

DESIGNED TO STAY OUT OF YOUR WAY
cpMan does not show a Dock icon and does not appear in ⌘Tab. The menu-bar icon and the floating picker are the entire interface. If you don't press the shortcut, you'll never see it.

If you have an active password field (Secure Event Input), cpMan automatically pauses recording so passwords are never captured.

PRIVACY
Everything cpMan reads from your clipboard stays in its own sandbox container on your Mac. There is no cloud, no sync, no server. You can confirm this by checking Activity Monitor — cpMan does not open any network connection because it has no networking entitlement at all.

REQUIREMENTS
• macOS 14 (Sonoma) or later.
• Apple silicon or Intel.

THE NAME
"cpMan" is short for "copy manager" — small enough to fit in your muscle memory next to ⌘C and ⌘V.
```
*(2,025 characters)*

---

## 6. Keywords  *(limit: 100 chars, comma-separated, no spaces after commas)*

```
clipboard,history,paste,copy,manager,menubar,productivity,utility,snippet,text,hotkey,workflow
```
*(94 characters)*

Notes:
- Do NOT repeat words already in the **app name** or **subtitle**;
  Apple indexes those automatically. "Clipboard" and "history" are
  duplicated here defensively in case you trim the name later.
- Avoid competitor names — that is a frequent rejection reason.

---

## 7. URLs

| Field | Required? | What to enter |
|-------|-----------|---------------|
| **Support URL** | Required | Public URL hosting [`support.md`](./support.md). |
| **Privacy Policy URL** | Required | Public URL hosting [`privacy-policy.md`](./privacy-policy.md). |
| **Marketing URL** | Optional | Same as Support URL is fine, or leave blank. |

Suggested hosting: enable GitHub Pages on this repository and serve
both pages from `https://<your-github-user>.github.io/cpman/` (or any
domain you control). Apple does not require the URLs to be on your own
domain, only that they are publicly reachable, working at submission
time, and that the privacy policy actually describes the app.

---

## 8. Copyright

```
© 2026 <Your Name or Legal Entity>
```

Use the same string in `Info.plist → NSHumanReadableCopyright`
(currently `Copyright © 2026. All rights reserved.` — edit before
shipping if you want your name there).

---

## 9. Pricing & availability

- **Price:** Free (no IAP).
- **Availability:** All territories (default).
- **Pre-orders:** off.
- **Volume Purchase Program:** off (no business use case yet).

---

## 10. Version information (per submission)

| Field | Value for 1.0.0 |
|-------|------------------|
| **Version** | `1.0.0` |
| **Build** | `1` (or whatever `CURRENT_PROJECT_VERSION` was in the uploaded build) |
| **What's New in This Version** | First public release. (Required only on updates — for 1.0.0 leave blank or write "Initial release.") |
| **Release option** | "Automatically release this version" is fine. Choose "Manually release" if you want to coordinate a launch. |

---

## 11. App Review Information

| Field | Value |
|-------|-------|
| **Sign-in required** | No |
| **Contact: first name** | *(your first name)* |
| **Contact: last name** | *(your last name)* |
| **Phone** | *(your phone, including country code)* |
| **Email** | *(an inbox you actually monitor; reviewers reply here)* |
| **Notes** | Paste the contents of [`review-notes.md`](./review-notes.md). |
| **Attachment** | Optional. A 20–40s screen recording shortens review. See `screenshots.md` → "Optional review video". |

---

## 12. Encryption export compliance

In **App Store Connect → App Information → Encryption**, answer:

> *Does your app use encryption?* — **No**

This matches the `ITSAppUsesNonExemptEncryption = false` key we just
added to `Info.plist`, so on every build you upload after this, App
Store Connect will skip the questionnaire automatically.

Details and Apple's reference language live in
[`encryption-compliance.md`](./encryption-compliance.md).

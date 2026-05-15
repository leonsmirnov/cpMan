# Reviewer FAQ — anticipated App Review questions

The questions below are the ones clipboard managers, menu-bar apps, and
"no permissions / no network" apps typically receive from App Review.
The answers are factual and reflect the current source tree on the
`basic_version` branch. Use them as canned replies in App Store Connect
Resolution Center, or fold the most likely ones into the **Review
Notes** so the reviewer never has to ask.

---

### Q1. "We can't find your app after installing it. There is no Dock icon."

cpMan is a menu-bar utility and intentionally has no Dock icon
(`LSUIElement = YES` in `Info.plist`). After launch, look for the
clipboard icon in the menu bar (top-right area). If the menu bar is
crowded, click the `»` chevron to reveal hidden icons. The only other
UI surface is the floating picker, which is opened with the global
shortcut **⌃⌥V** (Control-Option-V).

### Q2. "Where is the main functionality of the app?"

Two surfaces, both reachable without any system permission:

1. Menu-bar icon → click → opens **Settings…**, **Open cpMan** (the
   picker), and **Quit cpMan**.
2. Press **⌃⌥V** anywhere in macOS → the picker appears centered on
   screen, showing the most recent clips. Arrow keys + Return selects
   one; the text is placed on the clipboard and the picker closes.

### Q3. "What permissions does the app request? We did not see any system prompts."

That is correct — cpMan does not request any permission:

- No Accessibility.
- No Full Disk Access.
- No Screen Recording / Input Monitoring.
- No Camera, Microphone, Contacts, Calendars, Reminders, Photos.
- No Apple Events / "Automation" prompts.
- No network entitlement at all.

The only system facilities used are `NSPasteboard` (sandbox-default
access), `UserDefaults`, and the public Carbon API
`IsSecureEventInputEnabled()`, none of which require user consent.

### Q4. "Why does the app run in the background?"

cpMan needs to notice when the user copies new text. It does this by
polling `NSPasteboard.general.changeCount` on the main run loop at a
low cadence. When the change count has not advanced no work happens.
There is no `LaunchAgent`, `LaunchDaemon`, XPC service, helper tool,
or login-item helper. The app process is the only process cpMan owns.

### Q5. "Does the app collect, transmit, or share user data?"

No. cpMan has no networking entitlement, so the sandbox prevents any
network request even if the code attempted one. There is no analytics
SDK, crash reporter, or telemetry. All clipboard content stays inside
the app's own sandbox container at:

```
~/Library/Containers/com.cpman.app/Data/Library/Application Support/cpMan/history.json
```

In **App Store Connect → App Privacy**, every "Data Collected" toggle
is left **off** — "Data Not Collected".

### Q6. "Does the app read passwords from the clipboard?"

No. cpMan calls `IsSecureEventInputEnabled()` before recording each new
clipboard change. While macOS reports that Secure Event Input is on
(typically because a password field is focused), cpMan does not record
the pasteboard at all.

### Q7. "Does the app use the Accessibility APIs (`AXIsProcessTrustedWithOptions`, `AXUIElement*`, posting key events with `CGEvent.post`)?"

No. The source tree on this branch contains no calls to any of those
APIs and no Accessibility usage description in `Info.plist`. When the
user selects an entry in the picker, cpMan writes the text back to the
clipboard with `NSPasteboard`; the user presses ⌘V themselves. That is
why no Accessibility permission is needed and none is requested.

(If the reviewer wants to confirm: `grep -R "AXIsProcessTrusted\|CGEvent.post\|kAXTrustedCheck" Sources` returns no matches.)

### Q8. "Does the app modify other applications or system files?"

No. cpMan does not write to disk anywhere except its own sandbox
container. It does not send Apple Events, it does not control other
apps, and it does not install anywhere outside `/Applications`.

### Q9. "What third-party code is bundled?"

One open-source Swift package:

| Name | Author | License | Use |
|------|--------|---------|-----|
| KeyboardShortcuts | sindresorhus | MIT | Recording/persisting the user's global hotkey. Reads/writes `UserDefaults` only. |

No analytics, no crash reporter, no advertising SDK, no networking
library.

### Q10. "Is the app universal? What versions of macOS does it support?"

The app is universal (arm64 + x86_64) and supports macOS 14 (Sonoma)
and later, as declared by `LSMinimumSystemVersion = 14.0` and
`MACOSX_DEPLOYMENT_TARGET = 14.0`.

### Q11. "We received a warning about a missing privacy manifest."

`Sources/cpMan/Resources/PrivacyInfo.xcprivacy` is bundled. It declares
a single Required Reason API: `NSPrivacyAccessedAPICategoryUserDefaults`
with reason `CA92.1` (used by the KeyboardShortcuts package to persist
the hotkey). No tracking, no tracking domains, no other API categories.

### Q12. "We received an export-compliance question on upload."

`Info.plist` sets:

```xml
<key>ITSAppUsesNonExemptEncryption</key>
<false/>
```

After this is in a build, the encryption questionnaire is auto-answered
on every upload. See `encryption-compliance.md` for the wording App
Review usually expects if the reviewer follows up anyway.

### Q13. "Is there a free tier / paid tier? In-app purchases?"

No. cpMan is free. There are no in-app purchases or subscriptions.
There is no account, no sign-in, and no server side at all.

### Q14. "Can you provide a demo video?"

Optional but useful — a 20–40 second screen recording showing the menu
bar icon, the global shortcut opening the picker, selecting a row, and
pasting into another app shortens review. See `screenshots.md` →
"Optional review video".

### Q15. "The app does not appear to do anything on first launch."

That is expected and documented in the review notes: cpMan is silent
until the user copies text or presses the global shortcut. The
suggested test flow in `review-notes.md` walks through the minimal
30-second test that exercises every feature.

# Reviewer Notes — paste into App Store Connect

Paste the section below into **App Store Connect → App Review
Information → Notes**. Trim or expand contact details as you like, but
keep the structure — it answers the questions reviewers usually ask
about menu-bar clipboard apps before they have to ask them.

---

```
Thank you for reviewing cpMan.

1. WHAT THIS APP IS
   cpMan is a minimal menu-bar clipboard manager for macOS. It remembers
   the most recent plain-text clips (hard cap of 100) and lets the user
   bring any of them back via a small floating picker.

   • Plain-text only — image / file / rich-text pasteboard payloads are
     ignored.
   • History lives as a JSON file inside the app's sandbox container.
   • No accounts, no analytics, no networking. Nothing leaves the device.

2. HOW TO LAUNCH AND FIND THE UI
   cpMan uses LSUIElement = YES: it does NOT show a Dock icon and does
   NOT appear in ⌘Tab. That is intentional for a menu-bar utility.

   After launch, look for the clipboard icon in the menu bar (top-right
   area of the screen). If the menu bar is crowded, click the chevron
   "»" to reveal hidden icons.

   Open the picker with the default global shortcut:

       Control + Option + V   (⌃⌥V)

   The shortcut can be changed in cpMan → Settings… → Shortcut.

3. SUGGESTED 30-SECOND TEST FLOW
   a) Launch cpMan → confirm clipboard icon in the menu bar; no Dock
      icon, not in ⌘Tab.
   b) Press ⌃⌥V → the picker appears.
   c) In Safari or Notes, copy any text → it appears at the top of the
      picker the next time you open it.
   d) Select a row → picker closes; ⌘V pastes that text into the app
      that was active before the picker opened.
   e) In Finder, copy a file → it does NOT appear in cpMan (cpMan only
      records text on purpose).
   f) Open Settings → record a new shortcut → confirm it works.

4. PERMISSIONS — NONE
   cpMan does not request Accessibility, Full Disk Access, Screen
   Recording, Camera, Microphone, Contacts, Calendars, Reminders,
   Photos, or any other restricted permission. There is no TCC prompt
   anywhere in the app.

   • Clipboard is read via standard NSPasteboard APIs (allowed in the
     sandbox by default).
   • When the user selects an item in the picker, cpMan writes the text
     back to NSPasteboard. No synthetic key events are generated and no
     other application is controlled, so the Accessibility entitlement
     is not needed.

5. SECURE INPUT
   While macOS reports Secure Event Input is active (e.g. a password
   field is focused), cpMan pauses recording. The check uses the public
   Carbon API `IsSecureEventInputEnabled()`, which requires no
   entitlement.

6. PRIVACY / DATA HANDLING
   • Data collected: NONE. Privacy nutrition labels are set to
     "Data Not Collected".
   • No network entitlement at all (com.apple.security.network.client
     and .network.server are both absent from the entitlements file).
     Reviewers can verify in Activity Monitor → Network that cpMan
     never opens a connection.
   • Privacy Manifest (PrivacyInfo.xcprivacy) declares a single API
     usage: NSPrivacyAccessedAPICategoryUserDefaults, reason CA92.1,
     used by the bundled KeyboardShortcuts package to persist the
     user's hotkey.
   • No third-party SDKs other than the open-source Swift package
     KeyboardShortcuts (sindresorhus/KeyboardShortcuts, MIT).

7. BACKGROUND BEHAVIOR
   cpMan polls NSPasteboard.changeCount on the main run loop at a low
   cadence. When the changeCount has not advanced, no allocation or I/O
   happens. There is no LaunchAgent, no LaunchDaemon, no XPC service,
   no helper tool, and no login item.

8. ENCRYPTION
   cpMan uses no encryption beyond what macOS itself provides. The
   Info.plist sets ITSAppUsesNonExemptEncryption = false, so the
   encryption questionnaire is skipped automatically on upload.

9. ACCOUNTS / IAP
   No accounts, no sign-in, no in-app purchases, no subscriptions.

10. CONTACT
    Name:    <Your Name>
    Email:   <Your Email>
    Phone:   <Your Phone>
    Bundle:  com.cpman.app

If anything fails during review, we can supply a short screen recording
or adjust the notes. The app contains no hidden features — what you see
is everything.
```

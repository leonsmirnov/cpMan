# Reviewer Notes — paste into App Store Connect

Paste the section below into **App Store Connect → App Review Information → Notes**.

---

```
Thank you for reviewing cpMan.

DEMO MODE — START HERE (required before testing the picker)
cpMan ships with an empty history for customers. For review, load fictional
sample clips using ONE of the options below.

OPTION A — Terminal (recommended; copy/paste as one line):
   killall cpMan 2>/dev/null; open -b com.cpman.app --args -CPManDemoMode

OPTION B — Menu bar fallback:
   Launch cpMan → click the clipboard icon in the menu bar → "Load Demo Content"

After either option, press Control + Option + V (⌃⌥V) to open the picker.
You should see 15 sample clips (not an empty list) and a "Sample clips" banner.

Suggested test flow:
1. Run Option A or B above.
2. Press ⌃⌥V → picker with sample clips.
3. Type "meeting" or "git" in search → filtered results.
4. Return on a row → text on clipboard; paste with ⌘V.
5. Space → preview long clip in TextEdit.
6. Delete → remove selected row.
7. Menu bar → Settings… → Demo content section (clear/reload) and Shortcut.

Alternate env-var launch (if Terminal is preferred without --args):
   killall cpMan 2>/dev/null; CPMAN_DEMO_MODE=1 /Applications/cpMan.app/Contents/MacOS/cpMan &

WHAT THIS APP IS
cpMan is a minimal menu-bar clipboard manager. Plain-text history (max 100),
stored on the Mac only. No accounts, no network, no special permissions.

UI LOCATION
cpMan uses LSUIElement: no Dock icon, not in ⌘Tab. Look for the clipboard icon
in the menu bar (use the » chevron if the bar is crowded).

PERMISSIONS — NONE
No Accessibility, Full Disk Access, Screen Recording, or TCC prompts.

PRIVACY
Data Not Collected. No network entitlement.

SUPPORT URL
https://leonsmirnov.github.io/cpMan/support/
Contact: leon.smirnov1986@gmail.com

CONTACT FOR REVIEW
Name:  Leon Smirnov
Email: leon.smirnov1986@gmail.com
Phone: [your phone with country code]
Bundle: com.cpman.app
```

# Reviewer Notes — paste into App Store Connect

---

```
Thank you for reviewing cpMan.

DEMO MODE — START HERE (required before testing the picker)
cpMan ships with an empty history for customers. For review, load fictional
sample clips using Terminal:

   killall cpMan 2>/dev/null; open -n -a "/Applications/cpMan.app" --args -CPManDemoMode

Then press Control + Option + V (⌃⌥V) to open the picker with 15 sample clips.
If cpMan was already running, you must quit it first (or the command above does killall).

Alternate (most reliable):
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

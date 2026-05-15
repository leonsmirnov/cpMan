# cpMan Support

cpMan is a minimal menu-bar clipboard manager for macOS. This page
covers the most common questions; if it does not answer yours, send a
note to *(your support email)* and we'll get back to you.

## Getting started

1. Install cpMan from the Mac App Store (or open the DMG and drag
   cpMan into `/Applications`).
2. Launch it. A small clipboard icon appears in the menu bar.
   - cpMan does **not** show a Dock icon or appear in ⌘Tab. That is by
     design — it's meant to stay out of the way.
   - If your menu bar is crowded, click the chevron `»` to reveal
     hidden icons.
3. Copy some text in any app.
4. Press **⌃⌥V** (Control-Option-V) to open the picker.
5. Select a row with the arrow keys and press **Return**. The text is
   placed on the clipboard; paste with **⌘V** as usual.

## Keyboard shortcuts inside the picker

| Action | Shortcut |
|--------|----------|
| Move selection | ↑ / ↓ |
| Copy selected entry & close picker | Return |
| Quick-pick top 1–9 | `1`…`9` |
| Preview long entry | Space |
| Delete the selected entry | Delete |
| Dismiss the picker | Esc |

## Changing the global hotkey

Open the menu-bar icon → **Settings…** → **Shortcut** and record a new
combination. Anything macOS allows as a global hotkey works.

## What gets recorded

- Plain text only. Images, files, and rich text are ignored.
- The most recent **100** entries are kept on disk. Older entries are
  discarded automatically.
- While a password field is active (macOS reports "Secure Event Input"
  is on) cpMan pauses recording.

## Privacy

cpMan does not have any networking entitlement, so it cannot send data
anywhere. Everything stays inside the app's sandbox container on your
Mac. See the [Privacy Policy](./privacy-policy.md) for full details.

## Removing all data

Quit cpMan, then delete:

```
~/Library/Containers/com.cpman.app
```

That removes both the history file and the saved hotkey.

## Troubleshooting

**The menu-bar icon doesn't appear.** Make sure cpMan is running
(Launchpad → cpMan). If the menu bar is full, the icon may be hidden
behind the `»` chevron, or hidden by Bartender / Hidden Bar etc.

**The hotkey does nothing.** Another app is probably using the same
combination. Open Settings and record a different shortcut.

**A copy did not appear in the history.**
- It might be non-text (an image, a file). cpMan only records text.
- A password field was probably focused. Re-copy with a different field
  focused and the entry will appear.

**I want to clear everything.** Use the Delete key inside the picker to
remove one entry at a time, or delete the sandbox container as shown
above to wipe everything.

## Contact

Email *(your support email)* with:

- macOS version (Apple menu → About This Mac).
- cpMan version (menu-bar icon → Settings… → About).
- A short description of what happened, what you expected, and what
  you saw instead.

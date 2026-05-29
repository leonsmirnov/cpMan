---
title: cpMan Support
layout: default
permalink: /support/
---

# cpMan Support

cpMan is a menu-bar clipboard manager for macOS. This page answers common
questions and explains how to contact us.

## Contact support

**Email:** [leon.smirnov1986@gmail.com](mailto:leon.smirnov1986@gmail.com)

We read every message. Include your macOS version (Apple menu → About This Mac),
cpMan version (menu-bar icon → Settings → About), and a short description of
what happened.

Typical response time: within a few business days.

## Getting started

1. Install cpMan from the Mac App Store.
2. Launch the app. A clipboard icon appears in the menu bar.
   - cpMan does **not** show a Dock icon or appear in ⌘Tab.
   - If the menu bar is crowded, click the **»** chevron to reveal hidden icons.
3. Copy text in any app. Press **⌃⌥V** (Control-Option-V) to open the picker,
   or choose **Open cpMan** from the menu-bar menu.
4. Select a row and press **Return**. The text is copied to the clipboard;
   paste with **⌘V** in any app.

## Keyboard shortcuts in the picker

| Action | Shortcut |
|--------|----------|
| Move selection | ↑ / ↓ |
| Copy selected entry and close | Return |
| Quick-pick top 1–9 | `1`…`9` |
| Preview a long clip | Space |
| Delete selected entry | Delete |
| Dismiss picker | Esc |

## Changing the global hotkey

Menu-bar icon → **Settings…** → **Shortcut**. Record any combination macOS
allows as a global hotkey.

## What gets recorded

- Plain text only. Images, files, and rich text are ignored.
- Up to **100** recent entries, stored on your Mac inside the app sandbox.
- Recording pauses while a password field is active (Secure Event Input).

## Privacy

cpMan has no network entitlement. Clipboard history never leaves your Mac.
See the [Privacy Policy](../privacy/) for details.

## Removing all data

Quit cpMan, then delete:

```
~/Library/Containers/com.cpman.app
```

That removes history, preferences, and the saved hotkey.

## Troubleshooting

**Menu-bar icon missing.** Confirm cpMan is running. Check the **»** overflow
menu or menu-bar tools such as Bartender.

**Hotkey does nothing.** Another app may use the same shortcut. Pick a different
one in Settings.

**A copy did not appear.** Non-text copies are ignored. Password fields pause
recording; copy again from a normal text field.

**Need more help?** Email [leon.smirnov1986@gmail.com](mailto:leon.smirnov1986@gmail.com).

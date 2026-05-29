# cpMan Support

cpMan is a menu-bar clipboard manager for macOS. This page answers common
questions and explains how to contact us.

## Contact support

**Email:** leon.smirnov1986@gmail.com

We read every message. Include your macOS version (Apple menu → About This Mac),
cpMan version (menu-bar icon → Settings → About), and a short description of
what happened.

Typical response time: within a few business days.

## Getting started

1. Install cpMan from the Mac App Store.
2. Launch the app. A clipboard icon appears in the menu bar.
   - cpMan does **not** show a Dock icon or appear in ⌘Tab.
   - If the menu bar is crowded, click the **»** chevron to reveal hidden icons.
3. On first launch, sample clips load automatically so you can try the app
   immediately. You can clear them in **Settings → Demo content**.
4. Press **⌃⌥V** (Control-Option-V) to open the picker, or choose **Open cpMan**
   from the menu-bar menu.
5. Select a row and press **Return**. The text is copied to the clipboard;
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

## Demo content

For App Review, load samples via Terminal or the menu (not automatic for customers):

```bash
killall cpMan 2>/dev/null; open -b com.cpman.app --args -CPManDemoMode
```

Menu bar → **Load Demo Content** is the UI fallback.

## Privacy

See [privacy-policy.md](./privacy-policy.md). cpMan has no network access;
data stays on the Mac.

## Contact

Email leon.smirnov1986@gmail.com with macOS version, cpMan version, and steps
to reproduce any issue.

**Support URL for App Store Connect:** `https://leonsmirnov.github.io/cpMan/support/`

Do **not** use a raw GitHub `.md` file URL. Apple requires a rendered webpage.

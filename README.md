# cpMan — Clipboard Manager for macOS

A tiny, fast clipboard manager that lives in your menu bar. cpMan remembers
the last 100 things you copied as plain text and lets you bring any of them
back with a single keyboard shortcut.

---

## Features

- **Recent-text history** — captures every plain-text copy automatically; up
  to the last 100 items, newest first
- **Instant search** — type to filter history in real time
- **Keyboard navigation** — `↑` / `↓` to move, `Return` to copy the selected
  item, `Esc` to dismiss
- **Quick select** — press `1`–`9` to immediately copy one of the first nine
  items
- **Open Preview** — press `Space` (or right-click → Open Preview) to view
  the full item in TextEdit
- **Delete items** — right-click any row → Delete
- **Customisable hotkey** — change the global shortcut from
  **Settings → Shortcut**

---

## Requirements

- macOS 14 (Sonoma) or later
- Apple Silicon or Intel Mac

---

## Installation

1. Download `cpMan` from the Mac App Store (or `cpMan.dmg` from
   [Releases](../../releases) if you want the direct-DMG channel).
2. App Store: it installs to `/Applications` automatically. DMG: drag
   **cpMan.app** into **/Applications**.
3. Launch cpMan from Applications or Spotlight (`⌘Space` → type `cpMan`).
4. cpMan appears as a clipboard icon in your menu bar. There is no Dock
   icon and no `⌘Tab` entry by design (it's a menu-bar agent).

---

## Permissions

**cpMan requires no special permission.** No Accessibility, no Full Disk
Access, no Screen Recording, no network access. The clipboard is read via
standard `NSPasteboard` APIs that are allowed inside the App Sandbox.

When you pick a clipboard item from the picker, cpMan copies its text back
to the system clipboard and closes the panel — you then paste with **`⌘V`**
yourself, exactly as you would after any normal copy.

---

## Usage

### Opening the picker

Press the global hotkey (default **`⌃⌥V`**) from any app. The picker appears
in the centre of the screen.

### Selecting an item

| Action | Result |
|---|---|
| **Click** an item | Copies it to the clipboard and closes the picker |
| **`↑` / `↓`** arrow keys | Move the highlight up / down |
| **`Return`** | Copies the highlighted item |
| **`1`–`9`** | Copies the item at that position |
| **`Space`** | Open the highlighted item in TextEdit |
| **`Esc`** | Close the picker without copying |
| **Type anything** | Filter history by text content |

After the picker closes, switch back to the app you were typing in and
press **`⌘V`** to paste.

### Right-click menu

| Option | Effect |
|---|---|
| **Copy** | Same as Return — copies the row to the clipboard |
| **Open Preview** | Writes the text to a temporary file and opens it in TextEdit |
| **Delete** | Removes the row from history |

---

## Configuring the hotkey

1. Open the menu-bar icon → **Settings…**
2. Click the recorder next to **Open picker** and press your desired
   key combination.
3. The new hotkey takes effect immediately.

---

## Where the history lives

cpMan stores its 100-item history as a single JSON file inside its sandbox
container:

```
~/Library/Containers/com.cpman.app/Data/Library/Application Support/cpMan/history.json
```

Nothing leaves the device. No analytics, no telemetry, no network calls.

---

## License

MIT License — Copyright © 2026

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to
deal in the Software without restriction, including without limitation the
rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
sell copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
IN THE SOFTWARE.

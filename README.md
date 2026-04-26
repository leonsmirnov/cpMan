# cpMan — Clipboard Manager for macOS

A fast, lightweight clipboard manager that lives in your menu bar. cpMan keeps a searchable history of everything you copy — text and images — and lets you paste any item instantly with a keyboard shortcut.

---

## Screenshots

> _Screenshots coming soon_

---

## Features

- **Clipboard history** — automatically captures text and images as you copy; the picker list updates live while it is open (no need to close and reopen)
- **Instant search** — type to filter history in real time
- **Auto-paste** — select an item and it pastes directly into whatever app you were using
- **Paste as plain text** — strips formatting; press ⌥Return or right-click any text item
- **Keyboard navigation** — arrow keys to move, Enter to paste, Escape to close
- **Quick select** — press 1–9 to instantly paste one of the first nine items
- **Inline preview** — click the chevron on any row to expand full text or a larger image
- **System viewer** — press Space to open the selected item in Preview.app or TextEdit
- **Edit history items** — right-click any text item to edit it; saves as a new entry
- **Delete items** — right-click any item to delete it from history
- **Clear all history** — wipe everything at once from Settings
- **Private mode** — pause clipboard capture from the menu bar; choose a duration (15 min, 30 min, 1 h, 2 h, or indefinite) and the icon changes to a lock so you always know it's active
- **Image support** — captures screenshots and images with thumbnail previews
- **OCR** — automatically extracts text from images so you can search their content
- **Paste as File** — right-click an image to paste it as a `.png` file (useful in Finder, Mail, Slack)
- **Ignore list** — exclude specific apps from being captured (e.g. password managers)
- **History limits** — configure max item count, total image size, and item age independently
- **Customisable hotkey** — change the global shortcut to whatever you prefer

---

## Requirements

- macOS 14 (Sonoma) or later
- Apple Silicon or Intel Mac

---

## Installation

1. Download the latest `cpMan.dmg` from the [Releases](../../releases) page
2. Open the DMG and drag **cpMan.app** into your **Applications** folder
3. Launch cpMan from Applications or Spotlight (`⌘Space` → type `cpMan`)
4. cpMan appears as a clipboard icon in your menu bar

---

## Permissions

cpMan requires one permission to work fully.

### Accessibility (required for auto-paste)

Auto-paste works by simulating `⌘V` into the app you were using before opening the picker. macOS requires Accessibility access for any app that synthesises key presses.

**How to grant it:**

1. Open the cpMan picker (`⌃⌥V`) — an orange banner appears at the top
2. Click **"Open Settings"** in the banner — System Settings opens at the Accessibility pane
3. **If cpMan is in the list** → toggle it **ON**
4. **If cpMan is not in the list** → click **`+`**. The picker usually starts in the **system** Applications folder (`/Applications`). If you installed from the DMG or install script, cpMan is often under **your user** Applications folder instead: in the open sheet press **`⌘⇧G`** (Go to Folder), enter **`~/Applications`**, press Return, select **cpMan.app**, then **Open**. If you dragged the app to the main Applications folder, look under **`/Applications`**.
5. Switch back to cpMan — the banner disappears automatically once access is detected

> You can also go through these steps any time via **Settings → General → Accessibility Permission → Open Settings…**

**Without Accessibility:** cpMan still works — the selected item is written to the clipboard and you can paste manually with `⌘V`.

---

## Usage

### Opening the picker

Press the global hotkey (default **`⌃⌥V`**) from any app. The clipboard history picker appears in the centre of your screen.

### Selecting an item

| Action | Result |
|---|---|
| **Click** an item | Pastes it immediately |
| **↑ / ↓ arrow keys** | Move selection up / down |
| **Enter** | Paste selected item |
| **1 – 9** | Instantly paste item at that position |
| **Escape** | Close picker without pasting |
| **Type anything** | Filter history by text |

While the picker is open, new copies still appear in the list within about half a second. Your keyboard selection stays on the same row (same item) when possible, so the highlight does not jump to the top every time something new is captured.

### Right-click menu

Right-clicking any item shows additional options:

| Option | Available on |
|---|---|
| Paste | All items |
| Paste as Plain Text | Text items |
| Edit | Text items |
| Paste as File | Images |
| Paste OCR Text | Images with detected text |
| Open Preview | All items |
| Delete | All items |

### Private mode

Click the cpMan icon in the menu bar and choose **Enable Private Mode**. A sub-menu lets you pick how long private mode stays on:

| Duration | Behaviour |
|---|---|
| 15 / 30 minutes | Automatically resumes after the chosen time |
| 1 hour / 2 hours | Automatically resumes after the chosen time |
| Until I Turn It Off | Stays active until you choose **Disable Private Mode** |

The menu bar icon changes to a filled lock (``) while private mode is active. Your last-used duration is remembered and pre-selected next time.

---

## Configuring the Hotkey

1. Open **cpMan → Settings → Hotkeys**
2. Click the hotkey field and press your desired key combination
3. The new hotkey takes effect immediately

---

## History Management

Open **cpMan → Settings → History** to configure:

| Setting | Description |
|---|---|
| **Max items** | Maximum number of items to keep (`0` = no limit) |
| **Size limit** | Maximum total size of stored images in MB (`0` = no limit) |
| **Age limit** | Toggle on, then set the number of days after which items are pruned |
| **Clear All History** | Permanently delete all history items and images |

Items are pruned automatically when new content is captured.

---

## Ignore List

Some apps (e.g. password managers) should never have their content saved to clipboard history.

**To add an app to the ignore list:**
1. Open **Settings → Ignore List**
2. Click **+** and select the app, or type its Bundle ID directly

When an ignored app is in the foreground, cpMan skips all clipboard captures.

---

## Image Settings

Open **Settings → Images** to configure:

- **Max resolution** — images larger than this are downscaled before saving
- **Max file size** — images exceeding this size are discarded
- **OCR** — toggle automatic text extraction from images on or off

---

## License

MIT License — Copyright © 2026

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

# Screenshots & optional review video

App Store Connect requires **at least one** screenshot for macOS. We
recommend **four**, in the order below — that's the sweet spot for
reviewers and store browsers without making yourself maintain a
gallery.

## Required size

Use one of these resolutions (Apple accepts any of them; 2880×1800 is
the safest because it covers every current MacBook display at 1×).

| Source display | Pixel size | DPI |
|----------------|------------|-----|
| Retina MacBook Pro 16" | **2880 × 1800** | 144 |
| Retina MacBook Pro 14" | 3024 × 1964 | 144 |
| Studio Display / iMac | 2560 × 1600 | 144 |
| Compatibility fallback | 1280 × 800 | 72 |

All screenshots in a submission should share the same aspect ratio
(16:10 above). Mixing aspect ratios is allowed but looks inconsistent.

## How to capture

1. Build the Release binary (`scripts/build-release-dmg-and-install.sh`)
   and install it to `/Applications`.
2. Set the desktop wallpaper to a neutral solid color (Apple
   recommends a dark grey or system default — busy wallpapers are a
   frequent rejection reason).
3. Run cpMan, then on a 2880×1800-capable display take screenshots
   with **⌘⇧4 → Space → click the window** (or `screencapture -w` from
   Terminal). For full-screen shots use **⌘⇧3**.

## Screenshot plan

| # | Scene | Caption (≤ 30 words) |
|---|-------|----------------------|
| 1 | Full screen. The menu-bar icon at the top right is highlighted (a red circle drawn in Preview is fine). The desktop is otherwise empty. | "Lives in your menu bar. No Dock icon, no clutter." |
| 2 | The picker (⌃⌥V) open over a Safari window. The list shows ~6 recent text clips with realistic but neutral content (no personal info, no third-party logos). The search field is empty. | "Press ⌃⌥V from anywhere to bring back the last 100 things you copied." |
| 3 | The picker open with the user typing a few characters in the search field, list filtered. | "Type to filter. Return copies. ⌘V pastes." |
| 4 | The Settings window showing the Shortcut recorder + version. | "One setting: the shortcut. That's it." |

Optional 5th if you want store-page polish:

| 5 | A side-by-side composition of the menu-bar icon (zoomed) + the picker. | "Plain text only. No accounts, no network, no permissions." |

## Captions & overlays

Captions are baked into the screenshot image — Apple does not provide
a separate caption field for macOS screenshots. Keep overlays small,
high-contrast, and in the same typeface as the OS (San Francisco) if
you add any.

## Optional review video

Reviewers explicitly accept a short video as an attachment under
**App Review Information → Attachment** (PNG, JPG, MP4, MOV, ZIP).
A 20–40 second QuickTime recording is enough:

1. Show the desktop with no cpMan UI visible.
2. Click the menu-bar icon → close the menu.
3. Copy two or three different strings from Safari / Notes.
4. Press ⌃⌥V → picker appears.
5. Use arrow keys to select one; press Return.
6. Switch to TextEdit, press ⌘V — text appears.
7. Optionally: copy a file from Finder, open the picker, show that the
   file is NOT recorded.

Compress to <50 MB before uploading (QuickTime → File → Export As →
1080p is fine).

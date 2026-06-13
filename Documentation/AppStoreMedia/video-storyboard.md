# App Preview video storyboard (~25 seconds)

**Target**: 1920 x 1080 landscape, H.264 `.mp4`, 15–30 sec.  
**Rule**: Real in-app UI only — no fake mockups in the video itself.

## Before recording

1. Run `./scripts/record-app-preview.sh` (launches demo mode).
2. Clean desktop, hide notifications (Focus mode).
3. Open **Notes** or **TextEdit** as the "paste target" app.
4. QuickTime → **File → New Screen Recording** → record **selected portion** (center of screen) or full screen.

## Timeline

| Time | Action | On screen |
|------|--------|-----------|
| 0:00–0:03 | Hold on menu bar | cpMan icon visible in menu bar. Optional: fade in from black. |
| 0:03–0:06 | Press **⌃⌥V** | Picker opens with demo clips. |
| 0:06–0:10 | Type `roadmap` in search | List filters to standup notes. |
| 0:10–0:13 | Arrow down to image row, Space to preview | Image + OCR content visible. |
| 0:13–0:17 | Return on a text clip | Picker closes; clip pastes into Notes (auto-paste on, or manual ⌘V). |
| 0:17–0:20 | Click menu bar icon → Private Mode → 30 Minutes | Menu shows private mode options. |
| 0:20–0:23 | Open Settings → History tab | Limits UI visible. |
| 0:23–0:25 | Picker closed, menu bar only | End card feel — optional text overlay in iMovie: "cpMan — copy manager for Mac". |

## Audio

- **Muted** is fine (App Store autoplays muted).
- If you add music, use royalty-free only; no voice-over required.

## Export

1. Trim in QuickTime: **Edit → Trim** to 25 sec.
2. Export: **File → Export As → 1080p**.
3. Or with ffmpeg (after `brew install ffmpeg`):

```bash
ffmpeg -i input.mov -t 25 -vf scale=1920:1080 -r 30 -c:v libx264 -pix_fmt yuv420p \
  Documentation/AppStoreMedia/output/cpMan-preview.mp4
```

## Poster frame

App Store uses frame at **5 seconds** by default. Pick a frame where the picker is fully open (around 0:05) in ASC when uploading.

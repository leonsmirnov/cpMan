# cpMan App Store Media Kit

Professional screenshots and app preview video for the Mac App Store listing.

## What you get

| Asset | Spec | Count |
|-------|------|-------|
| **Screenshots** | 2880 x 1800 px (16:10) PNG — Apple also accepts 1280 x 800 minimum | 6 branded slides |
| **App Preview** (optional) | 1920 x 1080 px landscape, 15–30 sec, H.264 `.mp4` | 1 video |

Templates use cpMan's navy brand (`#1B2F4D`), full-bleed gradient backgrounds, headline copy, and a slot for your real UI captures.

## Quick start (about 30 minutes)

### 1. Capture raw UI screenshots

```bash
./scripts/capture-app-store-raw.sh
```

This builds cpMan, launches **demo mode** (sample clips), and walks you through capturing the picker, Settings tabs, and menu bar. Saves PNGs into `Documentation/AppStoreMedia/raw/`.

### 2. Export branded App Store slides

```bash
./scripts/export-app-store-slides.sh
```

Opens each HTML template in your browser. Follow the prompts to save full-size PNGs into `Documentation/AppStoreMedia/output/`.

### 3. Record the app preview video

```bash
./scripts/record-app-preview.sh
```

Launches demo mode and prints a timed storyboard. Record with **QuickTime Player → New Screen Recording**, then trim to 15–30 seconds in QuickTime or iMovie.

### 4. Upload to App Store Connect

1. **App Store Connect** → your app → **2.0.0** (or current version) → **Media** / screenshots section.
2. Upload all 6 PNGs from `output/` (drag in order: 01 through 06).
3. **App Preview** tab → upload the `.mp4` (1920 x 1080).
4. Save. No new app review is required for screenshot/video-only updates on an already-approved version (metadata change).

## Folder layout

```
Documentation/AppStoreMedia/
  README.md              ← you are here
  shot-list.md           ← what each slide shows
  video-storyboard.md    ← 25-second preview script
  templates/slides/      ← 6 HTML templates (2880 x 1800)
  raw/                   ← your UI captures (gitignored)
  output/                ← final App Store PNGs (gitignored)
```

## Design notes

- **Background**: dark navy gradient with subtle mesh — matches the app icon.
- **UI frame**: floating Mac-style window with soft shadow (not a literal device bezel — Apple prefers real macOS UI in screenshots; the template frames your capture cleanly).
- **Copy**: short headline + one-line subhead per slide. Edit text in each `templates/slides/*.html` if needed.
- **Typography**: system UI stack (SF Pro on Mac) for a native feel.

## Optional: automate with ffmpeg / ImageMagick

For scripted video assembly after recording:

```bash
brew install ffmpeg
```

Then trim and scale your QuickTime export:

```bash
ffmpeg -i ~/Desktop/cpMan-preview.mov -t 25 -vf scale=1920:1080 -c:v libx264 -pix_fmt yuv420p \
  Documentation/AppStoreMedia/output/cpMan-preview.mp4
```

## Apple requirements (macOS)

- Screenshots: **16:10**, min **1280 x 800**, max 10 per localization, PNG/JPEG.
- App Preview: **landscape only**, **1920 x 1080**, 15–30 sec, H.264, max 500 MB, up to 3 videos.
- Preview must show **real in-app footage** (no marketing animations only — UI must be visible).

See [shot-list.md](shot-list.md) and [video-storyboard.md](video-storyboard.md) for per-slide detail.

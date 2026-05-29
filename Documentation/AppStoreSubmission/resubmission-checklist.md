# Resubmission checklist (after 2.1 / 1.5 rejection)

Run through this before uploading the new build and clicking **Submit for Review**.

## Code and build

- [ ] Bump `CURRENT_PROJECT_VERSION` in `project.yml` (build **2** for this resubmission).
- [ ] Optional: bump `MARKETING_VERSION` if you want 1.0.1 instead of reusing 1.0.0.
- [ ] `xcodegen generate`
- [ ] `./scripts/release-app-store-archive.sh` succeeds
- [ ] Upload new `.pkg` via Organizer or Transporter; wait until build is **Ready**

## Demo mode (Guideline 2.1)

- [ ] Normal launch: picker is **empty** until you copy text (no auto demo for customers).
- [ ] `./scripts/launch-cpman-demo-mode.sh` OR `open -b com.cpman.app --args -CPManDemoMode` → 15 samples after ⌃⌥V.
- [ ] Menu **Load Demo Content** still works as fallback.
- [ ] Review notes updated (Option A = Terminal command).
- [ ] Picker shows list (not empty), search works (try `meeting`, `git`).
- [ ] Settings → **Demo content** section visible; Clear / Reload work.
- [ ] Return, Space preview, Delete, 1–9 shortcuts work on sample rows.
- [ ] Paste review notes from `review-notes.md` (demo section updated).

## Support URL (Guideline 1.5)

- [ ] GitHub Pages enabled: repo **Settings → Pages → `/docs` branch**.
- [ ] Support page loads in browser: `https://leonsmirnov.github.io/cpMan/support/`
- [ ] Page is **HTML** (not raw GitHub markdown). Must show contact email and FAQ.
- [ ] App Store Connect → **App Information** or version page → **Support URL** set to the Pages URL above (not `github.com/.../support.md`).
- [ ] Privacy Policy URL still works: `https://leonsmirnov.github.io/cpMan/privacy/`

## App Store Connect

- [ ] Attach **new build** to the version (remove old build if needed).
- [ ] Update **App Review Information → Notes** from `review-notes.md`.
- [ ] Paste **Resolution Center reply** from `resolution-center-reply.md` when resubmitting.
- [ ] Screenshots still accurate (picker with sample content is fine).

## Optional reviewer launch flag

Documented in review notes; not required if auto-seed on first launch works:

```bash
open -a cpMan --args -CPManDemoMode
```

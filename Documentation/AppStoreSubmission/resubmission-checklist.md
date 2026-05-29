# Resubmission checklist (after 2.1 / 1.5 rejection)

Run through this before uploading the new build and clicking **Submit for Review**.

## Code and build

- [ ] `CURRENT_PROJECT_VERSION` in `project.yml` is **4** (higher than any uploaded build).
- [ ] `xcodegen generate`
- [ ] `./scripts/release-app-store-archive.sh` succeeds
- [ ] Upload `build/AppStore/Export/cpMan.pkg` via Transporter or Xcode Organizer
- [ ] Wait until build **1.0.0 (4)** is **Ready** in App Store Connect

## Demo mode (Guideline 2.1)

- [ ] Normal launch: picker is **empty** until you copy text.
- [ ] No **Load Demo Content** item in the menu bar menu.
- [ ] `./scripts/launch-cpman-demo-mode.sh` → ⌃⌥V shows ~15 samples (e.g. "Team standup notes").
- [ ] Review notes pasted from `review-notes.md` (Terminal command with `open -n`).

## Support URL (Guideline 1.5)

- [ ] GitHub Pages live: `https://leonsmirnov.github.io/cpMan/support/`
- [ ] Privacy page live: `https://leonsmirnov.github.io/cpMan/privacy/`
- [ ] App Store Connect Support URL uses the Pages link (not `github.com/.../support.md`).

## App Store Connect

- [ ] Attach build **1.0.0 (4)** to version 1.0.0.
- [ ] Update **App Review Information → Notes** from `review-notes.md`.
- [ ] Reply in **Resolution Center** using `resolution-center-reply.md`.
- [ ] Submit for Review.

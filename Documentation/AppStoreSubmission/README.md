# App Store Submission Packet — cpMan

Everything you need to submit cpMan to the Mac App Store and minimize
back-and-forth with App Review. Each file in this folder maps to a specific
App Store Connect section or to a likely review question.

| File | What it's for |
|------|---------------|
| [`metadata.md`](./metadata.md) | Every text field in App Store Connect (name, subtitle, description, keywords, promotional text, URLs, copyright, categories) with character counts and copy-paste-ready content. |
| [`privacy-policy.md`](./privacy-policy.md) | Privacy Policy text. Host it (GitHub Pages, your own site) and paste the URL into App Store Connect. |
| [`support.md`](./support.md) | Support page content. Same: host it and paste the URL. |
| [`review-notes.md`](./review-notes.md) | Reviewer notes — paste into **App Review Information → Notes**. Replaces the old `Documentation/AppStoreReviewNotes.txt`. |
| [`reviewer-faq.md`](./reviewer-faq.md) | Pre-emptive answers to questions clipboard / menu-bar apps usually get from App Review. Reference internally; copy snippets into the review notes if you want them inlined. |
| [`screenshots.md`](./screenshots.md) | Required sizes, what each screenshot should show, and ready-to-use captions. |
| [`age-rating.md`](./age-rating.md) | Exact answers for the App Store Connect age-rating questionnaire. |
| [`encryption-compliance.md`](./encryption-compliance.md) | Why `ITSAppUsesNonExemptEncryption = false` is correct and what to say if asked. |
| [`privacy-labels.md`](./privacy-labels.md) | App Privacy "nutrition label" answers — "Data Not Collected". |
| [`submission-checklist.md`](./submission-checklist.md) | Pre-flight checklist to run through before clicking *Submit for Review*. |

## Quick recap (the version cpMan submits)

- **Bundle ID:** `com.cpman.app`
- **Category:** Productivity (primary). Secondary: *Utilities*.
- **macOS minimum:** 14.0 (Sonoma).
- **Sandboxed:** yes. Hardened Runtime: yes.
- **Permissions requested:** **none**. No Accessibility, no Full Disk
  Access, no Screen Recording, no Camera/Mic, no network.
- **Data collected:** **none**. Everything stays in the app's sandbox
  container.
- **Networking:** none — there is no `com.apple.security.network.*`
  entitlement.
- **Third-party SDKs:** `KeyboardShortcuts` (Swift package by
  sindresorhus, MIT-licensed). It only reads/writes `UserDefaults`.
- **Encryption:** none beyond OS-provided. `ITSAppUsesNonExemptEncryption`
  is set to `false` in `Info.plist`.
- **In-app purchases / subscriptions:** none.
- **Account / login:** none.

If a reviewer asks anything else, the answer is almost certainly in
[`reviewer-faq.md`](./reviewer-faq.md).

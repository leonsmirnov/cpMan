---
title: cpMan Privacy Policy
layout: default
permalink: /privacy/
---

# Privacy Policy — cpMan

*Last updated: 2026-05-15*

This page is the official Privacy Policy for the **cpMan** macOS
application (bundle ID `com.cpman.app`), distributed via the Mac App
Store and as a direct download.

## Short version

cpMan does not collect, transmit, sell, share, or otherwise process any
personal data. Everything cpMan reads from your clipboard stays on your
Mac, inside the app's own sandbox container. There are no accounts, no
analytics, no advertising, and no network requests of any kind.

## What cpMan reads

cpMan watches the macOS general pasteboard (`NSPasteboard.general`) for
new **plain-text** clips. When you copy text in another app, cpMan adds
a record to its on-device history. Non-text payloads (images, files,
rich text) are ignored.

While macOS reports that **Secure Event Input** is active (for example,
when a password field is focused), cpMan automatically pauses recording
so passwords and other secure entries are not captured.

## Where the data lives

History is stored as a JSON file inside the app's sandbox container:

```
~/Library/Containers/com.cpman.app/Data/Library/Application Support/cpMan/history.json
```

No other app can read this location, and cpMan does not copy it anywhere
else. There is a hard cap of **100 entries**; older clips are discarded
to make room for newer ones. You can delete any entry from the picker UI
at any time.

The hotkey you choose for opening the picker is persisted via
`UserDefaults`. That is the only piece of configuration cpMan stores.

## What cpMan sends over the network

Nothing. The app does not have the `com.apple.security.network.client`
or `com.apple.security.network.server` entitlement, so the macOS sandbox
will refuse any networking attempt. You can verify this in Activity
Monitor → Network: cpMan never appears there.

## Third-party services and SDKs

cpMan uses one open-source Swift package, **KeyboardShortcuts** by
Sindre Sorhus (MIT-licensed), to manage the customizable global hotkey.
It runs entirely in-process and only reads/writes the hotkey value in
`UserDefaults`. cpMan integrates no analytics SDK, no crash reporter, no
advertising SDK, and no telemetry of any kind.

## Children

cpMan is rated 4+ in the App Store. It does not collect any data, so it
collects no data from children either.

## Your choices

- **Delete an entry:** open the picker, select the entry, press the
  delete shortcut shown in the UI.
- **Clear the entire history:** quit cpMan, then delete the file at the
  path above.
- **Uninstall:** drag cpMan from `/Applications` to the Trash. macOS
  will also remove the sandbox container the next time you empty the
  Trash; if you want to remove the container immediately, delete
  `~/Library/Containers/com.cpman.app`.

## Changes to this policy

If this policy changes materially, the new version will be published at
the same URL with an updated "Last updated" date.

## Contact

Questions or concerns about privacy:
[opensource@leonsmirnov.com](mailto:opensource@leonsmirnov.com)

*(Update this address before submitting to the App Store if you'd
prefer a different inbox.)*

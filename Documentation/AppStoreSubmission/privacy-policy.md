# Privacy Policy - cpMan

*Last updated: 2026-05-15*

cpMan is a macOS menu-bar app (bundle ID `com.cpman.app`), sold on the Mac
App Store and available as a direct download. This policy describes what
the app does with information on your Mac.

## Summary

cpMan does not collect, send, sell, or share personal data. Clipboard text
you copy is stored only inside the app's sandbox on your Mac. There are no
accounts, no ads, no analytics, and no network access.

## Clipboard access

cpMan reads plain text from the system clipboard when you copy in another
app and adds it to a local history list. Images, files, and rich text are
not saved.

When macOS turns on Secure Event Input (common in password fields), cpMan
stops recording until that mode ends, so passwords are not stored.

## Storage on your Mac

History is kept in a JSON file here:

```
~/Library/Containers/com.cpman.app/Data/Library/Application Support/cpMan/history.json
```

Other apps cannot read that folder. The list holds at most 100 items; older
entries are removed when new ones arrive. You can delete items in the picker.

Your global hotkey is saved in `UserDefaults` on the same machine.

## Network

cpMan has no network entitlements. The sandbox blocks outbound connections.
The app does not phone home, sync, or upload clipboard data.

## Other software in the app

cpMan includes the open-source **KeyboardShortcuts** library (MIT) to store
your hotkey in `UserDefaults`. There is no analytics, crash reporting, or
advertising code in the project.

## Children

The app is rated 4+. It does not collect data from anyone, including children.

## What you can do

- Delete one item from the picker with the delete key shown in the UI.
- Clear all history: quit cpMan and delete the JSON path above, or remove
  `~/Library/Containers/com.cpman.app`.
- Uninstall: move cpMan from Applications to the Trash. Empty the Trash to
  remove the sandbox container, or delete the container folder yourself.

## Updates

If we change this policy, we will post a new version at this URL and change
the date at the top.

## Contact

Privacy questions: opensource@leonsmirnov.com

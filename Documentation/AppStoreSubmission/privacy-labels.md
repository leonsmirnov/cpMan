# App Privacy "nutrition labels"

App Store Connect → **App Privacy** asks you to declare what data the
app collects. cpMan collects nothing, so every category is set to
**Data Not Collected**.

## Step-by-step answers

1. **"Do you or your third-party partners collect data from this app?"**
   → **No, we do not collect data from this app.**

That single answer is the entire questionnaire. App Store Connect will
generate the "Data Not Collected" nutrition label automatically and
will not ask any of the follow-up questions about data types, purposes,
linking, or tracking.

## Why this is accurate

- The app has no networking entitlement; the sandbox blocks any
  outbound connection.
- There is no analytics SDK, crash reporter, advertising SDK, or
  telemetry of any kind in the source tree.
- All clipboard content is stored only in the app's own sandbox
  container on the user's Mac.
- The only persisted preference (`UserDefaults`, the hotkey) is local
  and not transmitted anywhere.

## If a reviewer questions the label

Reply with:

> cpMan has no network entitlement (`com.apple.security.network.client`
> and `.network.server` are both absent from the entitlements file),
> contains no analytics or telemetry SDK, and stores all clipboard
> history exclusively inside the app's sandbox container at
> `~/Library/Containers/com.cpman.app/Data/Library/Application Support/cpMan/history.json`.
> The Privacy Manifest (`PrivacyInfo.xcprivacy`) declares one
> Required-Reason API: `NSPrivacyAccessedAPICategoryUserDefaults`,
> reason `CA92.1`, used by the bundled KeyboardShortcuts package to
> persist the user's chosen hotkey. No data leaves the device, so the
> "Data Not Collected" label is correct.

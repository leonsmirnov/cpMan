# Export-compliance (encryption)

cpMan does not implement any cryptography of its own and does not call
any Apple framework with the purpose of encrypting user data. It also
does not transmit data over the network at all (no network entitlement),
which means even Apple's HTTPS-style exemption is not actually needed.

## What's in the build

`Info.plist`:

```xml
<key>ITSAppUsesNonExemptEncryption</key>
<false/>
```

Once a build containing this key is uploaded, App Store Connect skips
the encryption questionnaire automatically on every subsequent upload.

## App Store Connect answer

In **App Store Connect → App Information → Encryption**:

> *Does your app use encryption?* — **No**

## If a reviewer asks anyway

Paste the following:

> cpMan does not implement any cryptography of its own and does not
> call Apple's cryptography frameworks (CommonCrypto, CryptoKit,
> Security.framework) for the purpose of encrypting user data. The
> app has no network entitlement (verifiable in the entitlements
> file: neither `com.apple.security.network.client` nor
> `com.apple.security.network.server` is present), so it does not
> establish TLS connections either. The `Info.plist` declares
> `ITSAppUsesNonExemptEncryption = false` to reflect this. No Year-End
> Self-Classification Report (ERN) is required because no controlled
> encryption functionality is shipped.

## References

- Apple Developer documentation: <https://developer.apple.com/documentation/security/complying-with-encryption-export-regulations>
- US Bureau of Industry and Security FAQs on mass-market software: <https://www.bis.doc.gov/index.php/policy-guidance/encryption>

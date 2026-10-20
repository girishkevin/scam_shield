# Scam Shield threat model

This document says what Scam Shield protects, from whom, and what it does not defend against.

## What we protect

| Asset | Why it matters |
|---|---|
| Scan history (pasted messages, links, QR contents) | May contain private messages, payment details, names and phone numbers |
| The user's decisions | A wrong "safe" verdict can lead to a loss, so the tool must not give false reassurance |
| The device and account | The app must not become a way into the phone or send data out |

## Who we consider

1. **A person who briefly holds the unlocked phone** (family, a colleague, a thief who grabbed it unlocked).
2. **Another app or malware on the device** trying to read Scam Shield's files.
3. **A scammer** who controls the content of a message, link or QR code the user checks.
4. **Someone who gets a copy of the app's data** through a cloud backup or a copied file.

## Threats and mitigations

| # | Threat | Mitigation |
|---|---|---|
| 1 | Someone opens the History tab on an unlocked phone | Biometric or screen-lock prompt before history is shown, and it locks again when the app goes to the background |
| 2 | Another app reads the history file | Stored in the app's private storage and encrypted with AES-256-GCM, so the file contents are unreadable without the key |
| 3 | The key is stored next to the data | The key is kept separately in Android Keystore-backed secure storage |
| 4 | History is copied through cloud backup | Android backup is disabled for the app |
| 5 | The history file is modified or corrupted | GCM authentication fails on any change. The app discards the file instead of trusting it, and never crashes on it |
| 6 | A scam message or QR contains a malicious link | Content is treated as untrusted text. It is analyzed locally and never opened, executed or fetched |
| 7 | Data leaves the device | The release build declares no network permission (verified with `aapt2 dump permissions`), so the operating system blocks all network access. The app also has no analytics and no accounts |
| 8 | The ML model gives false reassurance | The model can only add to the risk score. It can never lower a score that the rules produced |
| 9 | A crash or a failed save loses or exposes data | Saves go through a temporary file and are then swapped in. Save failures are ignored without affecting a scan |

## Out of scope (not defended)

- **A rooted device, a debugger, or a compromised operating system.** While the app is open, history is decrypted in memory.
- **Someone who knows the phone's PIN or whose biometrics are enrolled.** Scam Shield relies on the operating system lock.
- **Shoulder surfing and screenshots.** Screenshot blocking is not enabled.
- **Scammers who adapt.** Rules and the model are heuristics. A determined scammer can reword a message to avoid them. Detection will never be complete.
- **Reverse engineering.** The scoring rules and model are not secret. Release builds use code obfuscation, but this is not a security boundary.
- **Supply chain risk in third-party packages.** Dependencies are pinned by the lock file but not independently audited.

## Known gaps and possible hardening

- Block screenshots and hide the app preview in the recent apps list on the History tab.
- Lock History after a short inactivity timeout, not only when the app is backgrounded.
- Let the user turn history off or choose how long entries are kept.
- Rotate the encryption key when the user deletes all history (the key is already deleted with the data).
- Expand shortened links and check against a blocklist, as an opt-in feature, since that needs network access.
- Add far more real Indian scam examples to the training data and measure on a larger, separate test set.

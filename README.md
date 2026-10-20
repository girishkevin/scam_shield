# Scam Shield

An on-device scam and phishing detector for Android, built with Flutter. It checks **links, messages and QR codes** (including UPI payment codes) and explains *why* something looks risky, without sending anything off your phone.

**[Download the latest APK](https://github.com/girishkevin/scam_shield/releases/latest)**

<p align="center">
  <img src="docs/screenshots/01-link-dangerous.png" width="22%" alt="Link check showing a dangerous result" />
  <img src="docs/screenshots/02-message-ml.png" width="22%" alt="Message check with on-device model explanation" />
  <img src="docs/screenshots/03-qr-upi.png" width="22%" alt="QR scan of a UPI payment code" />
  <img src="docs/screenshots/04-history-locked.png" width="22%" alt="Encrypted history behind a biometric lock" />
</p>

## Why this exists

Online fraud in India often arrives as a message: a fake KYC link, a "scan this QR to receive money" trick, a call about a parcel or an arrest. Most checkers upload what you paste to a server. Scam Shield does the analysis locally, so the message, link or QR you check stays on your device.

## Features

- **Link check**: scores a URL from 0 to 100 using rule-based signals (look-alike brand names, risky endings, URL shorteners, raw IP addresses, `@` tricks, look-alike characters, urgency words) and lists the reasons in plain language.
- **Message check**: detects scam wording in English and Hinglish (OTP requests, "account will be blocked", fake KYC, fake rewards, advance fees, remote-access apps, APK installs, "digital arrest" threats), pulls out every link and checks each one. Genuine warnings such as "do not share your OTP" are not flagged.
- **QR scanner**: live camera scan. Link codes go through the link check, **UPI payment codes** are parsed (payee, UPI ID, amount) and warned about, and text codes go through the message check. It never opens anything for you.
- **Share to Scam Shield**: long-press a message in any app, tap Share and choose Scam Shield. Implemented with a native Kotlin platform channel.
- **On-device ML**: a small TF-IDF + logistic regression model trained in Python and run in pure Dart. It can only *raise* the risk score, never lower it, and shows the words that influenced it.
- **Encrypted history**: past checks are stored with AES-256-GCM. The key lives in Android Keystore-backed secure storage, and the History tab needs your fingerprint, face or screen lock.
- **Premium UI**: light and dark themes, large titles, animated score ring, floating glass navigation bar, haptic feedback.

## How the scoring works

Each check produces a list of *signals*, each with a weight. The weights are added and capped at 100.

| Score | Level |
|---|---|
| 0 to 24 | Looks safe |
| 25 to 54 | Be careful |
| 55 to 100 | Dangerous |

For messages, the score is the larger of the wording score and the worst link score. If scary wording and a risky link appear together, 15 points are added. The ML model adds a small signal when it is very confident (about 75% and above) and never subtracts.

## Architecture

```
lib/
  core/                  theme, risk colours, shared widgets (score ring, cards, nav bar)
  features/
    link_check/          LinkAnalyzer (pure Dart) + screen
    message_scan/        MessageAnalyzer, ScamClassifier (ML inference) + screen
    qr_scan/             QrAnalyzer (links, UPI, text) + camera screen
    history/             HistoryCrypto (AES-GCM), HistoryStore, biometric lock + screen
android/.../MainActivity.kt   receives text shared from other apps (platform channel)
ml/                      train.py + training data
assets/ml/               exported model (JSON)
test/                    unit tests, including Dart-vs-Python model parity
```

State is managed with Riverpod. The analyzers are plain Dart classes with no Flutter dependencies, which keeps them easy to test.

## Privacy and security design

- No accounts, no analytics, no servers. The release build declares **no network permission**, so Android does not allow the app to go online at all. A library added `INTERNET` and `ACCESS_NETWORK_STATE`; the manifest removes them. You can check this yourself with `aapt2 dump permissions app-release.apk`.
- History is encrypted with AES-256-GCM using a random key. GCM also detects tampering, and a corrupted file is discarded rather than trusted.
- The key is kept in Android Keystore-backed secure storage, separate from the data file.
- The History tab requires biometric or screen-lock authentication and locks again when the app goes to the background.
- Android cloud backup is disabled so the encrypted file is not copied off the device.
- Shared text, scanned QR contents and pasted links are treated as untrusted input. They are analyzed as text and never opened or executed.
- Camera permission is requested only when the Scan tab is used, and the camera turns off when you leave it.

See [docs/THREAT_MODEL.md](docs/THREAT_MODEL.md) for what is and is not defended against.

## The ML model

- **Model**: TF-IDF over word 1 and 2-grams, logistic regression, exported as a JSON file of term weights and run in Dart. No native ML library is needed.
- **Training data**: the public [UCI SMS Spam Collection](https://archive.ics.uci.edu/dataset/228/sms+spam+collection) plus about 90 hand-written India-style examples in `ml/data/india_messages.txt`.
- **Held-out results (20% split)**: on 1,133 messages, scam precision was 0.968 and recall 0.943. About 98% of the data is the English UCI set, so this is **not** a measure of accuracy on Indian scams. On the 21 India-style test messages accuracy was 81%, which is too few messages to rely on.
- **Parity tests**: the Dart classifier is tested against probabilities computed by scikit-learn to make sure both give the same answers.

To retrain:

```bash
python -m pip install scikit-learn numpy
# optional: place the UCI file "SMSSpamCollection" in ml/data/
python ml/train.py
```

This rewrites `assets/ml/scam_model.json`. Run `flutter test` afterwards.

## Limitations

- Detection is heuristic. It will miss some scams and flag some genuine messages.
- The model has seen little real Indian scam data. Rules are the main defense and the model is a supporting signal.
- Links are judged by their shape only. There is no live blocklist and shortened links are not expanded, because that would need network access.
- The brand look-alike list is small and should be extended.
- It does not read SMS automatically. This is deliberate, because it would need a powerful permission and Google Play restricts it.
- While the app is open, history is decrypted in memory. Rooted devices and a compromised operating system are out of scope.
- Android only.

## Build and run

Requirements: Flutter SDK, Android Studio, an emulator or Android phone.

```bash
git clone https://github.com/girishkevin/scam_shield.git
cd scam_shield
flutter pub get
flutter test
flutter run
```

## Tech

Flutter, Dart, Riverpod, Kotlin (platform channel), `mobile_scanner`, `local_auth`, `flutter_secure_storage`, `cryptography`, scikit-learn (training only).

## Author

Built by Girish Kevin as a project for a BCA specialising in mobile application development and information security.

## Acknowledgements

- Training data: Almeida, T. & Hidalgo, J. (2011). SMS Spam Collection (Dataset). UCI Machine Learning Repository. https://doi.org/10.24432/C5CC84

## License

Scam Shield's source code is released under the [MIT License](LICENSE). The UCI dataset has its own licence, described on its dataset page.

# FORGE 1.0.0

The portfolio release is a source distribution of the offline Mac and iPhone workflow. It includes manual evidence, deterministic progression, a transaction ledger, business and skill records, reviews, recovery, local planning, and portable backups.

## Changes since the technical audit

- One configurable bundle identity now drives the app, Screen Time extensions and test target. Mac optional entitlement generation keeps Calendar and user-selected file access.
- A confirmed local purge commits row deletion before cleanup. An interrupted operation leaves an intent marker and a retry screen. The app reports unfinished cleanup. Turn off sync and restart before purging an active CloudKit-backed workspace.
- Saving a changed session now reuses the validated backup envelope for the durable revision and the automatic backup. Independent review additions can merge without letting array order change which review informs planning.
- The default profile and demo data use neutral identities. The source snapshot excludes historical workstation metadata. The app icon is original, generated artwork. The native walkthrough captures an isolated synthetic app workspace.
- The test gate includes resolved signing configuration and public-snapshot checks. The GitHub Actions workflow uses the Xcode 27 arm64 runner image with Xcode 27.2 and a read-only workflow token.

## Verification scope

Local verification uses an Apple silicon Mac with macOS 26.6.2, Xcode 27.2 (27B52), and iPhone 17 Pro Simulator with iOS 26.5. See [the walkthrough](docs/demo/README.md) for native evidence. Local runs passed 41 Swift core tests, six signing tests, eight snapshot checks, seven Python backend tests, four Node tests and three product UI workflows per platform. The Mac UI runner launched and exercised the app with strict bundle signature validation. The iPhone product suite had zero runtime warnings. Hosted checks are listed separately in the repository's Actions tab if run. The source release makes no claim of App Store distribution or notarization.

Backup, restore, interrupted purge and failed writes use actual temporary SwiftData databases. The native UI workflow covers onboarding, manual completion, rewards/history, relaunch, payments, review, recovery and a large-text skill form. The OS file picker and live Keychain, Calendar, notifications, HealthKit, Screen Time and CloudKit behavior are outside the automated fixture.

The iPhone-only verified matrix does not include iPad rotation. The unsigned device build can still emit an orientation warning. The `Invalid frame dimension` warning reproduced in the separate debug diagnostic control built from native SwiftUI components. The product test suite is reported separately from that control.

## Storage benchmark

The repeatable optimized benchmark is `swift run -c release ForgeDesktop --storage-benchmark`. Its synthetic session includes 91 daily snapshots and 500 evidence items. It makes 120 ordinary writes on the main actor and measures load and restore separately.

| Measurement | Observed after envelope reuse |
| --- | ---: |
| Backed-up session size | 429,953 bytes |
| Database and sidecars, after 2 revisions | 1.38 MB |
| Database and sidecars, after 121 revisions | 71.63 MB |
| Main-actor write, median / p95 | 236 ms / 589 ms |
| Cold / warm reopen | 19.00 s / 250 ms |
| Validated restore | 1.18 s |

The local runs shared the host with other verification processes. These timings show that cold verification and synchronous saves can be noticeable on a populated history. They do not measure rendered frames or establish a performance guarantee. Whole-state revision growth remains a known limitation. The release retains validation of every revision and does not compact history.

## Publication and license

The intended public history is a clean reviewed snapshot. The original development repository remains the local recovery point. This source distribution has no open-source license. Contact the repository owner for reuse permission. See [engineering decisions](docs/ENGINEERING_DECISIONS.md#asset-provenance) for the artwork and screenshot provenance.

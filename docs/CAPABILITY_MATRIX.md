# Capability matrix

Observed on 2026-10-08. `IMPLEMENTED` means code exists, not that a permission, entitlement or account works. No physical iPhone has been verified. Default builds keep optional Apple capabilities disabled. Manual proof and the core game work offline.

| Feature | macOS | iPhone simulator | Signed iPhone | Offline | Backend | CloudKit | Extension |
|---|---|---|---|---|---|---|---|
| Onboarding, quests, XP/MMR/Coins, business, skills, reviews, recovery | END_TO_END_VERIFIED: native GUI and 3 XCTest workflows | SIMULATOR_VERIFIED: XCTest | ACCOUNT_SETUP_REQUIRED: signing/run | LOCALLY_VERIFIED | — | Optional; not needed locally | — |
| Disk persistence, migration, write rollback, backup/recovery | LOCALLY_VERIFIED: real SwiftData disk and GUI relaunch | SIMULATOR_VERIFIED: persistent fixture relaunch | ACCOUNT_SETUP_REQUIRED: device relaunch | LOCALLY_VERIFIED | — | Graph cases locally verified; delivery pending | — |
| Analytics, Ghost, streaks, bosses, ledger | LOCALLY_VERIFIED: UI + 366-day fixture | SIMULATOR_VERIFIED: navigation/render | IMPLEMENTED: hardware render pending | LOCALLY_VERIFIED | — | Stored in private state if enabled | — |
| Local AI, all five actions | LOCALLY_VERIFIED | SIMULATOR_VERIFIED: offline loop | IMPLEMENTED | LOCALLY_VERIFIED | Optional local provider fixture | — | — |
| Remote plan → validate → accept → quest | END_TO_END_VERIFIED: Swift client + loopback local provider | IMPLEMENTED | IMPLEMENTED | LOCALLY_VERIFIED: fallback | END_TO_END_VERIFIED with local fixture; real provider ACCOUNT_SETUP_REQUIRED | — | — |
| GitHub proof | ACCOUNT_SETUP_REQUIRED: repository token | IMPLEMENTED | IMPLEMENTED | LOCALLY_VERIFIED: manual proof | Direct read-only API | — | — |
| Coding/n8n inbox, paging, immutable IDs, manual completion | END_TO_END_VERIFIED: real Swift/HTTP chain | IMPLEMENTED: adapter built | IMPLEMENTED | LOCALLY_VERIFIED: cached/manual proof | END_TO_END_VERIFIED: SQLite/HTTP fixtures; real n8n ACCOUNT_SETUP_REQUIRED | Cursor persisted with state | END_TO_END_VERIFIED: actual focused host minute → backend → Swift inbox → Builder quest proof/rewards |
| Health | LOCALLY_VERIFIED: manual; HealthKit unsupported | IMPLEMENTED: Health adapter compilation; no real samples | ACCOUNT_SETUP_REQUIRED: HealthKit/signing/read permission | LOCALLY_VERIFIED: manual and missing/stale data | No raw Health transmission | Derived summaries only when opted in | — |
| Calendar capacity | ACCOUNT_SETUP_REQUIRED: permission; capacity rules LOCALLY_VERIFIED | IMPLEMENTED: adapter | ACCOUNT_SETUP_REQUIRED: permission/real events | LOCALLY_VERIFIED: manual planning | No event-title transmission | — | — |
| Focus and earned entertainment timer | LOCALLY_VERIFIED: honor timer and reward debit | IMPLEMENTED: default timer; state rules verified | IMPLEMENTED: timer without Screen Time | LOCALLY_VERIFIED | — | Non-protected rule/redemption state | — |
| Focus Lock / Earned Access / Daily Limit shielding | Timer fallback | IMPLEMENTED: compiled; simulator cannot prove enforcement | ACCOUNT_SETUP_REQUIRED: Family Controls and authorization | IMPLEMENTED: native OS schedule | — | Protected selection excluded | IMPLEMENTED: embedded monitor; device execution pending |
| Protected usage report | Unsupported | IMPLEMENTED: embedded report build | ACCOUNT_SETUP_REQUIRED: authorized signed device | IMPLEMENTED: private native view | Never exported | Never exported | IMPLEMENTED: report scene, private data |
| Sparse notifications | ACCOUNT_SETUP_REQUIRED: permission | IMPLEMENTED: pure schedule tested | ACCOUNT_SETUP_REQUIRED: permission/background behavior | IMPLEMENTED: OS schedule | — | — | — |
| Keychain/settings consistency | LOCALLY_VERIFIED: typed failure/rollback fixture; real user credential access pending | IMPLEMENTED: Security adapter compiled | ACCOUNT_SETUP_REQUIRED: signed device read/write/delete | IMPLEMENTED | Provider key stays server-side | Credentials excluded | SecretStorage real-host fixture verified |
| Private cross-device sync | ACCOUNT_SETUP_REQUIRED: signed app/container/iCloud | IMPLEMENTED: graph and CloudKit adapter | ACCOUNT_SETUP_REQUIRED | LOCALLY_VERIFIED: local saved/pending behavior | — | ACCOUNT_SETUP_REQUIRED: real delivery/account switching | — |
| Automated native UI testing | END_TO_END_VERIFIED: correctly signed local runner; 3 XCTest workflows passed | SIMULATOR_VERIFIED | ACCOUNT_SETUP_REQUIRED | UI fixtures isolated | — | Disabled in tests | Disabled in tests |

A CloudKit export success is not proof of another device's receipt. A simulator compile is not proof of Health data access, app shielding, Keychain device behavior or background delivery. Real-provider AI and deployed private HTTPS are not verified by the local provider fixture.

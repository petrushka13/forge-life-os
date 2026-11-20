# Acceptance report

Historical local engineering release, October 8, 2026. See the repository release notes for the portfolio V1 gates. This report distinguishes real native UI/disk/HTTP evidence from unverified Apple/account integrations. Existing data and work were preserved; all development fixtures are isolated. No external deployment or publication occurred.

## Implemented

Native Mac/iPhone daily loop, onboarding, manual/timer/imported proof, deterministic XP/levels/ranks/domain and Life MMR, Coins/reward timers, business/payment pipeline, skill evidence/prerequisites, weekly/monthly bosses, reviews, recovery, streaks/Ghost, bounded analytics and append-only ledger. Local Game Master supports all five actions; remote plans require preview and atomic idempotent acceptance. Duration/imports never award progress automatically.

Audit defects were corrected: bounded numeric conversion/normalization, coding active-duration contract, zero calendar capacity, shared outcome budgets, metric-preserving Health merge, explicit local reset versus purge, recoverable damaged launch, transactional settings/credential application, real Keychain error statuses, AI provenance/preservation, separate backend auth and durable evidence cursors. Game days use a pinned time zone and DST-safe calendar arithmetic. Backups reject hostile dates, cycles, duplicates, broken references, corrupt checksum/schema and oversized input before changing live state.

Storage now preserves immutable revisions, validates cold graphs, caches unchanged validated history, quarantines corruption, rejects missing parents and stale saves, preserves both unsafe conflicts, and safely merges only independent append-only records. Real legacy migration, private retained backups, pre-restore copies, explicit damaged-store recovery and isolated purge are implemented. CloudKit statuses distinguish local persistence from export and remote receipt.

Independent Apple integration code is complete: read-only Health metrics, EventKit capacity, sparse notifications, Family Controls/ManagedSettings/DeviceActivity modes and opaque selection, embedded monitor/report, temporary access and reasoned emergency override. Signing configuration and selected entitlements are generated in ignored local files. Default builds disable optional entitlements. Actual Apple authorization/enforcement remains a device/account gate.

The private backend includes strict Responses output validation, opt-in provider/local/evidence-only modes, TLS deployment instructions, entropy-checked independent tokens, readiness, bounded requests/timeouts/rates, SQLite durable pagination and backup/restore. VS Code tracks only opt-in focused/trusted active minutes, uses SecretStorage/HMAC identity, retries a bounded queue, and cancels stop/erase safely.

## Passing local evidence

- `./scripts/verify_release.sh` exited 0. 40 Swift tests, seven Python/backend tests and four Node/companion tests passed. No failures/skips in those suites.
- Real disk smoke passed legacy StoredRecord migration, UUID-preserving relaunch, stale concurrent-save rejection, injected write failure without UI rewards, backup restoration, corrupt-row quarantine, missing-parent blocking and synthetic purge.
- Real Swift client → loopback HTTP server → strict local plan → validation/acceptance → evidence cursor → manual completion/rewards → backup/restore passed. Provider mode was a local fixture, not actual OpenAI inference.
- Actual VS Code Extension Development Host fixture passed activation and five command workflows, no-token flush, stop/erase and result marker. The full coupled fixture also passed: a user-held foreground synthetic editor produced one real minute through the actual 60-second timer and SecretStorage → temporary HTTP backend → Swift evidence inbox → explicit matching Builder quest completion/rewards → backup restore. Import alone awarded nothing; opaque workspace identity was checked and source text/full paths were absent. Fixture recording/credentials were erased. Reproduce with `python3 server/verify_host_chain.py --client /absolute/path/to/ForgeIntegrationCheck`. Four Node tests separately cover endpoint privacy, focused/trusted duration, queue/retry and in-flight erase.
- Native macOS and generic iPhone Simulator Debug and optimized Release builds passed. The latest universal Mac Release rebuild used Xcode local signing and passed. App Intents metadata extraction was skipped because the app has no AppIntents dependency. Embedded ForgeMonitor/ForgeReport installed in the simulator build; optional Health/Cloud/Screen Time compile flags were also built. No signing entitlement or physical-device claim follows from compilation.
- Mac native UI automation through the isolated app verified onboarding, starting 1000/Bronze II/level 1/three quests, concrete proof, 110 XP/51 Coins, Business 1014/Life 1006, receipt/history, 150000 KZT payment and dashboard, Practicing skill with proof, saved review, recovery preserving completed work, local coaching, reward debit 51 → 21 and active 30-minute timer, and offline navigation. Final native build also quit/relaunched the same disk fixture and retained proof and all balances. Final Progress renders unavailable coding as `— h`, not invented zero. The optimized Release app reopened the saved fixture, recorded another synthetic payment and showed Life MMR 1009 with the corrected +9 weekly composite change; the rounding regression passed. The refreshed optimized universal Mac artifact also passed strict signature verification and its isolated disk smoke. The prior artifact remains preserved as `artifacts/FORGE-before-runner-repair.app`. The final correctly signed local Mac XCTest runner also launched, connected to FORGE and executed all three product workflows: zero failures/skips. Reproduce with `bash scripts/verify_mac_ui.sh`; exact result and warnings are in `docs/verification/macos-ui.json` and the signing diagnosis.
- iPhone 17 Pro / iOS 26.5 ran the daily loop, business, review, recovery and the large-text/light skill workflow. The consolidated run passed three product workflows and one native editor diagnostic control. A later product-only run passed all three workflows without runtime warnings. See the portable historical summaries in `docs/verification/`.

## Twenty original acceptance steps

| Step | Actual evidence |
|---|---|
| 1 Onboarding | Mac native form and simulator onboarding |
| 2 Life MMR | Fresh 1000; post-completion 1006 on Mac; simulator numeric assertion |
| 3 Rank | Bronze II visible in native Mac and simulator |
| 4 Level | Level 1; progress from 0 to 110/200 XP |
| 5 Three quests | Main/secondary/supporting buttons verified |
| 6 Complete quest | Concrete manual result submitted; completed button disabled |
| 7 XP | Actual +110 XP receipt and history |
| 8 Coins | Actual +51 Coins and persisted balance |
| 9 Transaction | Append-only XP/Coin/MMR entries rendered in Progress |
| 10 Domain MMR | Business 1000 → 1014 visible on Mac |
| 11 Life recalculation | Derived 1000 → 1006 visible, engine weights tested |
| 12 History | Progress native history and simulator history element |
| 13 Revenue | Synthetic 150000 KZT entered through native forms |
| 14 Business dashboard | Payment totals/customer displayed on both platforms |
| 15 Skills | Native proof and Practicing state save/reopen; largest Dynamic Type/light test |
| 16 Daily review | Native Mac review saved; simulator save flow |
| 17 Recovery | Concrete 25-minute recovery quest; completed work retained |
| 18 Relaunch | Actual GUI disk quit/relaunch on Mac and simulator; disk migration smoke |
| 19 Both platforms render | Native Mac accessibility/render evidence; simulator screenshots |
| 20 Offline without AI | All UI fixtures run without remote credentials; local planner responds |

## Volume and performance

The deterministic fixture contains 366 days (365-day history plus current day), 10,051 external records and real rewards/ledger/history/Health/revenue. Final measured import 2.500 s, backup encode 1.263 s, decode/validation 1.267 s, analytics 0.000607 s; backup 3,619,714 bytes. These are observed host fixture timings, not a performance SLA. Sixty durable SwiftData revisions: cold load 0.024277 s, unchanged warm load 0.002232 s. Charts expose at most 365 samples; transactions page by 40; evidence fetches 100/page, bounded to 20 pages per import batch.

## External gates and warnings

No failing local product check or known unresolved product defect remains in the exercised workflows. This does not prove absence of bugs in unexercised device/account paths. No signed physical iPhone was connected/verified. Apple development signing, real Keychain access, Health permissions/known data, Family Controls entitlement/shielding/report/closed-app expiry, Calendar permission, notification delivery and private CloudKit cross-device/account-switch checks require the user. Real GitHub/n8n/provider credentials and a chosen private HTTPS endpoint are also pending. `ACCOUNT_SETUP.md` contains exact setup and verification steps.

The earlier “damaged” Mac XCTest runner was a local signing/packaging defect: signing was disabled after Xcode modified the prebuilt agent bundle. Those launch failures remain failed evidence. Fresh Xcode local signing repaired the complete runner/plugin, strict recursive verification passed, and the actual final suite executed all three product workflows successfully. No global security exception or Apple signing identity was needed. Standalone Gatekeeper assessment still rejects the ad-hoc artifact for distribution. See `MAC_UI_SIGNING.md` for diagnosis and exact commands.

The passing Mac XCTest result retains three internal quality-of-service priority-inversion warnings and console DisplayManager diagnostics. Xcode reports a debugger lookup `noURL` diagnostic; diagnostic collection sometimes timed out after 600 seconds, including after passing tests. The simulator emitted `Invalid frame dimension` while focusing an editor. It also reproduced in a DEBUG-only minimal native SwiftUI sheet/Form/TextField with a keyboard toolbar and no FORGE layout. The completion-form workaround moves keyboard dismissal to the navigation toolbar; the final shipping run passed all three product workflows with zero runtime warnings and zero failures/skips. This diagnostic control is absent from Release builds and never reads live data.

Minimum iOS 17/macOS 14 deployment compatibility was compiled; those older runtime versions were not exercised. V1 skill verification is explicit self-attestation with practical evidence, not an automatic examiner. A 30-day personal-use outcome study has not occurred.

## Completion measure and Git

This historical checkpoint covered the local engineering scope. Apple and account certification remained separate. Equal-weight section acceptance is exactly 60/70 = 6/7 = 85.714285…%, based on the 70-row matrix: nine account/permission/device-gated sections and one longitudinal-use section remain. This defined measure is not a weighted estimate of engineering effort and does not replace row-level evidence.

Branch `production/2026-10-07`; starting checkpoint `9242553`; historical checkpoint `ccc21ac`. Native/core checkpoint `932d6d4`; backend/companion checkpoint `93c15ae`. Local optimized Release Mac artifact: `artifacts/FORGE.app` (Xcode ad-hoc signed with sealed bundle resources; no Apple signing identity, not notarized). Open `FORGE.xcodeproj`, select My Mac or an installed simulator and Run; select your team and connected iPhone for signed-device checks. Resolve final source identity with `git rev-parse checkpoint/forge-personal-release^{commit}`. The final checkpoint preserves locally accepted engineering and all documented external gates.

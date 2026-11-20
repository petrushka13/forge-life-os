# Architecture

`ForgeCore` contains Codable domain values, a pure deterministic GameEngine, game workflows, bounded backup validation, conservative merge, planner contracts, evidence paging/aggregation and notification planning. `App` contains SwiftUI screens, a transactional AppStore, SwiftData repository and public Apple service adapters. `server` provides private Responses API proxying and durable SQLite evidence. `Integrations/VSCode` is an opt-in companion. `ForgeIntegrationCheck` exercises the real Swift client against an isolated HTTP server.

## Durability and migration

AppStore copies state, validates it, saves it, then publishes success and feedback. A failed commit rolls back SwiftData and leaves visible XP/Coins unchanged. Legacy StoredRecord arrays migrate with original identities. New saves append immutable SessionRevision envelopes; parents identify the state used for editing. A fresh context observes imported revisions. Validated immutable revisions are cached by exact row bytes; changed bytes are revalidated.

Incomplete delivery, graph cycles, damaged envelopes and concurrent heads surface recovery/review. Corrupt rows remain intact and get private quarantine copies. A newer corrupt row cannot silently roll state back. Safe merge only combines independent append-only reviews, business activity and evidence inbox records when all protected state agrees. It never adds balances from competing snapshots. Other conflicts require explicit version selection and export; every branch is retained.

CloudKit is opt-in through compile capability, registered container and runtime account. Export events show Saved locally / Pending sync / Sync failed / Synced; the last status means export completion, not proof of another device's receipt. No cross-device claim is made without the device gate.

Backups use a versioned 32 MB envelope with SHA-256, unique IDs, finite bounded numbers, references, graph and enum validation. Automatic files use private permissions and seven-file retention; pre-restore/conflict copies are not pruned as automatic backups. Restore validates before any mutation. Launch recovery can export readable rows or raw store/WAL copies, retry, or switch to a fresh recovery database only after a successful write; the original file remains intact.

## Credentials and adapters

Keychain operations return actual OSStatus and safe error descriptions. Settings pre-reads prior credentials, applies writes and durable settings as one compensating transaction, and rolls back on failure. Imports require successful settings save. Backups/diagnostics exclude credentials. HTTP is ephemeral, refuses redirects and requires HTTPS except loopback. Provider keys exist only in server environment; VS Code uses SecretStorage.

Health merges metric-by-metric with provenance, preserving manual and unrelated values. Calendar reads busy commitments and unions overlaps; capacity considers elapsed and overnight windows. Game settlement uses an onboarding timezone so travel does not create duplicate daily snapshots. Notifications/calendar display local time. Screen Time uses embedded monitor/report extensions and opaque app-group selection; usage is rendered only inside Apple's report extension. Mac has no iOS shielding enforcement.

Performance fixtures cover a year of game history, 10,051 events, 60 durable revisions, pagination and rollback. UI tests use UUID-isolated persistent fixtures or memory. `scripts/generate_project.py --check` detects project drift without overwriting local signing configuration.

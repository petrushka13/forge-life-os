# Integration boundaries

| Integration | Implemented behavior | External gate |
|---|---|---|
| Calendar | Read-only busy commitments, including all-day events; union overlaps and remaining/overnight capacity; titles stay local | OS permission; denial retains manual planner |
| Health | iPhone read-only sleep/wake, steps, workouts/cardio, body mass and water; deduplicated intervals/workouts, metric provenance/availability/staleness; manual merge and relevant quest references | Registered HealthKit and signed iPhone authorization; no Mac Health prompt |
| Screen Time | Embedded ForgeMonitor and ForgeReport; individual authorization, opaque picker, Focus Lock, Earned Access, Daily Limit, background callbacks, emergency override; private Apple report | Family Controls approval, app group, signing and physical-device expiry/re-shield checks |
| CloudKit | Private SwiftData delivery, immutable graph, preserved branches, safe limited merge and truthful export-event state | Registered container, same account on both devices, actual cross-device test |
| AI | Five local/remote actions, compact context v2, bounded strict output, preview/acceptance, offline fallback | Real provider key/model and private HTTPS service choice |
| GitHub | Fine-grained read-only token in Keychain; relevant commit IDs/timestamps/links; auth/rate/offline errors | Token/repository access; commit count never awards progress |
| VS Code | Trusted workspace opt-in, visible status, opaque HMAC identity, active minutes, bounded durable retry queue, stop/erase; real host verification and private packaging command | Configure/install in chosen workspace and private evidence endpoint; SecretStorage |
| n8n | Authenticated immutable ingest with scoped token and SQLite durability/cursor pages; evidence inbox, no auto-completion | Configure your workflow and chosen private backend |
| LeetCode | Manual URL/result proof and protocol; no brittle scraper | No account required for manual proof |
| Notifications | Sparse morning/risk/boss/reward notices, dedupe, cancellation/disable/rescheduling | OS permission and signed-device background delivery verification |

Use `scripts/configure_capabilities.py` to generate **ignored** account-specific signing files. Default native builds contain no optional entitlements. The generated project embeds both actual Screen Time targets; old standalone adapter examples are not used by the project. Build success does not establish entitlement or hardware behavior.

Exact registration fields, minimum scopes, credential locations and verification steps are in [ACCOUNT_SETUP](docs/ACCOUNT_SETUP.md). Server contract/TLS/rotation/SQLite operations: [server README](server/README.md). Companion lifecycle/packaging/host check: [VS Code README](Integrations/VSCode/README.md). No public deployment or distribution is performed automatically.

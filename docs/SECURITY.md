# Security review

FORGE is a single-user, local-first application. No analytics SDK or hidden telemetry is included. The following controls are implemented; device and external service verification are separately recorded in the acceptance report.

| Threat | Control | Remaining risk |
|---|---|---|
| Provider or client secrets leak | Provider key exists only in server environment; client Keychain; companion SecretStorage; diagnostics contain counts and capability flags only; HTTP redirects refused | A compromised account/OS can access secrets. Export files contain personal records and require private storage. |
| Malicious backup / numeric overflow | 32 MB input limit; version and SHA-256 integrity check; bounded finite numbers and dates, unique IDs, acyclic skill dependencies and reference validation before apply | Checksum detects damage, not an authenticated author. A valid backup can deliberately replace state after explicit confirmation. Backups are not encrypted. |
| Duplicate reward / replay | Completed quests immutable; append-only ledger; bounded caps; consumed external evidence IDs; immutable server event IDs reject changed payloads with 409 | Manual evidence is self-attested. FORGE cannot determine whether a description represents honest real work. |
| Compromised AI / prompt injection | Compact versioned context; raw reviews, customer identities, full calendar names and raw Health excluded; strict server/client output validation; preview and explicit acceptance; local engine controls scoring | The provider sees the configured goal and compact aggregate context. AI can still give poor advice; acceptance is a human decision. |
| Token redirect or interception | Ephemeral URLSession refuses redirects; HTTPS required except loopback; scoped independent ingest/client tokens generated from 32 random bytes | TLS deployment and hosting identity must be chosen by the user. Do not expose the Python server directly to the public internet. |
| Request flood / stalled client | 16 KB requests, bounded provider output, 25-second connection timeout, 8 concurrent server threads, 10 plan / 120 ingest requests per minute per address | A reverse proxy should also bound connections and headers; this is a personal service. |
| Database write / sync failure | Persist before publishing success; rollback on failed local write; stale save rejection; preserved immutable branches and private conflict backups; incomplete graph blocks review | Whole scoring state conflicts require a user choice. OS CloudKit export is not proof of other-device receipt. |
| Corrupted local storage | Damaged rows preserved with private quarantine copies; launch recovery export/restore/retry; fresh recovery store leaves original intact | A completely unreadable file may require recovery from an external backup. Recovery copies are personal data. |
| Accidental incomplete deletion | Start Over explicitly retains history. Purge explicitly confirms local scope and optional Keychain deletion | External exports, other devices, remote evidence and OS/cloud retention are outside local deletion. Never promise forensic secure erase on flash storage. |
| Extension privacy / cancellation race | Trusted workspace and explicit start; HMAC workspace identity; no source, keys, clipboard or paths recorded; bounded queue; same-ID retry; stop/erase abort delivery | Already accepted remote evidence remains on the backend. Erase only clears local pending activity and credentials. |
| Screen Time lockout | Individual authorization; public frameworks; schedule before shielding; emergency override; release/re-shield monitor; report stays inside Apple sandbox | Apple authorization can be revoked. All-device bypass detection is unavailable. Hardware permission/expiry behavior requires a signed iPhone test. |

## Redaction policy

Do not log credentials, request/response bodies, customer identities, source text, protected tokens, raw Health, full paths or calendar titles. Backend access logging is disabled. HTTP errors use generic descriptions. Keychain errors include operation and OSStatus only. `FORGE-redacted-diagnostics` is an allowlist of schema/app version, timestamps, counts and capability booleans; free-text errors are excluded. Private recovery and conflict exports are deliberately **not** diagnostic files.

## Verification

Core tests cover tampering, bounded numbers, immutable evidence and AI acceptance. Backend tests cover auth scopes, replay conflicts, malformed contexts, rate limits, paging and SQLite restoration. Companion tests cover offline retry, queue bounds and in-flight erase cancellation. No secrets or real provider requests are used by tests. See `ACCEPTANCE_REPORT.md` for current observed results.

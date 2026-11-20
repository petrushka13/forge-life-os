# FORGE technical interview guide

Start with the user workflow. The user records an outcome, FORGE checks the request and calculates progression, and the app displays the resulting receipt after a durable local save. Describe your role as initiating, directing, iterating on and validating a Codex-assisted project. Be ready to trace the code and explain which behavior you personally verified.

## Five areas to study

1. **Deterministic progression.** Read `GameEngine` in [GameEngine.swift](Sources/ForgeCore/GameEngine.swift), especially `rewards`, `dailyDelta`, `lifeMMR`, `rank`, and `level`. Then read `GameSession.completeQuest` and `advanceDay` in [GameSession.swift](Sources/ForgeCore/GameSession.swift). Explain where the game applies caps, how the chosen calendar affects settlement, and which inputs need to stay fixed to repeat a calculation.
2. **Durable state and rollback.** Read `AppStore.mutate` in [AppStore.swift](App/AppStore.swift) and `SessionRepository.versions`, `load`, and `save` in [Persistence.swift](App/Persistence.swift). Trace how the old in-memory session survives a failed database commit. A backup-file warning can occur after a successful commit, which has different consequences.
3. **Ancestry and conflict handling.** Read `SessionRevision.heads` in [Backup.swift](Sources/ForgeCore/Backup.swift), `SessionRepository.resolve` in [Persistence.swift](App/Persistence.swift), and `SafeSessionMerge.merge` in [SafeMerge.swift](Sources/ForgeCore/SafeMerge.swift). Compare two forks with only independent review additions to two forks with different ledger entries. Explain why the second case calls for user review.
4. **Evidence intake.** Read `GameSession.importEvidence` in [ExternalEvidence.swift](Sources/ForgeCore/ExternalEvidence.swift), `AppStore.complete` in [AppStore.swift](App/AppStore.swift), and the completion guards in `GameSession.completeQuest`. Follow a focused minute from [extension.js](Integrations/VSCode/extension.js) through [proxy.py](server/proxy.py), then attach it to a quest. Explain the difference between an opaque workspace identifier and a proof of task completion.
5. **Validated backup and recovery.** Read `ForgeBackup.restore` and `validateForStorage` in [Backup.swift](Sources/ForgeCore/Backup.swift), `recoverStorage` and `purgeLocalData` in [AppStore.swift](App/AppStore.swift), and the isolated [persistence smoke](App/PersistenceSmoke.swift). Explain why a failed directory removal after a committed deletion is different from a failed database write. Point to the tested retry path.

## Demo sequence

1. Open a fresh isolated workspace on Mac or an iPhone Simulator. Complete onboarding and show the three daily priorities.
2. Record one result for the main quest and show the balance changes and receipt. Contrast the receipt with an imported minute that has yet to be attached to a completion.
3. Quit the app and reopen the same workspace. Show the completed quest and unchanged earned balance.
4. Export a test backup, change the workspace and restore the earlier snapshot. For a repeatable failure demo, use the persistence smoke fixture and point out its injected write failure and corrupt-row cases.

## Ten questions to practice

| Question | Evidence to use in your answer |
| --- | --- |
| What is deterministic about FORGE? | Fixed scoring inputs, injected time and calendar, and the limits created by new IDs or timestamps. |
| Which part enforces that imported activity cannot award XP? | Import updates the inbox. The explicit completion entry point validates evidence and creates the ledger. |
| How do you prevent a second completion from minting rewards? | Quest status guards, evidence ID/reference checks and reward caps in the session. |
| What happens if a durable write fails at the point of reward? | The candidate is separate, the SwiftData context rolls back, and published progression stays unchanged. |
| What happens if two writers start from the same head? | A later stale save can fail. Close concurrent writes may still create branches, so ancestry and conflict review remain necessary. |
| Why does the merge avoid game-state changes? | Independent notes can be unioned by ID. Independent-looking scores can encode overlapping actions or conflicting policy. |
| Why snapshots instead of replaying the ledger? | Restoring and validating a complete state is straightforward. The cost is storage growth and more data to read as history grows. |
| Which failures does SHA-256 catch, and which does it leave to validation? | It checks payload integrity. Schema, IDs, references and ranges have separate checks. The checksum conveys no author identity. |
| Which guarantees stop at the OS or network boundary? | Local SQLite and SwiftData tests are distinct from system permission, CloudKit delivery and provider behavior. |
| What would you measure before optimizing persistence? | Save and load latency, database and WAL size at known revision counts, and main-thread work during actual UI operations. Read the release benchmark limits before generalizing. |

Read the [engineering decisions](docs/ENGINEERING_DECISIONS.md) and [security notes](docs/SECURITY.md) alongside the code. In an interview, use an observed result or say what remains unverified.

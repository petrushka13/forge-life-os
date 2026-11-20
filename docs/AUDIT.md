# Audit — 2026-10-07

Baseline: ccc21ac, clean main. Checkpoint: checkpoint/2026-10-07-v1. Work branch: production/2026-10-07. Original specification is preserved in MASTER_SPEC.md (70 sections).

Baseline verified this session: 18 Swift core/workflow tests and 3 Python backend tests pass. Swift desktop target compiles with Xcode 27.0 / Swift 6.4. Previous session's device/UI claims are historical evidence only.

Existing usable pieces: five native navigation sections; evidence-gated quest completion; centralized nonlinear levels, ranks, XP and bounded MMR; Coins/rewards; revenue and pipeline; prerequisite skill graph; recovery/rest/streaks/Ghost; weekly/monthly bosses; reviews; local analytics; isolated demo; SwiftData persistence; optional Calendar/Health/GitHub/remote AI adapters.

Critical gaps found:
- CloudKit mutable envelopes delete unknown records and discard duplicate keys; concurrent device changes can overwrite history. No conflict UI or portable restore.
- Export is unversioned and unvalidated; no rotating backup; malformed import not supported.
- Screen Time sources are unembedded templates. UI is timer only; earned access and daily limits absent.
- n8n events persist on server but cannot reach the app. VS Code has only a protocol.
- AI plan validation is action-agnostic; local advice scarcely uses context; failure doesn't expose an actionable fallback proposal.
- Notification is morning only; wake-hour edits don't reschedule it. Health has no wake/consistency provenance; Calendar double-counts overlaps.
- Core writes accept several unsafe/extreme imported values; Keychain reports the wrong error on insertion failure.
- No account-independent signing configuration, deployment/service scripts, privacy manifest, CI or consolidated acceptance/release checklist.

Execution limits: repository write and Git metadata write granted; requested Xcode/Simulator runtime folders not granted. Core builds use a temporary scratch/module cache. UI/signed-device/live cloud/provider checks must be reported as blocked or unverified unless actual subsequent evidence establishes success. No secrets read from user accounts.

Policy for completion: code implemented ≠ build passed ≠ device verified ≠ release accepted. Account-dependent features stay visibly gated. Every section receives an explicit acceptance status; no percent estimates substitute for evidence.

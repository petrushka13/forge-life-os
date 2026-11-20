# Personal release checklist

Version 1.0 / build 1; minimum deployment iOS 17 and macOS 14. Tested host: macOS 26.6.2; simulator: iOS 26.5. Minimum deployment targets were compiled, not tested on that old hardware/OS.

Completed locally:

- [x] Existing work preserved at `9242553` (`checkpoint/2026-10-07-existing-work`); historical `ccc21ac` preserved.
- [x] Central game rules, privacy, atomic settings, idempotent AI/evidence, numeric and date safety.
- [x] Core/backend/companion tests; real Swift HTTP client chain; actual VS Code focused-minute → backend → Swift inbox → explicit Builder quest proof/rewards chain with isolated fixture cleanup.
- [x] Mac and iPhone Simulator native builds; embedded DeviceActivity monitor/report; optional capability code compilation.
- [x] Native Mac manual acceptance plus three actual Mac XCTest workflows, and iPhone Simulator automated workflows with isolated fixtures.
- [x] Mac runner packaging/signing diagnosed and repaired with Xcode local signing; complete app/runner strict verification passed; global OS security unchanged.
- [x] Real disk legacy migration, failed-write rollback, stale-save rejection, quarantine, missing-parent recovery, backup/restore and fixture purge.
- [x] 366-day/10,051-event data volume and 60 durable revisions measured; charts bounded and history paged.
- [x] Backup schema/checksum/size/references/date validation; private permissions; retention; pre-restore preservation.
- [x] Deterministic generator check; ignored local signing configuration; privacy manifest/icon; secret sanity and clean whitespace check.
- [x] README, product/rules/architecture/integrations/roadmap and requirement/capability/security/account documents.

External gates, completed only with the user's account, permission or device:

- [ ] Apple development signing and physical iPhone build/run, trust and real Keychain round trip.
- [ ] HealthKit known samples, permission denial/revocation and overlapping real-device source behavior.
- [ ] Family Controls entitlement, opaque selection, actual shielding, app-closed expiry, midnight, report and emergency override.
- [ ] Calendar permission and known real commitments; notification permission and background delivery/cancellation.
- [ ] Private CloudKit container, same-account Mac/iPhone delivery, offline edits, conflict, logout and account switching.
- [ ] Real read-only GitHub credential/repository, n8n workflow and chosen private HTTPS service.
- [ ] Real provider credential/model, authenticated readiness, actual inference and unavailable-provider fallback.
- [ ] 30 days of real personal use and resulting behavior; synthetic history proves storage/calculation capacity only.

Run `./scripts/verify_release.sh` for reproducible local checks. Run `bash scripts/verify_mac_ui.sh` for three signed, isolated Mac UI workflows, or set `FORGE_UI_MAC=1` to include them in release verification. To run simulator XCTest, set `FORGE_UI_SIMULATOR_UDID` to an installed device ID. Use `./Integrations/VSCode/verify_host.sh` for the actual extension-host fixture. The coupled real-minute chain is `python3 server/verify_host_chain.py --client /absolute/path/to/ForgeIntegrationCheck`; it requires holding its isolated synthetic editor in front for roughly two minutes. Evidence and exact counts are in `ACCEPTANCE_REPORT.md`.

Delivery: local Mac app and Xcode build/run to the personal iPhone. No public hosting, App Store, TestFlight, notarization or external publication was performed. Mac package is Xcode ad-hoc signed with sealed bundle resources and passes strict recursive signature verification. It is not notarized or signed with an Apple identity; distribution and other-machine policy are separate from the verified local XCTest execution.

Rollback: export the latest state; check out a preserved checkpoint in a separate directory and restore a validated compatible backup. Retain pre-restore state. Do not reset this repository or erase live data to roll back code. Start Over retains history; Purge is explicit local deletion. Other devices, exports, backend and cloud retention need separate user action.

Release source identity: use `git rev-parse checkpoint/forge-personal-release^{commit}` after the documented acceptance checkpoint is created. The tag denotes completed local engineering with these explicit external gates, not full signed-device certification.

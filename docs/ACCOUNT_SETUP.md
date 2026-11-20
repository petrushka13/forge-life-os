# Account and permission setup

Core FORGE works offline with manual evidence. These steps configure optional external capabilities; no provider secret belongs in the iPhone or Mac app.

## Personal Apple signing

**Why:** run on a real iPhone and authorize Apple frameworks. Open `FORGE.xcodeproj` → FORGE target → Signing & Capabilities, sign in to your Apple account and select your team. To preserve settings across project regeneration, copy `Config/Local.xcconfig.example` to ignored `Config/Local.xcconfig`; enter `DEVELOPMENT_TEAM` and a registered `FORGE_APP_BUNDLE_ID`. This one ID sets the app identifier and supplies the prefix for `.monitor`, `.report`, and `.UITests`. Select the connected iPhone and Product → Run. Trust the developer certificate on the phone if prompted. No signing credentials are tracked in Git. Verify launch, persistence after relaunch and Keychain save/read/delete on the device.

For a reproducible optional-capability configuration, use the configuration writer after registering your account values:

```sh
python3 scripts/configure_capabilities.py --team YOURTEAMID --bundle com.yourname.FORGE \
  --health --cloud --container iCloud.com.yourname.FORGE \
  --screen-time --app-group group.com.yourname.FORGE
```

Omit switches for unavailable capabilities. The command updates ignored local signing files and preserves unrelated overrides. It migrates the old bundle identity keys to `FORGE_APP_BUNDLE_ID` and does not print account values. Apple development signing still requires a registered team, matching capabilities and a connected device. Build settings alone cannot verify provisioning or device behavior.

To confirm the account-independent configuration contract with synthetic identifiers, run:

```sh
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest -v scripts.test_signing_configuration
```

This test resolves the app, XCTest, monitor and report settings in Xcode from a temporary project copy and verifies that CloudKit extends the baseline Mac network, Calendar and file access entitlements.

## HealthKit

**Why:** read derived health summaries on iPhone. Register HealthKit for the iOS app ID in the Apple Developer account. Run `scripts/configure_capabilities.py` with your team/bundle and `--health` (add other switches only for capabilities you registered); it generates the selected entitlements and compile flags in ignored local files. Build the signed app → Settings → Read Apple Health. Select read permissions on iPhone. Minimum scope: sleep, steps, workouts, body mass, water, read-only. No Health raw data is sent to backend/AI. Verify known samples and missing samples; the app reports metric availability, not an inferred denial. Status: connected only after a successful read; missing samples remain missing.

## macOS local XCTest signing

The former “damaged” runner was an invalid generated bundle caused by `CODE_SIGNING_ALLOWED=NO`, not an unresolved Apple-account requirement. `bash scripts/verify_mac_ui.sh` builds fresh with Xcode **Sign to Run Locally**, verifies complete app/runner signatures and executes isolated workflows. All three product workflows passed with zero failures/skips. No Apple certificate or global security exception was needed. See [signing diagnosis](MAC_UI_SIGNING.md) for exact evidence, warnings and the distinction between local developer execution and notarized distribution. If a future host requires Accessibility/developer-tool permission, grant only the specific application through normal settings and rerun; launch or compilation alone is never passing XCTest evidence.

## Calendar and notifications

**Why:** achievable planning and sparse reminders. Use the Xcode app with usage descriptions. Settings → Read today's calendar → allow access, or deny to retain manual planning. FORGE only reads busy commitments; event titles stay local. Settings → enable sparse reminders → allow or deny notifications. Change wake hour and save to reschedule morning reminders. Verify one morning reminder, cancellation on disable and no repeated at-risk/boss/reward notifications. Signed-device background delivery is a separate gate.

## CloudKit

**Why:** private cross-device delivery. In Apple Developer/Xcode register one private CloudKit container for both app IDs, enable iCloud/CloudKit and use the same Apple account on Mac and iPhone. Set `FORGE_CLOUD_CONTAINER` and `FORGE_CLOUD_ENABLED` in each platform's local compile flags, with matching platform entitlement files. Build both signed apps. Export a backup first; Settings → iCloud → restart. Minimum scope: private app database only. No shared/public profile. Verify a quest completed on one device appears on the other, offline changes survive, concurrent edits are preserved and account logout/unavailable storage yields a local/pending/failed state. CloudKit export completion does not guarantee receipt by another device.

## Screen Time

**Why:** Focus Lock, Earned Access, Daily Limit and private usage report. Requires Apple Family Controls capability for the app, ForgeMonitor and ForgeReport, and entitlement approval where Apple requires it. Register an app group shared by app and monitor. Set `FORGE_APP_GROUP`, use app/monitor/report optional entitlements and add `FORGE_SCREEN_TIME_ENABLED` to iOS flags. Report has no shared app group: usage stays in its private report view. Build the signed iPhone app; Settings → Screen Time / focus setup → Authorize → Choose apps/categories. Selection tokens stay opaque in app-group storage and are excluded from exports. Verify each mode, app-closed expiry, midnight, relaunch, denial/revocation, unshield/re-shield and emergency override. Grant failure must leave Coins unchanged. Status shows authorization; never infer hardware enforcement from a simulator build.

## Private backend and OpenAI

**Why:** remote inference and durable external evidence. Choose a private HTTPS hosting endpoint; deployment is not performed automatically. Follow `server/README.md` to generate separate client and ingest tokens. Provider key and model remain server environment variables. FORGE Settings → endpoint `https://your-private-host/v1/plan` and client token → Save. Client credential is Keychain. Minimum provider access: inference for your selected model. Enable remote backend explicitly, request a plan, preview and accept. Verify authenticated `/ready`, actual inference, malformed/refused responses and local fallback when unavailable. Evidence-only mode needs no OpenAI account.

## GitHub

**Why:** relevant commit references. GitHub → Settings → Developer settings → Personal access tokens → Fine-grained tokens. Limit to the one repository; read-only Contents (and required metadata). Set `owner/repository` and token in FORGE Settings → Save → Fetch GitHub proof. Token is Keychain. Verify known commit identity, wrong token/rate limit/offline and empty repository. Counts do not grant rewards.

## VS Code / n8n

**Why:** duration and automation references. Package/install the private extension using `Integrations/VSCode/README.md`. In a trusted workspace, run FORGE: Configure private evidence backend, enter HTTPS `/v1/events/coding` and dedicated ingest token. Token is SecretStorage. Start explicitly; status bar shows recording and pending counts. Stop cancels delivery, erase clears local activity and credential. Minimum backend scope: ingest only. n8n sends authenticated events to `/v1/events/n8n` with immutable IDs and no source/customer payload. In FORGE Settings → Import evidence; select a relevant record when completing a quest. Verify retry, cursor continuation, server reset and manual fallback. Remote events already delivered require deletion on the private server separately.

# FORGE private activity companion

Opt-in, trusted-workspace coding references. Start explicitly using **FORGE: Start activity recording**. A visible status bar shows recording/paused and pending count. The extension records a salted HMAC workspace identity, event identity, start/end and active minutes. It never reads or stores source text, content changes, keys, full paths, clipboard or customer names. Identity hashing reads the local workspace URI transiently; the raw URI is never persisted or transmitted.

Configure **FORGE: Configure private evidence backend** with HTTPS `/v1/events/coding` and the dedicated ingest token generated from 32 random bytes. Token storage is VS Code SecretStorage. No provider key belongs here. Only loopback HTTP is permitted for local development; redirects are refused.

Recording excludes untrusted workspaces, background windows, idle ticks and long machine-sleep gaps. A minute is a coarse activity signal, never an outcome. Focus changes reset the sampling boundary. The local queue retains at most 10,000 events, visibly reports overflow and retries immutable IDs. Delivery is bounded to five requests per flush. Stop aborts in-flight delivery and leaves the queue for an explicit later flush. Erase stops recording, aborts delivery and removes local pending records and credentials. Already delivered backend events remain on the private server.

```sh
node --test Integrations/VSCode/activity.test.js
./Integrations/VSCode/verify_host.sh
```

The host script launches an isolated VS Code profile and empty trusted test workspace. It records actual host activation, command registration, stop, no-token flush and erase evidence. It never accesses the user's normal VS Code secrets/profile. Unit tests cover endpoint privacy, active sampling, offline same-ID retry, queue overflow and in-flight erase races. The full focused-minute fixture is `python3 server/verify_host_chain.py --client /absolute/path/to/ForgeIntegrationCheck` from the repository root, after building that Swift product. Keep only its isolated `synthetic-acceptance.txt` Extension Development Host window foreground for roughly two minutes. It generates local tokens, exercises actual SecretStorage and the 60-second timer, sends one minute to a temporary loopback backend, then imports and explicitly completes a matching Builder quest through the real Swift client. It checks that source text/full paths never enter the event. Test-only configuration is exposed solely in VS Code Test mode with the explicit fixture environment flag; normal installations expose no fixture API. The harness erases local recording/credentials and never uses your personal profile. Real hosted workspace/account sessions remain separate.

Reproducible private packaging from this directory (Node 20+ and npm):

```sh
npx --yes @vscode/vsce package --allow-missing-repository --out forge-private-activity.vsix
code --install-extension forge-private-activity.vsix
```

Do not publish to Marketplace. `.vscodeignore` excludes tests and development configuration. In FORGE, Settings → Import n8n / VS Code evidence. Select the relevant reference when completing a quest and describe the real outcome. Importing a duration never auto-completes work or earns Coins.

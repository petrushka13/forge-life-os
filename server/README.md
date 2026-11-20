# Private FORGE backend

Python 3.10+ standard library. Core FORGE is offline and never requires this service. Tests use generated tokens, temporary databases and a deterministic provider; they make no OpenAI requests.

```sh
python3 -m unittest discover -s server -v
cd server
# Generate TWO independent secrets from 32 random bytes; put them in a private
# process environment or secret manager, not a terminal transcript or Git.
# Generator: python3 -c 'import secrets; print(secrets.token_urlsafe(32))'
# Set FORGE_PROXY_TOKEN and FORGE_INGEST_TOKEN to the separate generated values.
export FORGE_AI_MODE=disabled
python3 proxy.py
```

Use `server/.env.example` as the variable inventory. The server does not automatically parse or print `.env`. Client and ingest tokens must differ, contain at least 43 characters and pass a diversity check; generate them using the command above, rather than choosing memorable strings. Default binding is `127.0.0.1:8787`; default durable database is `events.sqlite`, created with private permissions. SQLite schema version 1 migrates original events in place. Connections close after every request.

Modes:

- `disabled`: evidence-only; plan requests fail safely and FORGE uses its local planner.
- `local`: deterministic provider for reproducible integration verification.
- `remote`: set server-only `OPENAI_API_KEY` and `OPENAI_MODEL` to your chosen structured-output-capable model.

## Contract

| Endpoint | Token scope | Behavior |
|---|---|---|
| `GET /health` | None | Liveness only; never confirms storage or provider readiness |
| `GET /ready` | Client | Storage/schema readiness and AI mode; missing remote provider configuration returns 503 |
| `POST /v1/plan` | Client | `{action,context}` → `{message,quests}`; five supported actions; strict validation; no scoring fields |
| `POST /v1/events/n8n` | Ingest | Immutable `id,kind,project,timestamp`; supported workflow kinds; same payload retry succeeds; changed payload returns 409 |
| `POST /v1/events/coding` | Ingest | Adds `start,end,minutes`; active minutes remain independent of enclosing wall-clock interval |
| `GET /v1/events?cursor=0` | Client | At most 100 events, `nextCursor,hasMore,serverID`; continue with both saved cursor and serverID |

All protected endpoints use `Authorization: Bearer <scoped-token>`. Timestamps include a timezone and cannot be more than five minutes in the future. Coding intervals are at most two hours, with 1–120 active minutes; active minutes cannot exceed wall-clock duration. Swift apportions active duration across local calendar days, uses maximum density for overlapping reports and never mints rewards from imports. Exact active subintervals are unavailable, so density is an explicit conservative estimate. Companion emits one active minute per eligible tick and retries its original immutable ID.

Changed server database identity resets pagination to zero without discarding the app's evidence inbox; immutable IDs deduplicate replay. Clients publish the cursor with the same local transaction as imported evidence. A bounded client batch imports up to 2,000 events and reports when more remain. Server pages support 10k+ events without returning the entire table.

The implementation uses the [OpenAI Responses API](https://developers.openai.com/api/docs/guides/structured-outputs?api-mode=responses), strict `text.format` JSON schema and `store:false`. It rejects incomplete/refused, malformed and oversized outputs. Server input values are untrusted data. Provider retention policies still apply. Real inference is an account gate; a mock/local provider is not OpenAI verification.

## Limits and operation

16 KB request body, 128 KB provider response, 25-second client socket timeout, 20-second upstream timeout, eight concurrent threads; ten plan and 120 ingest requests per minute per address/scope. Responses disable caching. No request/body/credential logging. SIGTERM/SIGINT stop accepting new requests and wait for bounded active requests to finish. Use a process supervisor with restart-on-failure and private environment files (0600). `/ready` exposes no credentials, paths or provider errors.

For remote iPhone access, choose a private HTTPS host and terminate TLS before the loopback server. Example Caddy configuration after you choose/register a host:

```caddy
{$FORGE_PUBLIC_HOST} {
    reverse_proxy 127.0.0.1:8787
}
```

Keep the backend loopback binding, firewall it from direct public access, protect SSH/admin access and limit reverse-proxy header/body sizes. Localhost HTTP is for Mac development only. No deployment or paid hosting selection is performed automatically.

## Backup / restore / rotation

```sh
python3 manage.py backup events.sqlite private-backup.sqlite
# Stop the service and close database connections before restoring:
python3 manage.py restore private-backup.sqlite events.sqlite --confirm-server-stopped
```

Backups use SQLite's backup API, integrity validation, a self-contained DELETE journal, atomic replacement and 0600 permissions. Restore preserves the previous database as `.pre-restore.sqlite` and rejects invalid schema/integrity or active WAL files. Store backups privately; they include project labels and timestamps. Keep seven daily backups plus a pre-upgrade backup; this retention is an operator policy, not an automatic background service.

Rotate the two tokens independently: generate fresh values, update the server environment, restart, then update FORGE Keychain or companion SecretStorage/n8n credential store. Check `/ready` with the new client credential and verify old credentials return 401. Provider key rotation occurs only on the server. Do not put tokens in URLs or terminal output. Local companion erase does not erase events already delivered to this server.

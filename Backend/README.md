# Trace Studio AI backend

An executable Node 24 service for the iOS `Create with AI` flow. It is **not deployed** and contains no API credentials. Tests use injected providers and never spend OpenAI credits.

## What it does

- Accepts a text prompt and simple/detailed style; returns a printable black-line PNG.
- Keeps the OpenAI API key on the server. The app only knows its HTTPS API URL.
- Verifies the signed StoreKit transaction using Apple's official server library, then fetches its current status from Apple to reject expired/revoked purchases.
- Uses a SHA-256 hash of the original subscription transaction as the quota owner. There is no extra user account/login in this MVP.
- Persists reservations, results and usage in SQLite. Retries with the same request ID and description return the cached image instead of creating another billable request.
- Default allowance: **10 images in a rolling seven-day window**, configurable via `AI_WEEKLY_LIMIT`. This is a development default, not a finalized commercial promise.
- Limits global generation concurrency (2), provider attempts per subscription (5/hour), request sizes and total provider attempts (100/rolling 24h by default). Failed attempts count toward the global cost cap but return the user's generation allowance.
- Keeps replay data for 30 days; cleanup runs at startup, before requests and hourly. Do not log authorization headers, prompts or image bodies in the reverse proxy.

## Configure

1. `npm ci`
2. Use `.env.example` as the configuration checklist. Supply real values through a secret manager or untracked environment file.
3. Download Apple's DER root certificates from [Apple PKI](https://www.apple.com/certificateauthority/) into the configured certificate directory. Use Apple's root certificates, never a certificate supplied by a client.
4. Create an **In-App Purchase** key in App Store Connect. Mount its `.p8` file read-only and configure its key ID and issuer ID. Set bundle/product IDs to the actual app and weekly subscription.
5. Use `APPLE_ENVIRONMENT=Sandbox` for TestFlight/sandbox testing. For production set `Production` and the numeric `APPLE_APP_ID`. Never accept Xcode's locally simulated StoreKit transactions in this backend.
6. Set `OPENAI_API_KEY` server-side and select the model via `OPENAI_IMAGE_MODEL`. Default: `gpt-image-2.5-flare`; image size 1024², medium quality, one PNG per request. Confirm availability and billing in your OpenAI account before launch.
7. Run `node --env-file=.env src/main.mjs` or use the Dockerfile. Put HTTPS in front of the service, set the proxy timeout above 180 seconds, and mount `/data` on persistent storage.
8. In Xcode → Painter target → Build Settings, set `TRACE_API_BASE_URL` to the HTTPS origin, e.g. `https://your-api.example.com`. The app appends `/v1/generations`. Do not add a provider API key to Xcode or Info.plist.

Use **one service instance per SQLite file**. For horizontal scaling, replace the quota ledger with a transactional shared database. Do not launch multiple independent ledgers: that would multiply the per-user and global budgets.

## HTTP contract

```http
POST /v1/generations
Authorization: Bearer <verified StoreKit transaction JWS>
Content-Type: application/json

{"requestId":"550e8400-e29b-41d4-a716-446655440000","prompt":"A sleepy kitten","detail":"simple"}
```

Success: `{ "imageBase64": "…", "remaining": 9, "limit": 10 }`.
Errors: `{ "error": { "code": "quota_exceeded", "message": "…" } }` with a corresponding 4xx/5xx status. A request ID is bound to its subscription and prompt; changing the prompt requires a new ID. A pending request returns 409 and must not be retried with a new ID just to bypass it.

The signed transaction acts as an entitlement bearer credential and must travel over TLS. A copied credential shares the same subscription quota; it does not create a new allowance. For a public launch, consider adding App Attest and server notifications as additional abuse protection.

## Tests

`npm test` covers authentication failure, idempotency, quota exhaustion, parallel reservations, failure refunds, request validation, persistence, daily capacity and provider parameters. `npm run check` checks module syntax. The GitHub Backend workflow runs both.

Live end-to-end tests still need configured OpenAI/App Store credentials and a sandbox purchase. No live image-generation request has been made by this repository setup.

Sources: [Apple server library](https://github.com/apple/app-store-server-library-node), [OpenAI Image API](https://developers.openai.com/api/reference/resources/images/methods/generate).

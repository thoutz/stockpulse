# StockPulse API — api.tryan.app migration

**Date:** June 4, 2026

## DNS record (GoDaddy — you must add this)

Add **one** A record in your tryan.app DNS manager:

| Type | Name | Data | TTL |
|------|------|------|-----|
| **A** | **api** | **45.63.64.79** | 600 |

Do **not** change existing `@` records (they point to your other hosting).

### Verify propagation

```bash
dig +short api.tryan.app
# expect: 45.63.64.79
```

## Server (already deployed)

- Nginx vhost: `/etc/nginx/sites-available/api.tryan.app`
- Proxies `api.tryan.app` → `127.0.0.1:8002` (stockpulse-api)
- HTTP works now if you test with Host header:

```bash
curl -s -H "Host: api.tryan.app" http://45.63.64.79/api/health
```

### TLS (run after DNS resolves)

```bash
ssh mspclientpro 'certbot --nginx -d api.tryan.app --non-interactive --agree-tos --register-unsafely-without-email'
```

Then verify:

```bash
curl -s https://api.tryan.app/api/health
curl -s https://api.tryan.app/api/dashboard | head -c 200
```

## iOS config

In [`ios/Config.xcconfig`](../ios/Config.xcconfig) (do **not** use bare `https://` — `//` is a comment):

```xcconfig
SLASH = /
STOCKPULSE_API_BASE_URL = https:$(SLASH)$(SLASH)api.tryan.app
```

Quoted `"https://..."` also breaks (build can embed `"https:` only). Use `$(SLASH)` instead.

After editing:

```bash
cd ios && xcodegen generate
```

Clean build in Xcode.

## Public API base URL

**`https://api.tryan.app`**

Endpoints unchanged: `/api/dashboard`, `/api/health`, `/api/ai/chat`, etc.

## Deprecated

- `https://frameios.com/stockpulse` — do not use for StockPulse

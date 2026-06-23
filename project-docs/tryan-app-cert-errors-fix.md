# tryan.app cert errors — diagnosis and fix

**Date:** June 16, 2026

## Symptom

Browser or curl shows TLS/SSL errors when opening `https://tryan.app` or `https://api.tryan.app` from the office network.

## Root cause (two layers)

### 1. Server — already healthy

On VPS `45.63.64.79` (`mspclientpro`):

| Hostname | Let's Encrypt cert | Expires |
|----------|-------------------|---------|
| `tryan.app`, `www.tryan.app` | Valid | 2026-09-14 |
| `api.tryan.app` | Valid | 2026-09-14 |

- Nginx vhosts: `/etc/nginx/sites-available/tryan.app`, `api.tryan.app`
- Web root: `/var/www/tryan.app`
- API proxy: `127.0.0.1:8002`
- `certbot.timer` enabled (renews twice daily)

External HTTPS check (outside office network) succeeds:

```bash
curl -s https://tryan.app | head
curl -s https://api.tryan.app/api/health
```

### 2. Office SonicWall — blocks `tryan.app`

From the dev network, HTTP returns a **SonicWall NSA block page**:

- Policy: **CFS Default Policy**
- Reason: **Phishing and Other Frauds**
- HTTPS: TLS handshake **reset by peer** (browser shows cert/SSL error)

This is **not** a missing or invalid certificate on the server. The firewall intercepts/resets traffic before nginx completes the handshake.

`frameios.com` on the same IP works because it is not categorized/blocked.

## Server changes applied

1. Replaced Certbot `return 404` HTTP blocks with:
   - `/.well-known/acme-challenge/` → `/var/www/letsencrypt` (renewals)
   - All other HTTP → `301` to HTTPS
2. **Fixed incomplete TLS chain (Windows / some browsers):** Certbot was serving `EE ← YRn ← Root YR` (3 certs) without the **ISRG Root X1 cross-sign**, which newer Let's Encrypt YR intermediates require for clients that don't yet trust Root YR. Built compatible fullchains at `/etc/letsencrypt/compatible/{tryan.app,api.tryan.app}/fullchain.pem` and pointed nginx at them. Renewal hook: `/etc/letsencrypt/renewal-hooks/deploy/compatible-chain.sh` (see `web/deploy/enable-compatible-tls-chain.sh`).
3. Set `tryan.app` as nginx `default_server` on 443 (was falling back to `ais.harbormasterpro.com` cert).
4. Reloaded nginx.
5. Redeployed latest web build to `/var/www/tryan.app/`.
6. Updated repo templates:
   - `web/deploy/nginx-tryan.app.conf`
   - `server/stockpulse-api/deploy/nginx-api.tryan.app.conf`

## Fix for office / SonicWall users

On the SonicWall (or ask network admin):

1. **Content Filter → Allow list** — add:
   - `tryan.app`
   - `www.tryan.app`
   - `api.tryan.app`
2. Or **recategorize** the domain via [SonicWall CFS support](http://cfssupport.sonicwall.com/) (false positive: personal finance/stock dashboard, not phishing).
3. **Verify** after whitelist:

```bash
curl -sI https://tryan.app
curl -s https://api.tryan.app/api/health
```

4. **Quick test without firewall:** phone on cellular (Wi‑Fi off) — site should load with valid padlock.

## DNS (unchanged, M365-safe)

| Type | Name | Value |
|------|------|-------|
| A | `@` | `45.63.64.79` |
| A | `api` | `45.63.64.79` |
| CNAME | `www` | `@` |

Do not remove MX, SPF, autodiscover, sip, or Teams SRV records.

## Re-issue certs (only if expired)

```bash
ssh mspclientpro
certbot --nginx -d tryan.app -d www.tryan.app --non-interactive --agree-tos --register-unsafely-without-email
certbot --nginx -d api.tryan.app --non-interactive --agree-tos --register-unsafely-without-email
nginx -t && systemctl reload nginx
```

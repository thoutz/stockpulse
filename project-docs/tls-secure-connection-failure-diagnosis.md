# TLS / secure connection failure — diagnosis

**Date:** June 9, 2026

## Symptom

iOS app shows: *"An SSL error has occurred. A secure connection to the server could not be established."* (URLError -1200) when calling `https://api.tryan.app`.

## What we checked

### 1. iOS app config — OK

- [`ios/Config.xcconfig`](../ios/Config.xcconfig) uses the correct xcconfig escape:

```xcconfig
SLASH = /
STOCKPULSE_API_BASE_URL = https:$(SLASH)$(SLASH)api.tryan.app
```

- Built app `Info.plist` embeds: `https://api.tryan.app` (verified after `xcodebuild`).

### 2. Server TLS — OK

On VPS `45.63.64.79` (`mspclientpro`):

- Nginx vhost `/etc/nginx/sites-available/api.tryan.app` has Certbot-managed TLS.
- Let's Encrypt cert for `api.tryan.app` valid until **2026-09-02**.
- From the server: `curl https://api.tryan.app/api/health` → `{"status":"ok","service":"stockpulse-api"}`.
- UFW allows ports 80 and 443.

**TLS on the server is correctly configured.**

### 3. Network / firewall — root cause

From the dev machine (same network as Xcode Simulator):

| URL | Result |
|-----|--------|
| `https://api.tryan.app/api/health` | TLS handshake **reset by peer** (curl exit 35) |
| `http://api.tryan.app/api/health` | **403 SonicWall** — "Web Site Blocked", policy *CFS Default Policy*, reason *Phishing and Other Frauds* |
| `https://frameios.com/stockpulse/api/health` | **Works** — same IP, different hostname |

Both hostnames resolve to `45.63.64.79`. The firewall (SonicWall NSA) is **blocking or breaking TLS specifically for `api.tryan.app`**, not a missing certificate on the server.

The iOS Simulator uses the Mac's network stack, so it hits the same block and shows the TLS error.

## Fix options

### A. Network whitelist (recommended)

On the SonicWall / corporate firewall:

- Allow or recategorize **`api.tryan.app`** (and optionally IP `45.63.64.79`).
- Or test the app on **cellular** / home Wi‑Fi without content filtering.

### B. Verify after whitelist

```bash
curl -s https://api.tryan.app/api/health
# expect: {"status":"ok","service":"stockpulse-api"}
```

Then in Xcode: **Product → Clean Build Folder**, run again.

### C. Do not revert to bare `https://` in xcconfig

Writing `STOCKPULSE_API_BASE_URL = https://api.tryan.app` in `.xcconfig` truncates at `//` (comment) and embeds `https:` only — a separate bug that prevents API calls entirely.

## Not the cause

- Missing certbot / nginx TLS on server (already done).
- Wrong iOS bundle URL (build verified correct).
- App Transport Security exceptions (not needed; HTTPS is used throughout).

# GitHub Initial Backup

**Date:** June 23, 2026  
**Remote:** `git@github.com:thoutz/stockpulse.git`

## What was done

1. Initialized a new git repository at the project root.
2. Added a root `.gitignore` covering secrets, build artifacts, and local IDE folders.
3. Created initial commit on `main` (348 files).
4. Pushed to GitHub and set upstream tracking.

## Excluded from the repo (not committed)

- `server/stockpulse-api/.env` — API keys and secrets
- `node_modules/`, `.venv/`, `__pycache__/`, `.pytest_cache/`
- `ios/Config.xcconfig`, `ios/Signing.xcconfig` — local signing config
- `.cursor/`, `.claude/`, `.DS_Store`

## Included safely

- `server/stockpulse-api/.env.example` — template without secrets
- `ios/Config.xcconfig.example`, `ios/Signing.xcconfig.example`

## Future pushes

From the project root:

```bash
git add -A
git commit -m "Your message"
git push
```

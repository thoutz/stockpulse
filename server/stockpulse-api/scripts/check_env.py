#!/usr/bin/env python3
"""Validate required environment variables before deploy."""

from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from config import get_settings  # noqa: E402


def main() -> int:
    settings = get_settings()
    errors: list[str] = []
    warnings: list[str] = []

    if not settings.database_url.strip():
        errors.append("DATABASE_URL is empty")
    if not settings.massive_api_key.strip():
        warnings.append("MASSIVE_API_KEY missing — daily/minute bars will not ingest")
    if not settings.finnhub_api_key.strip():
        warnings.append("FINNHUB_API_KEY missing — Monitor live quotes disabled")
    if not settings.groq_api_key.strip():
        warnings.append("GROQ_API_KEY missing — pulse reports and chat disabled")
    if not settings.alpaca_api_key.strip() or not settings.alpaca_secret_key.strip():
        warnings.append("ALPACA_API_KEY missing — Trade tab disabled (run scripts/verify_alpaca.py)")

    for w in warnings:
        print(f"WARN: {w}")
    for e in errors:
        print(f"ERROR: {e}")

    if errors:
        return 1
    print("Environment check passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

#!/usr/bin/env python3
"""Verify hybrid ticker search against a local Postgres database."""

from __future__ import annotations

import asyncio
import os
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from database import SessionLocal, init_db  # noqa: E402
from scripts.seed_tickers import load_seed_tickers, upsert_tickers  # noqa: E402
from services.ticker_search import hybrid_search_tickers, search_tickers_local  # noqa: E402


async def main() -> None:
    db_url = os.environ.get("DATABASE_URL")
    if not db_url:
        print("Set DATABASE_URL to run local verification.")
        raise SystemExit(1)

    tickers = await load_seed_tickers()
    count = await upsert_tickers(tickers)
    print(f"Loaded {count} tickers.")

    async with SessionLocal() as session:
        local = await search_tickers_local(session, "apple", limit=15)
        assert local, "Expected local Postgres matches for 'apple'"
        assert any(r["symbol"] == "AAPL" for r in local), local
        print(f"Local search 'apple': {[r['symbol'] for r in local[:5]]}")

        hybrid = await hybrid_search_tickers(session, "apple", limit=15)
        assert hybrid, "Expected hybrid search results for 'apple'"
        assert any(r["symbol"] == "AAPL" for r in hybrid), hybrid
        print(f"Hybrid search 'apple': {[r['symbol'] for r in hybrid[:5]]}")

    print("Search verification passed.")


if __name__ == "__main__":
    asyncio.run(main())

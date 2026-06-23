#!/usr/bin/env python3
"""Propose catalyst events from upcoming earnings + sector peers."""

from __future__ import annotations

import argparse
import asyncio
import sys
from datetime import datetime, timedelta, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from sqlalchemy import select  # noqa: E402

from config import get_settings  # noqa: E402
from database import SessionLocal, init_db  # noqa: E402
from models.db_models import CatalystEvent, CatalystRipple  # noqa: E402
from services.alphavantage_client import AlphaVantageClient  # noqa: E402
from services.sector_catalog import SECTOR_BY_ID, sector_for_symbol  # noqa: E402
from services.tracked import get_tracked_symbols  # noqa: E402


def _peer_ripples(ticker: str) -> list[tuple[str, str]]:
    sector = sector_for_symbol(ticker)
    if not sector:
        return []
    return [
        (sym, f"{sector.name} peer")
        for sym in sector.tickers
        if sym.upper() != ticker.upper()
    ]


async def discover(*, apply: bool) -> None:
    settings = get_settings()
    tracked = set()
    async with SessionLocal() as session:
        tracked = {s.upper() for s in await get_tracked_symbols(session)}

    proposals: list[dict] = []
    today = datetime.now(timezone.utc).date()
    cutoff = today + timedelta(days=14)

    client = AlphaVantageClient()
    if client.configured:
        rows = await client.fetch_earnings_calendar()
        for row in rows:
            sym = row.get("symbol") or ""
            if sym not in tracked:
                continue
            rd = row.get("report_date") or ""
            try:
                d = datetime.strptime(rd, "%Y-%m-%d").date()
            except ValueError:
                continue
            if d < today or d > cutoff:
                continue
            ripples = _peer_ripples(sym)
            if not ripples:
                continue
            proposals.append(
                {
                    "ticker": sym,
                    "name": row.get("name") or sym,
                    "event_name": f"Earnings report ({rd})",
                    "event_date": rd,
                    "ripples": ripples,
                    "source": "alphavantage",
                }
            )
    else:
        print("Alpha Vantage not configured — no earnings calendar proposals")

    if not proposals:
        print("No proposals in the next 14 days for tracked tickers")
        return

    print(f"Found {len(proposals)} proposal(s):")
    for p in proposals:
        peers = ", ".join(t for t, _ in p["ripples"])
        print(f"  {p['ticker']} on {p['event_date']}: {p['event_name']} → ripples: {peers}")

    if not apply:
        print("\nDry run — pass --apply to insert inactive events")
        return

    async with SessionLocal() as session:
        for p in proposals:
            existing = (
                await session.execute(
                    select(CatalystEvent)
                    .where(CatalystEvent.ticker == p["ticker"], CatalystEvent.event_date == p["event_date"])
                    .limit(1)
                )
            ).scalar_one_or_none()
            if existing:
                print(f"Skip existing {p['ticker']} {p['event_date']}")
                continue
            event = CatalystEvent(
                ticker=p["ticker"],
                name=p["name"][:128],
                event_name=p["event_name"][:256],
                event_date=p["event_date"],
                active=True,
                source=p["source"],
            )
            session.add(event)
            await session.flush()
            for ripple_ticker, description in p["ripples"]:
                session.add(
                    CatalystRipple(
                        catalyst_event_id=event.id,
                        ripple_ticker=ripple_ticker,
                        description=description,
                    )
                )
            print(f"Inserted {p['ticker']} {p['event_date']}")
        await session.commit()


async def main() -> None:
    parser = argparse.ArgumentParser(description="Discover catalyst events from earnings calendar")
    parser.add_argument("--apply", action="store_true", help="Insert proposals into catalyst_events")
    args = parser.parse_args()
    await init_db()
    await discover(apply=args.apply)


if __name__ == "__main__":
    asyncio.run(main())

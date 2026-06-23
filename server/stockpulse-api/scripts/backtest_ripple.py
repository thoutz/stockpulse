#!/usr/bin/env python3
"""Backtest ripple pairs on historical daily bars; update hit_rate on catalyst_ripples."""

from __future__ import annotations

import asyncio
import sys
from datetime import datetime, timedelta, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from sqlalchemy import select  # noqa: E402

from database import SessionLocal, init_db  # noqa: E402
from models.db_models import BarDaily, CatalystEvent, CatalystRipple  # noqa: E402
from services.ripple_engine import Bar, post_event_change, verdict  # noqa: E402


async def _bars_for(session, symbol: str, days: int = 400) -> list[Bar]:
    cutoff = datetime.now(timezone.utc) - timedelta(days=days)
    result = await session.execute(
        select(BarDaily)
        .where(BarDaily.symbol == symbol.upper(), BarDaily.bar_date >= cutoff)
        .order_by(BarDaily.bar_date)
    )
    return [Bar(date=r.bar_date, close=r.close) for r in result.scalars().all()]


async def main() -> None:
    await init_db()
    async with SessionLocal() as session:
        events = (await session.execute(select(CatalystEvent).where(CatalystEvent.active.is_(True)))).scalars().all()
        if not events:
            print("No catalyst events — run scripts/seed_catalysts.py first")
            return

        for event in events:
            cat_hist = await _bars_for(session, event.ticker)
            if len(cat_hist) < 5:
                print(f"Skip {event.ticker}: insufficient bars")
                continue
            event_dt = datetime.strptime(event.event_date, "%Y-%m-%d").replace(tzinfo=timezone.utc)
            cat_post = post_event_change(cat_hist, event_dt)

            ripples = (
                await session.execute(
                    select(CatalystRipple).where(CatalystRipple.catalyst_event_id == event.id)
                )
            ).scalars().all()

            hits = 0
            total = 0
            for rip in ripples:
                rip_hist = await _bars_for(session, rip.ripple_ticker)
                if len(rip_hist) < 5:
                    continue
                rip_post = post_event_change(rip_hist, event_dt)
                v = verdict(cat_post, rip_post)
                rip.avg_post_pct = round(rip_post, 2)
                total += 1
                if v in ("CONFIRMED", "FORMING"):
                    hits += 1
                print(
                    f"  {event.ticker}→{rip.ripple_ticker}: cat {cat_post:+.1f}%, "
                    f"rip {rip_post:+.1f}% → {v}"
                )

            if total:
                rate = hits / total * 100
                event.confidence_score = round(rate, 1)
                print(f"{event.ticker} confidence: {rate:.0f}% ({hits}/{total} pairs confirmed/forming)")

        await session.commit()
    print("Backtest complete")


if __name__ == "__main__":
    asyncio.run(main())

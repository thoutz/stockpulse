#!/usr/bin/env python3
"""Recompute change_5m_pct / change_15m_pct on latest snapshots from persisted quote ticks."""

from __future__ import annotations

import asyncio
import sys
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from sqlalchemy import select  # noqa: E402

from database import SessionLocal, init_db  # noqa: E402
from models.db_models import Snapshot  # noqa: E402
from services.quote_history import history_for, load_quote_history_from_db, pct_change, price_at_minutes_ago  # noqa: E402


async def main() -> None:
    await init_db()
    await load_quote_history_from_db()

    async with SessionLocal() as session:
        result = await session.execute(select(Snapshot).order_by(Snapshot.captured_at.desc()).limit(200))
        seen: set[str] = set()
        updated = 0
        for snap in result.scalars().all():
            if snap.symbol in seen:
                continue
            seen.add(snap.symbol)
            hist = history_for(snap.symbol)
            if not hist:
                continue
            m5 = pct_change(snap.price, price_at_minutes_ago(hist, 5))
            m15 = pct_change(snap.price, price_at_minutes_ago(hist, 15))
            if m5 != snap.change_5m_pct or m15 != snap.change_15m_pct:
                snap.change_5m_pct = m5
                snap.change_15m_pct = m15
                updated += 1
        await session.commit()
    print(f"Updated {updated} snapshot rows at {datetime.now(timezone.utc).isoformat()}")


if __name__ == "__main__":
    asyncio.run(main())

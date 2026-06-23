#!/usr/bin/env python3
"""Build session intelligence rows for a pulse slot (manual run or catch-up)."""

from __future__ import annotations

import argparse
import asyncio
import re
import sys
from collections import Counter
from datetime import datetime
from pathlib import Path
from zoneinfo import ZoneInfo

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from database import SessionLocal, init_db  # noqa: E402
from services.session_intelligence import (  # noqa: E402
    VALID_SLOTS,
    build_session_intelligence,
    fetch_intelligence_rows,
)

ET = ZoneInfo("America/New_York")
DATE_RE = re.compile(r"^\d{4}-\d{2}-\d{2}$")


def _today_et() -> str:
    return datetime.now(ET).strftime("%Y-%m-%d")


def _parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Build persisted session intelligence for a pulse slot.",
    )
    parser.add_argument(
        "--slot",
        required=True,
        choices=sorted(VALID_SLOTS),
        help="Pulse slot: open (10:00 ET), midday (13:00 ET), close (16:00 ET)",
    )
    parser.add_argument(
        "--date",
        default=None,
        help="Session date YYYY-MM-DD (default: today in America/New_York)",
    )
    return parser.parse_args()


async def main() -> int:
    args = _parse_args()
    session_date = args.date or _today_et()
    if not DATE_RE.match(session_date):
        print("ERROR: --date must be YYYY-MM-DD", file=sys.stderr)
        return 1

    await init_db()
    async with SessionLocal() as session:
        count = await build_session_intelligence(session, args.slot, session_date=session_date)
        await session.commit()
        rows = await fetch_intelligence_rows(session, session_date, slot=args.slot)

    categories = Counter(r.category for r in rows)
    print(f"Built {count} row(s) for {session_date}/{args.slot}")
    if categories:
        print("Categories:")
        for cat, n in sorted(categories.items()):
            print(f"  {cat}: {n}")
    for row in rows[:5]:
        print(f"  - [{row.category}] {row.summary_text[:120]}")
    if len(rows) > 5:
        print(f"  ... and {len(rows) - 5} more")
    return 0


if __name__ == "__main__":
    raise SystemExit(asyncio.run(main()))

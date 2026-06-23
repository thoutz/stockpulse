#!/usr/bin/env python3
"""Seed catalyst_events from built-in ripple_engine definitions."""

from __future__ import annotations

import asyncio
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from database import SessionLocal, init_db  # noqa: E402
from services.catalyst_catalog import seed_builtin_catalysts  # noqa: E402


async def main() -> None:
    await init_db()
    async with SessionLocal() as session:
        n = await seed_builtin_catalysts(session)
        await session.commit()
    print(f"Seeded {n} catalyst event(s)")


if __name__ == "__main__":
    asyncio.run(main())

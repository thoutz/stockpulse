#!/usr/bin/env python3
"""Run one auto-trade cycle (paper, market hours). Usage: ./venv/bin/python scripts/run_auto_trade.py"""

from __future__ import annotations

import asyncio
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from services.trading_jobs import run_auto_trade_cycle  # noqa: E402


async def main() -> None:
    result = await run_auto_trade_cycle()
    print(result)


if __name__ == "__main__":
    asyncio.run(main())

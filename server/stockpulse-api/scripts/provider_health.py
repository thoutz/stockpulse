#!/usr/bin/env python3
"""Print provider health report (same as GET /api/health/providers)."""

from __future__ import annotations

import asyncio
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from database import init_db  # noqa: E402
from services.provider_health import run_provider_health_check  # noqa: E402


async def main() -> None:
    await init_db()
    report = await run_provider_health_check()
    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    asyncio.run(main())

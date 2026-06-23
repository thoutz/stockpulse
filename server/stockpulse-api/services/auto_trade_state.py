"""Persist and expose last auto-trade cycle result."""

from __future__ import annotations

import json
import logging
from datetime import datetime, timedelta
from pathlib import Path
from typing import Any
from zoneinfo import ZoneInfo

logger = logging.getLogger(__name__)

ET = ZoneInfo("America/New_York")
_DATA_DIR = Path(__file__).resolve().parents[1] / "data"
_STATE_FILE = _DATA_DIR / "last_auto_trade_run.json"
# Backup cron slots if pulse-chained auto-trade did not run (close slot is 16:05 — last in-market minute).
_SCHEDULE = ((10, 15), (13, 15), (16, 5))


def _ensure_data_dir() -> None:
    _DATA_DIR.mkdir(parents=True, exist_ok=True)


def next_auto_trade_run_at() -> datetime | None:
    """Next scheduled cron slot (10:15 / 13:15 / 16:15 ET) on a weekday."""
    now = datetime.now(ET)
    for day_offset in range(8):
        day = now.date() + timedelta(days=day_offset)
        if day.weekday() >= 5:
            continue
        for hour, minute in _SCHEDULE:
            candidate = datetime(
                day.year, day.month, day.day, hour, minute, tzinfo=ET
            )
            if candidate > now:
                return candidate
    return None


def record_auto_trade_run(result: dict[str, Any]) -> dict[str, Any]:
    """Save cycle outcome and return normalized payload for API clients."""
    _ensure_data_dir()
    executed_raw = result.get("executed")
    try:
        executed = int(executed_raw) if executed_raw is not None else 0
    except (TypeError, ValueError):
        executed = 0

    skipped_raw = result.get("skipped_symbols") or []
    if isinstance(skipped_raw, str):
        skipped_symbols = [s.strip() for s in skipped_raw.split(",") if s.strip()]
    else:
        skipped_symbols = list(skipped_raw)

    payload: dict[str, Any] = {
        "at": datetime.now(tz=ET).isoformat(),
        "status": str(result.get("status", "unknown")),
        "reason": result.get("reason"),
        "executed": executed,
        "skipped_symbols": skipped_symbols,
    }
    try:
        _STATE_FILE.write_text(json.dumps(payload, indent=2), encoding="utf-8")
    except OSError:
        logger.exception("Failed to write auto-trade state file")
    return payload


def get_last_auto_trade_run() -> dict[str, Any] | None:
    if not _STATE_FILE.is_file():
        return None
    try:
        data = json.loads(_STATE_FILE.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        logger.exception("Failed to read auto-trade state file")
        return None
    if not isinstance(data, dict):
        return None
    return data


def auto_trade_status_extras() -> dict[str, Any]:
    """Fields merged into GET /api/trading/status."""
    last = get_last_auto_trade_run()
    nxt = next_auto_trade_run_at()
    return {
        "last_auto_trade_run": last,
        "next_auto_trade_run_at": nxt.isoformat() if nxt else None,
        "auto_trade_schedule_et": ["after each pulse", "10:15", "13:15", "16:05"],
    }

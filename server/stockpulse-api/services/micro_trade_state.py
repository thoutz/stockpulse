"""Persist last micro-trade cycle for Trade tab / status API."""

from __future__ import annotations

import json
import logging
from datetime import datetime
from pathlib import Path
from typing import Any
from zoneinfo import ZoneInfo

logger = logging.getLogger(__name__)

ET = ZoneInfo("America/New_York")
_DATA_DIR = Path(__file__).resolve().parents[1] / "data"
_STATE_FILE = _DATA_DIR / "last_micro_trade_run.json"


def _ensure_data_dir() -> None:
    _DATA_DIR.mkdir(parents=True, exist_ok=True)


def record_micro_trade_run(result: dict[str, Any]) -> dict[str, Any]:
    _ensure_data_dir()

    def _int(key: str) -> int:
        raw = result.get(key)
        try:
            return int(raw) if raw is not None else 0
        except (TypeError, ValueError):
            return 0

    payload: dict[str, Any] = {
        "at": datetime.now(tz=ET).isoformat(),
        "status": str(result.get("status", "unknown")),
        "reason": result.get("reason"),
        "entries": _int("entries"),
        "exits": _int("exits"),
        "skipped_symbols": list(result.get("skipped_symbols") or []),
    }
    try:
        _STATE_FILE.write_text(json.dumps(payload, indent=2), encoding="utf-8")
    except OSError:
        logger.exception("Failed to write micro-trade state file")
    return payload


def get_last_micro_trade_run() -> dict[str, Any] | None:
    if not _STATE_FILE.is_file():
        return None
    try:
        data = json.loads(_STATE_FILE.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        logger.exception("Failed to read micro-trade state file")
        return None
    return data if isinstance(data, dict) else None


def micro_trade_status_extras() -> dict[str, Any]:
    from services.micro_trading import micro_trading_config_payload

    return {
        "last_micro_trade_run": get_last_micro_trade_run(),
        **micro_trading_config_payload(),
    }

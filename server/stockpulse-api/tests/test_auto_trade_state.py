"""Tests for auto-trade run state persistence."""

from __future__ import annotations

import json
from datetime import datetime
from zoneinfo import ZoneInfo

import services.auto_trade_state as state


def test_record_and_read_last_run(tmp_path, monkeypatch):
    monkeypatch.setattr(state, "_STATE_FILE", tmp_path / "last.json")
    monkeypatch.setattr(state, "_DATA_DIR", tmp_path)

    saved = state.record_auto_trade_run(
        {
            "status": "skipped",
            "reason": "market_closed",
            "skipped_symbols": ["AAPL", "NVDA"],
        }
    )
    assert saved["status"] == "skipped"
    assert saved["reason"] == "market_closed"
    assert saved["executed"] == 0
    assert saved["skipped_symbols"] == ["AAPL", "NVDA"]

    loaded = state.get_last_auto_trade_run()
    assert loaded is not None
    assert loaded["status"] == "skipped"
    assert json.loads((tmp_path / "last.json").read_text())["executed"] == 0


def test_next_auto_trade_run_weekday(monkeypatch):
    class FixedDatetime(datetime):
        @classmethod
        def now(cls, tz=None):
            return cls(2026, 6, 17, 9, 0, tzinfo=tz or ZoneInfo("America/New_York"))

    import datetime as dt

    monkeypatch.setattr(dt, "datetime", FixedDatetime)
    nxt = state.next_auto_trade_run_at()
    assert nxt is not None
    assert nxt.hour == 10 and nxt.minute == 15


def test_status_extras_includes_schedule():
    extras = state.auto_trade_status_extras()
    assert extras["auto_trade_schedule_et"] == ["10:15", "13:15", "16:15"]
    assert "last_auto_trade_run" in extras
    assert "next_auto_trade_run_at" in extras

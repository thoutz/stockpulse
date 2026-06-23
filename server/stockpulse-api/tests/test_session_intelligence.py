from datetime import datetime, timezone

import pytest

from models.db_models import SessionIntelligence
from services.session_intelligence import (
    VALID_SLOTS,
    _observation_cutoff,
    build_session_intelligence,
    format_intelligence_for_packet,
)


def _row(
    *,
    slot: str = "open",
    category: str,
    summary_text: str,
    session_date: str = "2026-06-13",
) -> SessionIntelligence:
    return SessionIntelligence(
        session_date=session_date,
        slot=slot,
        category=category,
        summary_text=summary_text,
    )


def test_valid_slots():
    assert VALID_SLOTS == frozenset({"open", "midday", "close"})


def test_observation_cutoff_open():
    cutoff = _observation_cutoff("open", "2026-06-13")
    assert cutoff.hour == 9 and cutoff.minute == 30


def test_observation_cutoff_midday():
    cutoff = _observation_cutoff("midday", "2026-06-13")
    assert cutoff.hour == 10 and cutoff.minute == 0


def test_format_intelligence_for_packet_orders_categories():
    rows = [
        _row(category="ripple", summary_text="NVDA→AMD: CONFIRMED"),
        _row(category="focus", summary_text="Monitor focus: space"),
        _row(category="intraday_mover", summary_text="RKLB [hot]: 5m +2.1%"),
    ]
    lines = format_intelligence_for_packet(rows, "open")
    assert lines[0].startswith("- [focus]")
    assert any("[intraday_mover]" in line for line in lines)
    assert any("[ripple]" in line for line in lines)


def test_format_intelligence_for_packet_empty_slot():
    rows = [_row(slot="midday", category="focus", summary_text="ignored")]
    lines = format_intelligence_for_packet(rows, "open")
    assert lines == ["No pre-computed session intelligence for this slot yet."]


def test_format_intelligence_for_packet_unknown_category_appended():
    rows = [_row(category="custom_metric", summary_text="Custom row")]
    lines = format_intelligence_for_packet(rows, "open")
    assert lines == ["- [custom_metric] Custom row"]


@pytest.mark.asyncio
async def test_build_session_intelligence_rejects_unknown_slot():
    with pytest.raises(ValueError, match="Unknown slot"):
        await build_session_intelligence(None, "invalid")  # type: ignore[arg-type]

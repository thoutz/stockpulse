"""Prevent duplicate trade proposals for the same symbol within a cooldown window."""

from __future__ import annotations

from datetime import datetime, timedelta, timezone

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from config import get_settings
from models.db_models import TradeDecisionLog
from services.risk_engine import TradeIntent

_ACTIVE_STATUSES = frozenset({"proposed", "submitted", "filled"})


async def symbols_with_recent_activity(
    session: AsyncSession,
    *,
    hours: float | None = None,
) -> set[str]:
    settings = get_settings()
    window = hours if hours is not None else settings.propose_cooldown_hours
    cutoff = datetime.now(timezone.utc) - timedelta(hours=window)
    result = await session.execute(
        select(TradeDecisionLog.symbol).where(
            TradeDecisionLog.created_at >= cutoff,
            TradeDecisionLog.status.in_(tuple(_ACTIVE_STATUSES)),
        )
    )
    return {row.upper() for (row,) in result.all() if row}


async def filter_new_intents(
    session: AsyncSession,
    intents: list[TradeIntent],
    *,
    cooldown_hours: float | None = None,
) -> tuple[list[TradeIntent], list[str]]:
    """Drop intents for symbols that already have a recent proposal or fill."""
    blocked = await symbols_with_recent_activity(session, hours=cooldown_hours)
    kept: list[TradeIntent] = []
    skipped: list[str] = []
    for intent in intents:
        sym = intent.symbol.upper()
        if sym in blocked:
            skipped.append(sym)
            continue
        kept.append(intent)
        blocked.add(sym)
    return kept, skipped

"""Persist Finnhub quote ticks so 5m/15m windows survive server restarts."""

from __future__ import annotations

import logging
from collections import deque
from datetime import datetime, timedelta, timezone

from sqlalchemy import delete, select
from sqlalchemy.ext.asyncio import AsyncSession

from database import SessionLocal
from models.db_models import QuoteTick

logger = logging.getLogger(__name__)

RETENTION_HOURS = 24
MAX_DEQUE_LEN = 120

_quote_history: dict[str, deque[tuple[datetime, float]]] = {}


def history_for(symbol: str) -> deque[tuple[datetime, float]]:
    sym = symbol.upper()
    if sym not in _quote_history:
        _quote_history[sym] = deque(maxlen=MAX_DEQUE_LEN)
    return _quote_history[sym]


def price_at_minutes_ago(history: deque[tuple[datetime, float]], minutes: int) -> float | None:
    if not history:
        return None
    now = datetime.now(timezone.utc)
    target = now.timestamp() - minutes * 60
    best: tuple[datetime, float] | None = None
    for ts, price in history:
        if ts.timestamp() <= target + 30:
            best = (ts, price)
    if best:
        return best[1]
    return history[0][1] if history else None


def pct_change(current: float, past_price: float | None) -> float | None:
    if past_price is None or past_price <= 0:
        return None
    return (current - past_price) / past_price * 100


async def load_quote_history_from_db() -> None:
    cutoff = datetime.now(timezone.utc) - timedelta(hours=RETENTION_HOURS)
    rows: list[QuoteTick] = []
    async with SessionLocal() as session:
        result = await session.execute(
            select(QuoteTick)
            .where(QuoteTick.captured_at >= cutoff)
            .order_by(QuoteTick.symbol, QuoteTick.captured_at)
        )
        rows = list(result.scalars().all())
    _quote_history.clear()
    for row in rows:
        ts = row.captured_at
        if ts.tzinfo is None:
            ts = ts.replace(tzinfo=timezone.utc)
        history_for(row.symbol).append((ts, row.price))
    logger.info("Loaded quote history for %d symbols (%d ticks)", len(_quote_history), len(rows))


async def record_quote_tick(session: AsyncSession, symbol: str, price: float, captured_at: datetime) -> None:
    sym = symbol.upper()
    history_for(sym).append((captured_at, price))
    session.add(QuoteTick(symbol=sym, price=price, captured_at=captured_at))


async def prune_old_quote_ticks(session: AsyncSession) -> int:
    cutoff = datetime.now(timezone.utc) - timedelta(hours=RETENTION_HOURS)
    result = await session.execute(delete(QuoteTick).where(QuoteTick.captured_at < cutoff))
    return result.rowcount or 0

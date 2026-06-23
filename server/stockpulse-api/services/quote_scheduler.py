from __future__ import annotations

import logging
from datetime import datetime, timezone

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from database import SessionLocal
from models.db_models import BarDaily, Indicator, Snapshot
from services.finnhub_client import FinnhubClient
from services.monitor_tiers import build_tier_map, quote_interval_seconds
from services.quote_history import (
    history_for,
    pct_change,
    price_at_minutes_ago,
    prune_old_quote_ticks,
    record_quote_tick,
)
from services.session_tracker import _is_market_hours

logger = logging.getLogger(__name__)

_tick_index = 0


async def _latest_rsi_sma(session: AsyncSession, symbol: str) -> tuple[float | None, float | None]:
    rsi_result = await session.execute(
        select(Indicator)
        .where(Indicator.symbol == symbol, Indicator.indicator_type == "RSI")
        .order_by(Indicator.bar_ts.desc())
        .limit(1)
    )
    sma_result = await session.execute(
        select(Indicator)
        .where(Indicator.symbol == symbol, Indicator.indicator_type == "SMA20")
        .order_by(Indicator.bar_ts.desc())
        .limit(1)
    )
    rsi_row = rsi_result.scalar_one_or_none()
    sma_row = sma_result.scalar_one_or_none()
    return (
        rsi_row.value if rsi_row else None,
        sma_row.value if sma_row else None,
    )


async def _change_30d(session: AsyncSession, symbol: str, price: float) -> float:
    from datetime import timedelta

    cutoff = datetime.now(timezone.utc) - timedelta(days=35)
    result = await session.execute(
        select(BarDaily)
        .where(BarDaily.symbol == symbol, BarDaily.bar_date >= cutoff)
        .order_by(BarDaily.bar_date)
    )
    bars = result.scalars().all()
    if len(bars) < 2:
        return 0.0
    first = bars[0].close
    if first <= 0:
        return 0.0
    return (price - first) / first * 100


async def run_quote_cycle() -> None:
    global _tick_index
    client = FinnhubClient()
    if not client.configured:
        return
    if not _is_market_hours():
        return

    _tick_index += 1
    tick = _tick_index

    async with SessionLocal() as session:
        tier_map = await build_tier_map(session)
        symbols = list(tier_map.keys())
        updated = 0

        for symbol in symbols:
            tier = tier_map[symbol]
            if not quote_interval_seconds(tier, tick):
                continue

            quote = await client.fetch_quote(symbol)
            if not quote:
                continue

            price = float(quote["c"])
            change_1d = float(quote.get("dp") or 0.0)
            now = datetime.now(timezone.utc)
            hist = history_for(symbol)
            change_5m = pct_change(price, price_at_minutes_ago(hist, 5))
            change_15m = pct_change(price, price_at_minutes_ago(hist, 15))
            await record_quote_tick(session, symbol, price, now)
            change_30d = await _change_30d(session, symbol, price)
            rsi, sma = await _latest_rsi_sma(session, symbol)

            session.add(
                Snapshot(
                    symbol=symbol,
                    price=price,
                    change_1d_pct=change_1d,
                    change_30d_pct=change_30d,
                    change_5m_pct=change_5m,
                    change_15m_pct=change_15m,
                    rsi=rsi,
                    sma_20=sma,
                    quote_source="finnhub",
                    captured_at=now,
                )
            )
            updated += 1

        if updated:
            if tick % 20 == 0:
                pruned = await prune_old_quote_ticks(session)
                if pruned:
                    logger.info("Pruned %d old quote ticks", pruned)
            await session.commit()
            logger.info("Finnhub quotes updated %d symbols (tick %d)", updated, tick)

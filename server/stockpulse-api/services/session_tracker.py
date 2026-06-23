from __future__ import annotations

import logging
from datetime import datetime, timedelta, timezone
from zoneinfo import ZoneInfo

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from models.db_models import MarketObservation
from services.analysis_packet import _load_histories, _session_date_key
from services.news_ingest import ingest_news_for_next_ticker, news_ingest_interval_minutes
from services.ripple_engine import analyze_ripples
from services.tracked import get_tracked_symbols

logger = logging.getLogger(__name__)

ET = ZoneInfo("America/New_York")

_verdict_cache: dict[str, str] = {}
_rsi_cache: dict[str, float] = {}


def _is_market_hours() -> bool:
    now = datetime.now(ET)
    if now.weekday() >= 5:
        return False
    minutes = now.hour * 60 + now.minute
    return (9 * 60 + 30) <= minutes < (16 * 60)


async def _recent_observation(
    session: AsyncSession, symbol: str, observation_type: str, minutes: int = 60
) -> bool:
    cutoff = datetime.now(timezone.utc) - timedelta(minutes=minutes)
    result = await session.execute(
        select(MarketObservation.id)
        .where(
            MarketObservation.symbol == symbol,
            MarketObservation.observation_type == observation_type,
            MarketObservation.created_at >= cutoff,
        )
        .limit(1)
    )
    return result.scalar_one_or_none() is not None


async def _add_observation(
    session: AsyncSession,
    symbol: str,
    observation_type: str,
    change_pct: float,
    window_minutes: int,
    message: str,
) -> None:
    if await _recent_observation(session, symbol, observation_type):
        return
    session.add(
        MarketObservation(
            symbol=symbol,
            observation_type=observation_type,
            change_pct=change_pct,
            window_minutes=window_minutes,
            message=message,
            session_date=_session_date_key(),
        )
    )


async def _price_change_over_window(
    session: AsyncSession, symbol: str, window_minutes: int
) -> float | None:
    from models.db_models import BarMinute, Snapshot

    cutoff = datetime.now(timezone.utc) - timedelta(minutes=window_minutes)
    result = await session.execute(
        select(BarMinute)
        .where(BarMinute.symbol == symbol, BarMinute.bar_ts >= cutoff)
        .order_by(BarMinute.bar_ts)
    )
    bars = result.scalars().all()
    if len(bars) >= 2:
        first, last = bars[0].close, bars[-1].close
    else:
        snap_result = await session.execute(
            select(Snapshot)
            .where(Snapshot.symbol == symbol, Snapshot.captured_at >= cutoff)
            .order_by(Snapshot.captured_at)
        )
        snaps = snap_result.scalars().all()
        if len(snaps) < 2:
            return None
        first, last = snaps[0].price, snaps[-1].price
    if first <= 0:
        return None
    return (last - first) / first * 100


async def run_session_tracker(session: AsyncSession) -> None:
    from config import get_settings

    settings = get_settings()
    symbols = await get_tracked_symbols(session)
    histories = await _load_histories(session, symbols, days=30)
    ripple = analyze_ripples(histories)

    from models.db_models import Snapshot

    for symbol in symbols:
        for window in (15, 30, 60):
            change = await _price_change_over_window(session, symbol, window)
            if change is None:
                continue
            if abs(change) >= settings.alert_velocity_pct:
                await _add_observation(
                    session,
                    symbol,
                    "velocity_spike",
                    change,
                    window,
                    f"{symbol} moved {change:+.1f}% in the last {window} minutes",
                )
                break

        snap_result = await session.execute(
            select(Snapshot)
            .where(Snapshot.symbol == symbol)
            .order_by(Snapshot.captured_at.desc())
            .limit(1)
        )
        snap = snap_result.scalar_one_or_none()
        if snap and snap.rsi is not None:
            prev_rsi = _rsi_cache.get(symbol)
            if prev_rsi is not None:
                if prev_rsi < 70 <= snap.rsi:
                    await _add_observation(
                        session,
                        symbol,
                        "rsi_cross",
                        snap.change_1d_pct,
                        0,
                        f"{symbol} RSI crossed into overbought ({snap.rsi:.1f})",
                    )
                elif prev_rsi > 30 >= snap.rsi:
                    await _add_observation(
                        session,
                        symbol,
                        "rsi_cross",
                        snap.change_1d_pct,
                        0,
                        f"{symbol} RSI crossed into oversold ({snap.rsi:.1f})",
                    )
            _rsi_cache[symbol] = snap.rsi

    for cat_ticker, rows in ripple.items():
        for r in rows:
            key = f"{cat_ticker}:{r['ripple_ticker']}"
            verdict = r["verdict"]
            prev = _verdict_cache.get(key)
            if prev and prev != verdict:
                await _add_observation(
                    session,
                    r["ripple_ticker"],
                    "ripple_verdict_change",
                    r["post_event_pct"],
                    0,
                    f"{cat_ticker}→{r['ripple_ticker']} verdict {prev} → {verdict}",
                )
            _verdict_cache[key] = verdict


async def run_session_tracker_job() -> None:
    if not _is_market_hours():
        return
    from database import SessionLocal

    async with SessionLocal() as session:
        await run_session_tracker(session)
        await session.commit()
    logger.info("Session tracker completed")


async def run_news_ingest_job() -> None:
    if not _is_market_hours():
        return
    from database import SessionLocal

    async with SessionLocal() as session:
        sym, provider = await ingest_news_for_next_ticker(session)
        await session.commit()
        if sym and provider:
            logger.info("Ingested %s news for %s", provider, sym)

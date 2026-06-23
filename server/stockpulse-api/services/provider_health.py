"""Finnhub + Massive provider freshness and budget health."""

from __future__ import annotations

import logging
from datetime import datetime, timedelta, timezone

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from config import get_settings
from models.db_models import BarDaily, QuoteTick, Snapshot
from services.finnhub_client import FinnhubClient
from services.monitor_tiers import MonitorTier, build_tier_map
from services.tracked import get_tracked_symbols

logger = logging.getLogger(__name__)


async def _latest_snapshots(session: AsyncSession) -> dict[str, Snapshot]:
    result = await session.execute(select(Snapshot).order_by(Snapshot.captured_at.desc()).limit(200))
    out: dict[str, Snapshot] = {}
    for snap in result.scalars().all():
        if snap.symbol not in out:
            out[snap.symbol] = snap
    return out


async def build_provider_health(session: AsyncSession) -> dict:
    settings = get_settings()
    now = datetime.now(timezone.utc)
    tier_map = await build_tier_map(session)
    snapshots = await _latest_snapshots(session)
    tracked = await get_tracked_symbols(session)

    finnhub = FinnhubClient()
    hot_stale: list[str] = []
    warm_stale: list[str] = []
    cold_stale: list[str] = []
    quote_sources: dict[str, int] = {}

    for sym in tracked:
        tier = tier_map.get(sym, MonitorTier.COLD)
        snap = snapshots.get(sym)
        if snap and snap.quote_source:
            quote_sources[snap.quote_source] = quote_sources.get(snap.quote_source, 0) + 1
        lag_min = None
        if snap and snap.captured_at:
            captured = snap.captured_at
            if captured.tzinfo is None:
                captured = captured.replace(tzinfo=timezone.utc)
            lag_min = (now - captured).total_seconds() / 60
        threshold = {MonitorTier.HOT: 2.0, MonitorTier.WARM: 5.0, MonitorTier.COLD: 10.0}[tier]
        if lag_min is None or lag_min > threshold:
            if tier == MonitorTier.HOT:
                hot_stale.append(sym)
            elif tier == MonitorTier.WARM:
                warm_stale.append(sym)
            else:
                cold_stale.append(sym)

    hour_ago = now - timedelta(hours=1)
    tick_count_result = await session.execute(
        select(func.count()).select_from(QuoteTick).where(QuoteTick.captured_at >= hour_ago)
    )
    quote_ticks_last_hour = tick_count_result.scalar() or 0

    hot_cutoff = now - timedelta(days=settings.hot_days)
    stale_daily: list[str] = []
    for sym in tracked:
        count_result = await session.execute(
            select(func.count())
            .select_from(BarDaily)
            .where(BarDaily.symbol == sym, BarDaily.bar_date >= hot_cutoff)
        )
        if (count_result.scalar() or 0) == 0:
            stale_daily.append(sym)

    hot_count = sum(1 for t in tier_map.values() if t == MonitorTier.HOT)
    warm_count = sum(1 for t in tier_map.values() if t == MonitorTier.WARM)
    cold_count = sum(1 for t in tier_map.values() if t == MonitorTier.COLD)

    est_finnhub_per_min = hot_count + (warm_count + 1) // 2 + (cold_count + 5) // 6
    status = "ok"
    if hot_stale:
        status = "degraded"
    if not finnhub.configured:
        status = "finnhub_missing"

    return {
        "status": status,
        "checked_at": now.isoformat(),
        "finnhub_configured": finnhub.configured,
        "massive_configured": bool(settings.massive_api_key.strip()),
        "tiers": {"hot": hot_count, "warm": warm_count, "cold": cold_count},
        "estimated_finnhub_calls_per_min": est_finnhub_per_min,
        "massive_calls_per_min_limit": settings.calls_per_minute,
        "quote_ticks_last_hour": quote_ticks_last_hour,
        "quote_sources": quote_sources,
        "stale_quotes": {
            "hot": sorted(hot_stale),
            "warm": sorted(warm_stale),
            "cold": sorted(cold_stale),
        },
        "stale_daily_bars": sorted(stale_daily),
    }


async def run_provider_health_check() -> dict:
    from database import SessionLocal

    async with SessionLocal() as session:
        report = await build_provider_health(session)
    if report["status"] != "ok":
        logger.warning("Provider health degraded: %s", report)
    else:
        logger.info("Provider health ok (finnhub est %d/min)", report["estimated_finnhub_calls_per_min"])
    return report

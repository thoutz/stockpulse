from __future__ import annotations

from datetime import datetime, timezone

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from config import get_settings
from models.db_models import Favorite, Snapshot, Ticker
from services.monitor_tiers import FAVORITE_LIMIT, MonitorTier, build_tier_map, get_monitor_settings
from services.sector_catalog import SECTORS, sector_for_symbol
from services.tracked import get_tracked_symbols


def _snapshot_out(snap: Snapshot, tier: MonitorTier, sector_id: str | None, is_favorite: bool) -> dict:
    lag: float | None = None
    if snap.captured_at:
        lag = (datetime.now(timezone.utc) - snap.captured_at.replace(tzinfo=timezone.utc)).total_seconds()
    return {
        "symbol": snap.symbol,
        "name": None,
        "tier": tier.value,
        "sector_id": sector_id,
        "price": snap.price,
        "change_1d_pct": snap.change_1d_pct,
        "change_5m_pct": snap.change_5m_pct,
        "change_15m_pct": snap.change_15m_pct,
        "change_30d_pct": snap.change_30d_pct,
        "rsi": snap.rsi,
        "sma_20": snap.sma_20,
        "quote_source": snap.quote_source,
        "captured_at": snap.captured_at.isoformat() if snap.captured_at else None,
        "lag_seconds": round(lag, 1) if lag is not None else None,
        "is_favorite": is_favorite,
    }


async def build_monitor_payload(session: AsyncSession) -> dict:
    settings = get_settings()
    monitor = await get_monitor_settings(session)
    tier_map = await build_tier_map(session)
    tracked = await get_tracked_symbols(session)

    fav_result = await session.execute(select(Favorite))
    fav_rows = {f.symbol.upper(): f for f in fav_result.scalars().all()}
    fav_set = set(fav_rows.keys())

    ticker_names = {
        sym.upper(): name
        for sym, name in (
            await session.execute(select(Ticker.symbol, Ticker.name))
        ).all()
    }

    snap_result = await session.execute(select(Snapshot).order_by(Snapshot.captured_at.desc()).limit(200))
    latest_snaps: dict[str, Snapshot] = {}
    for snap in snap_result.scalars().all():
        if snap.symbol not in latest_snaps:
            latest_snaps[snap.symbol] = snap

    def symbol_row(sym: str) -> dict:
        tier = tier_map.get(sym, MonitorTier.COLD)
        sec = sector_for_symbol(sym)
        snap = latest_snaps.get(sym)
        if snap is None:
            return {
                "symbol": sym,
                "name": fav_rows.get(sym).name if sym in fav_rows else ticker_names.get(sym),
                "tier": tier.value,
                "sector_id": sec.id if sec else None,
                "price": 0.0,
                "change_1d_pct": 0.0,
                "change_5m_pct": None,
                "change_15m_pct": None,
                "change_30d_pct": 0.0,
                "rsi": None,
                "sma_20": None,
                "quote_source": None,
                "captured_at": None,
                "lag_seconds": None,
                "is_favorite": sym in fav_set,
            }
        row = _snapshot_out(snap, tier, sec.id if sec else None, sym in fav_set)
        row["name"] = fav_rows[sym].name if sym in fav_rows else ticker_names.get(sym)
        return row

    hot: list[dict] = []
    warm: list[dict] = []
    cold: list[dict] = []

    for sym in tracked:
        row = symbol_row(sym)
        tier = MonitorTier(row["tier"])
        if tier == MonitorTier.HOT:
            hot.append(row)
        elif tier == MonitorTier.WARM:
            warm.append(row)
        else:
            cold.append(row)

    for bucket in (hot, warm, cold):
        bucket.sort(key=lambda r: r["symbol"])

    count_result = await session.execute(select(func.count()).select_from(Favorite))
    fav_count = count_result.scalar() or 0

    return {
        "focus_sector_id": monitor.focus_sector_id,
        "favorite_count": fav_count,
        "favorite_limit": settings.favorite_limit,
        "sectors": [
            {
                "id": s.id,
                "name": s.name,
                "description": s.description,
                "tickers": list(s.tickers),
                "accent_hex": s.accent_hex,
            }
            for s in SECTORS
        ],
        "hot": hot,
        "warm": warm,
        "cold": cold,
    }

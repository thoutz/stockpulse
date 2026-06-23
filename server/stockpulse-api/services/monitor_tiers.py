from __future__ import annotations

from enum import Enum

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from config import get_settings
from models.db_models import Favorite, MonitorSettings
from services.sector_catalog import SECTOR_BY_ID, sector_for_symbol
from services.tracked import get_tracked_symbols

FAVORITE_LIMIT = 20


class MonitorTier(str, Enum):
    HOT = "hot"
    WARM = "warm"
    COLD = "cold"


async def get_monitor_settings(session: AsyncSession) -> MonitorSettings:
    row = await session.get(MonitorSettings, 1)
    if row is None:
        row = MonitorSettings(id=1, focus_sector_id=None)
        session.add(row)
        await session.flush()
    return row


async def set_focus_sector(session: AsyncSession, focus_sector_id: str | None) -> MonitorSettings:
    if focus_sector_id is not None and focus_sector_id not in SECTOR_BY_ID:
        raise ValueError(f"Unknown sector: {focus_sector_id}")
    settings = await get_monitor_settings(session)
    settings.focus_sector_id = focus_sector_id
    return settings


async def favorite_symbols(session: AsyncSession) -> set[str]:
    result = await session.execute(select(Favorite.symbol))
    return {s.upper() for (s,) in result.all()}


def resolve_tier(
    symbol: str,
    *,
    focus_sector_id: str | None,
    favorites: set[str],
    config_tickers: set[str],
) -> MonitorTier:
    sym = symbol.upper()
    if focus_sector_id:
        sector = SECTOR_BY_ID.get(focus_sector_id)
        if sector and sym in sector.tickers:
            return MonitorTier.HOT
    if sym in favorites:
        return MonitorTier.WARM
    if sym in config_tickers:
        return MonitorTier.COLD
    return MonitorTier.WARM


async def build_tier_map(session: AsyncSession) -> dict[str, MonitorTier]:
    settings = get_settings()
    monitor = await get_monitor_settings(session)
    favs = await favorite_symbols(session)
    config_set = {s.upper() for s in settings.ticker_list}
    tracked = await get_tracked_symbols(session)
    return {
        sym: resolve_tier(
            sym,
            focus_sector_id=monitor.focus_sector_id,
            favorites=favs,
            config_tickers=config_set,
        )
        for sym in tracked
    }


def quote_interval_seconds(tier: MonitorTier, tick_index: int) -> bool:
    """Return True if this scheduler tick should fetch a quote for the tier."""
    if tier == MonitorTier.HOT:
        return True
    if tier == MonitorTier.WARM:
        return tick_index % 2 == 0
    return tick_index % 6 == 0

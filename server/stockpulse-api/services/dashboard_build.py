from __future__ import annotations

from datetime import datetime, timedelta, timezone

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from config import get_settings
from models.db_models import BarDaily, Favorite, Snapshot
from services.catalyst_catalog import load_catalysts
from services.ripple_engine import Bar, analyze_ripples
from services.tracked import get_tracked_symbols

# Tickers needing 90d history for ripple / catalyst charts
EXTENDED_TICKERS = sorted(
    {
        "RKLB", "TSLA", "NVDA", "ASTS", "LUNR", "HWM", "RDW", "AMD", "AVGO",
    }
)


def _bar_out(b: BarDaily) -> dict:
    return {
        "date": b.bar_date.isoformat(),
        "open": b.open,
        "high": b.high,
        "low": b.low,
        "close": b.close,
        "volume": b.volume,
    }


async def build_dashboard(session: AsyncSession) -> dict:
    settings = get_settings()
    tickers = await get_tracked_symbols(session)
    fav_result = await session.execute(select(Favorite.symbol).order_by(Favorite.symbol))
    favorites = [s for (s,) in fav_result.all()]
    hot_cutoff = datetime.now(timezone.utc) - timedelta(days=settings.hot_days)

    snapshots_out: list[dict] = []
    snap_result = await session.execute(select(Snapshot).order_by(Snapshot.captured_at.desc()).limit(50))
    seen_snap: set[str] = set()
    for s in snap_result.scalars().all():
        if s.symbol in seen_snap:
            continue
        seen_snap.add(s.symbol)
        snapshots_out.append(
            {
                "symbol": s.symbol,
                "price": s.price,
                "change_1d_pct": s.change_1d_pct,
                "change_30d_pct": s.change_30d_pct,
                "rsi": s.rsi,
                "sma_20": s.sma_20,
                "captured_at": s.captured_at.isoformat(),
            }
        )
    snapshots_out.sort(key=lambda x: x["symbol"])

    histories: dict[str, list[dict]] = {}
    histories_extended: dict[str, list[dict]] = {}
    stale_tickers: list[str] = []
    data_as_of: datetime | None = None

    for sym in tickers:
        # Hot window (30d) for all tickers
        hot_result = await session.execute(
            select(BarDaily)
            .where(BarDaily.symbol == sym, BarDaily.bar_date >= hot_cutoff)
            .order_by(BarDaily.bar_date)
        )
        hot_bars = hot_result.scalars().all()
        if hot_bars:
            histories[sym] = [_bar_out(b) for b in hot_bars]
        else:
            stale_tickers.append(sym)

        # Extended (90d) for ripple/catalyst set
        if sym in EXTENDED_TICKERS:
            ext_result = await session.execute(
                select(BarDaily).where(BarDaily.symbol == sym).order_by(BarDaily.bar_date)
            )
            ext_bars = ext_result.scalars().all()
            if ext_bars:
                histories_extended[sym] = [_bar_out(b) for b in ext_bars]
                last_ts = ext_bars[-1].bar_date
                if data_as_of is None or last_ts > data_as_of:
                    data_as_of = last_ts

    # Ripple results from extended histories
    ripple_histories: dict[str, list[Bar]] = {}
    for sym in EXTENDED_TICKERS:
        ext_result = await session.execute(
            select(BarDaily).where(BarDaily.symbol == sym).order_by(BarDaily.bar_date)
        )
        ext_bars = ext_result.scalars().all()
        if ext_bars:
            ripple_histories[sym] = [Bar(date=b.bar_date, close=b.close) for b in ext_bars]
    ripple_results = analyze_ripples(ripple_histories, await load_catalysts(session))

    max_date_result = await session.execute(select(func.max(BarDaily.bar_date)))
    max_row = max_date_result.scalar()
    if max_row and (data_as_of is None or max_row > data_as_of):
        data_as_of = max_row

    return {
        "snapshots": snapshots_out,
        "histories": histories,
        "histories_extended": histories_extended,
        "ripple_results": ripple_results,
        "data_as_of": data_as_of.isoformat() if data_as_of else None,
        "stale": len(stale_tickers) > 0,
        "stale_tickers": stale_tickers,
        "catalysts": [c["ticker"] for c in await load_catalysts(session)],
        "favorites": favorites,
    }


async def build_data_status(session: AsyncSession) -> dict:
    settings = get_settings()
    tickers = await get_tracked_symbols(session)
    rows = []
    for sym in tickers:
        count_result = await session.execute(
            select(func.count()).select_from(BarDaily).where(BarDaily.symbol == sym)
        )
        count = count_result.scalar() or 0
        max_result = await session.execute(
            select(func.max(BarDaily.bar_date)).where(BarDaily.symbol == sym)
        )
        last_bar = max_result.scalar()
        rows.append(
            {
                "symbol": sym,
                "bar_count": count,
                "last_bar_date": last_bar.isoformat() if last_bar else None,
                "has_hot_data": count >= settings.hot_days // 2,
            }
        )
    return {"tickers": rows, "hot_days": settings.hot_days, "full_days": settings.full_days}

from __future__ import annotations

from datetime import datetime, timedelta, timezone
from zoneinfo import ZoneInfo

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from models.db_models import BarDaily, BarMinute, Snapshot
from services.sector_catalog import SECTOR_GROUPS

ET = ZoneInfo("America/New_York")


def _today_et_bounds() -> tuple[datetime, datetime]:
    now = datetime.now(ET)
    start = now.replace(hour=0, minute=0, second=0, microsecond=0)
    return start, now


async def _prev_daily_close(session: AsyncSession, symbol: str) -> float | None:
    result = await session.execute(
        select(BarDaily)
        .where(BarDaily.symbol == symbol)
        .order_by(BarDaily.bar_date.desc())
        .limit(2)
    )
    bars = result.scalars().all()
    if len(bars) >= 2:
        return bars[1].close
    if len(bars) == 1:
        return bars[0].close
    return None


async def _session_open_from_minutes(session: AsyncSession, symbol: str) -> float | None:
    start_et, _ = _today_et_bounds()
    start_utc = start_et.astimezone(timezone.utc)
    result = await session.execute(
        select(BarMinute)
        .where(BarMinute.symbol == symbol, BarMinute.bar_ts >= start_utc)
        .order_by(BarMinute.bar_ts)
        .limit(1)
    )
    bar = result.scalar_one_or_none()
    return bar.open if bar else None


async def _today_volume(session: AsyncSession, symbol: str) -> float | None:
    start_et, _ = _today_et_bounds()
    start_utc = start_et.astimezone(timezone.utc)
    result = await session.execute(
        select(BarMinute.volume).where(
            BarMinute.symbol == symbol, BarMinute.bar_ts >= start_utc
        )
    )
    vols = [v for (v,) in result.all()]
    if vols:
        return sum(vols)
    result = await session.execute(
        select(BarDaily)
        .where(BarDaily.symbol == symbol)
        .order_by(BarDaily.bar_date.desc())
        .limit(1)
    )
    bar = result.scalar_one_or_none()
    return bar.volume if bar else None


async def _avg_daily_volume(session: AsyncSession, symbol: str, days: int = 20) -> float | None:
    cutoff = datetime.now(timezone.utc) - timedelta(days=days + 5)
    result = await session.execute(
        select(BarDaily.volume)
        .where(BarDaily.symbol == symbol, BarDaily.bar_date >= cutoff)
        .order_by(BarDaily.bar_date.desc())
        .limit(days)
    )
    vols = [v for (v,) in result.all() if v and v > 0]
    if not vols:
        return None
    return sum(vols) / len(vols)


async def build_massive_session_stats(
    session: AsyncSession, symbols: list[str]
) -> list[str]:
    """Compact intraday stats from Massive bars — no external API calls."""
    lines: list[str] = []
    snapshots = {}
    snap_result = await session.execute(
        select(Snapshot).order_by(Snapshot.captured_at.desc()).limit(200)
    )
    for snap in snap_result.scalars().all():
        if snap.symbol not in snapshots:
            snapshots[snap.symbol] = snap

    for sym in sorted(symbols):
        snap = snapshots.get(sym)
        if not snap:
            continue
        parts: list[str] = [f"{sym}: 1D {snap.change_1d_pct:+.1f}%"]

        prev_close = await _prev_daily_close(session, sym)
        session_open = await _session_open_from_minutes(session, sym)
        if prev_close and prev_close > 0 and session_open:
            gap = (session_open - prev_close) / prev_close * 100
            parts.append(f"gap {gap:+.1f}%")

        today_vol = await _today_volume(session, sym)
        avg_vol = await _avg_daily_volume(session, sym)
        if today_vol and avg_vol and avg_vol > 0:
            ratio = today_vol / avg_vol
            if ratio >= 1.3 or ratio <= 0.7:
                parts.append(f"volume {ratio:.1f}× 20D avg")

        if len(parts) > 1:
            lines.append(", ".join(parts))

    group_lines: list[str] = []
    for group_name, group_syms in SECTOR_GROUPS.items():
        changes = [
            snapshots[s].change_1d_pct
            for s in group_syms
            if s in snapshots
        ]
        if changes:
            avg = sum(changes) / len(changes)
            group_lines.append(f"{group_name} avg 1D {avg:+.1f}%")

    if group_lines:
        lines.append("Sector groups: " + "; ".join(group_lines))

    return lines

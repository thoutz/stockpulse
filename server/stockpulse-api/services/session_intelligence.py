"""Pre-pulse session intelligence — persisted analytics for Groq reports and future APIs."""

from __future__ import annotations

import logging
from datetime import datetime, timedelta, timezone
from zoneinfo import ZoneInfo

from sqlalchemy import delete, select
from sqlalchemy.ext.asyncio import AsyncSession

from database import SessionLocal
from models.db_models import MarketObservation, SessionIntelligence, Snapshot
from services.monitor_tiers import MonitorTier, build_tier_map, get_monitor_settings
from services.ripple_engine import analyze_ripples
from services.sector_catalog import SECTOR_BY_ID
from services.tracked import get_tracked_symbols

logger = logging.getLogger(__name__)

ET = ZoneInfo("America/New_York")
VALID_SLOTS = frozenset({"open", "midday", "close"})

SLOT_PRIOR: dict[str, str | None] = {
    "open": None,
    "midday": "open",
    "close": "midday",
}


def _session_date_key() -> str:
    return datetime.now(ET).strftime("%Y-%m-%d")


async def _latest_snapshots(session: AsyncSession) -> dict[str, Snapshot]:
    result = await session.execute(select(Snapshot).order_by(Snapshot.captured_at.desc()).limit(200))
    out: dict[str, Snapshot] = {}
    for snap in result.scalars().all():
        if snap.symbol not in out:
            out[snap.symbol] = snap
    return out


def _observation_cutoff(slot: str, session_date: str) -> datetime:
    day = datetime.strptime(session_date, "%Y-%m-%d").replace(tzinfo=ET)
    if slot == "open":
        return day.replace(hour=9, minute=30)
    if slot == "midday":
        return day.replace(hour=10, minute=0)
    return day.replace(hour=9, minute=30)


async def build_session_intelligence(
    session: AsyncSession,
    slot: str,
    *,
    session_date: str | None = None,
) -> int:
    if slot not in VALID_SLOTS:
        raise ValueError(f"Unknown slot: {slot}")

    session_date = session_date or _session_date_key()
    await session.execute(
        delete(SessionIntelligence).where(
            SessionIntelligence.session_date == session_date,
            SessionIntelligence.slot == slot,
        )
    )

    tier_map = await build_tier_map(session)
    monitor = await get_monitor_settings(session)
    snapshots = await _latest_snapshots(session)
    rows: list[SessionIntelligence] = []

    def add(
        category: str,
        summary_text: str,
        *,
        symbol: str | None = None,
        tier: MonitorTier | None = None,
        metric_key: str | None = None,
        metric_value: float | None = None,
    ) -> None:
        rows.append(
            SessionIntelligence(
                session_date=session_date,
                slot=slot,
                category=category,
                symbol=symbol.upper() if symbol else None,
                tier=tier.value if tier else None,
                metric_key=metric_key,
                metric_value=metric_value,
                summary_text=summary_text,
            )
        )

    hot_syms = [s for s, t in tier_map.items() if t == MonitorTier.HOT]
    warm_syms = [s for s, t in tier_map.items() if t == MonitorTier.WARM]
    cold_syms = [s for s, t in tier_map.items() if t == MonitorTier.COLD]

    if monitor.focus_sector_id and monitor.focus_sector_id in SECTOR_BY_ID:
        sector = SECTOR_BY_ID[monitor.focus_sector_id]
        add(
            "focus",
            f"Monitor focus: {sector.name} ({monitor.focus_sector_id}) — HOT tickers: {', '.join(sorted(hot_syms)) or 'none'}",
        )
        up = 0
        changes: list[float] = []
        for sym in sector.tickers:
            snap = snapshots.get(sym)
            if not snap:
                continue
            changes.append(snap.change_1d_pct)
            if snap.change_1d_pct > 0:
                up += 1
        if changes:
            avg = sum(changes) / len(changes)
            add(
                "sector_breadth",
                f"{sector.name}: {up}/{len(sector.tickers)} up on 1D, avg 1D {avg:+.1f}%",
            )
    else:
        add("focus", "Monitor focus: none (no sector selected)")

    add(
        "tier_summary",
        f"Tiers — HOT: {len(hot_syms)}, WARM: {len(warm_syms)}, COLD: {len(cold_syms)}",
    )

    movers: list[tuple[str, MonitorTier, Snapshot]] = []
    for sym, snap in snapshots.items():
        if snap.change_5m_pct is None:
            continue
        tier = tier_map.get(sym, MonitorTier.COLD)
        if tier in (MonitorTier.HOT, MonitorTier.WARM):
            movers.append((sym, tier, snap))
    movers.sort(key=lambda x: abs(x[2].change_5m_pct or 0), reverse=True)
    for sym, tier, snap in movers[:10]:
        m5 = snap.change_5m_pct or 0
        m15 = snap.change_15m_pct
        m15_txt = f", 15m {m15:+.1f}%" if m15 is not None else ""
        add(
            "intraday_mover",
            f"{sym} [{tier.value}]: 5m {m5:+.1f}%{m15_txt}, 1D {snap.change_1d_pct:+.1f}% at ${snap.price:.2f}",
            symbol=sym,
            tier=tier,
            metric_key="change_5m_pct",
            metric_value=m5,
        )

    cutoff = _observation_cutoff(slot, session_date).astimezone(timezone.utc)
    obs_result = await session.execute(
        select(MarketObservation)
        .where(
            MarketObservation.session_date == session_date,
            MarketObservation.created_at >= cutoff,
        )
        .order_by(MarketObservation.created_at.desc())
        .limit(50)
    )
    observations = obs_result.scalars().all()
    if observations:
        by_type: dict[str, int] = {}
        for o in observations:
            by_type[o.observation_type] = by_type.get(o.observation_type, 0) + 1
        parts = [f"{k}: {v}" for k, v in sorted(by_type.items())]
        add(
            "observation_digest",
            f"Since session window start: {len(observations)} events ({', '.join(parts)})",
        )
        for o in observations[:8]:
            add(
                "observation",
                o.message,
                symbol=o.symbol,
                metric_key=o.observation_type,
                metric_value=o.change_pct,
            )

    symbols = await get_tracked_symbols(session)
    from services.analysis_packet import _load_histories
    from services.catalyst_catalog import load_catalysts

    histories = await _load_histories(session, symbols, days=30)
    catalysts = await load_catalysts(session)
    ripple = analyze_ripples(histories, catalysts)
    for cat_ticker, ripple_rows in ripple.items():
        for r in ripple_rows:
            if r["verdict"] in ("CONFIRMED", "FORMING"):
                add(
                    "ripple",
                    f"{cat_ticker}→{r['ripple_ticker']}: {r['verdict']}, post {r['post_event_pct']:+.1f}%",
                    symbol=r["ripple_ticker"],
                    metric_key="post_event_pct",
                    metric_value=r["post_event_pct"],
                )

    if slot == "close":
        stale_hot = [
            sym
            for sym in hot_syms
            if sym not in snapshots
            or (datetime.now(timezone.utc) - snapshots[sym].captured_at.replace(tzinfo=timezone.utc))
            > timedelta(minutes=2)
        ]
        if stale_hot:
            add(
                "data_quality",
                f"HOT symbols with stale quotes (>2m): {', '.join(sorted(stale_hot))}",
            )

    from services.buying_signals import build_buying_signals

    watch, avoid = await build_buying_signals(session, slot)
    for sig in watch:
        add(
            "buying_signal",
            f"WATCH {sig.symbol} [score {sig.score:.0f}, {sig.tier}]: {'; '.join(sig.signals[:4])}",
            symbol=sig.symbol,
            tier=MonitorTier(sig.tier) if sig.tier in ("HOT", "WARM", "COLD") else None,
            metric_key="watch_score",
            metric_value=sig.score,
        )
    for sig in avoid:
        add(
            "buying_signal",
            f"AVOID {sig.symbol} [score {sig.score:.0f}, {sig.tier}]: {'; '.join(sig.signals[:4])}",
            symbol=sig.symbol,
            metric_key="avoid_score",
            metric_value=sig.score,
        )

    for row in rows:
        session.add(row)
    await session.flush()
    logger.info("Session intelligence built for %s/%s: %d rows", session_date, slot, len(rows))
    return len(rows)


async def run_pre_pulse_intelligence(slot: str, *, session_date: str | None = None) -> int:
    async with SessionLocal() as session:
        count = await build_session_intelligence(session, slot, session_date=session_date)
        await session.commit()
        return count


async def fetch_intelligence_rows(
    session: AsyncSession,
    session_date: str,
    slot: str | None = None,
) -> list[SessionIntelligence]:
    stmt = (
        select(SessionIntelligence)
        .where(SessionIntelligence.session_date == session_date)
        .order_by(SessionIntelligence.slot, SessionIntelligence.id)
    )
    if slot:
        stmt = stmt.where(SessionIntelligence.slot == slot)
    result = await session.execute(stmt)
    return list(result.scalars().all())


def format_intelligence_for_packet(rows: list[SessionIntelligence], slot: str) -> list[str]:
    slot_rows = [r for r in rows if r.slot == slot]
    if not slot_rows:
        return ["No pre-computed session intelligence for this slot yet."]

    lines: list[str] = []
    by_category: dict[str, list[SessionIntelligence]] = {}
    for row in slot_rows:
        by_category.setdefault(row.category, []).append(row)

    order = (
        "focus",
        "tier_summary",
        "sector_breadth",
        "intraday_mover",
        "observation_digest",
        "observation",
        "ripple",
        "buying_signal",
        "data_quality",
    )
    seen: set[str] = set()
    for cat in order:
        if cat not in by_category:
            continue
        seen.add(cat)
        for row in by_category[cat]:
            lines.append(f"- [{row.category}] {row.summary_text}")

    for cat, cat_rows in by_category.items():
        if cat in seen:
            continue
        for row in cat_rows:
            lines.append(f"- [{row.category}] {row.summary_text}")

    return lines

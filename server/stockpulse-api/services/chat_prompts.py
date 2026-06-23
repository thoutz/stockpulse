from __future__ import annotations

import hashlib
from datetime import datetime, timedelta, timezone
from zoneinfo import ZoneInfo

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from models.db_models import AIAlert, AISuggestion, BarDaily, Snapshot
from services.catalyst_catalog import load_catalysts
from services.ripple_engine import Bar, analyze_ripples

ET = ZoneInfo("America/New_York")
PROMPT_COUNT = 4

STATIC_FALLBACKS = [
    "Summarize my watchlist for today",
    "Which ripple network looks strongest?",
    "Compare the top two movers this week",
    "What's the broad market telling us today?",
    "Which catalyst has the best ripple confirmation?",
    "Did NVDA earnings actually lift AMD?",
    "Which space stock has best risk/reward?",
    "Summarize the full watchlist",
]


def _et_date_key(now: datetime | None = None) -> str:
    anchor = (now or datetime.now(timezone.utc)).astimezone(ET)
    return anchor.strftime("%Y-%m-%d")


def _pick_indices(pool_size: int, count: int, date_key: str) -> list[int]:
    """Deterministic shuffle indices for a calendar day."""
    if pool_size <= 0:
        return []
    order = list(range(pool_size))
    for i in range(pool_size - 1, 0, -1):
        digest = hashlib.sha256(f"{date_key}:sort:{i}".encode()).hexdigest()
        j = int(digest, 16) % (i + 1)
        order[i], order[j] = order[j], order[i]
    return order[: min(count, pool_size)]


def _fmt_pct(value: float) -> str:
    sign = "+" if value >= 0 else ""
    return f"{sign}{value:.1f}%"


async def _load_histories(session: AsyncSession, symbols: list[str], days: int = 30) -> dict[str, list[Bar]]:
    cutoff = datetime.now(timezone.utc) - timedelta(days=days + 5)
    histories: dict[str, list[Bar]] = {}
    for symbol in symbols:
        result = await session.execute(
            select(BarDaily)
            .where(BarDaily.symbol == symbol, BarDaily.bar_date >= cutoff)
            .order_by(BarDaily.bar_date)
        )
        rows = result.scalars().all()
        histories[symbol] = [Bar(date=r.bar_date, close=r.close) for r in rows]
    return histories


async def _collect_candidates(session: AsyncSession, date_key: str) -> list[str]:
    candidates: list[str] = []
    used_symbols: set[str] = set()

    def add(prompt: str, symbol: str | None = None) -> None:
        if symbol and symbol in used_symbols:
            return
        if prompt in candidates:
            return
        candidates.append(prompt)
        if symbol:
            used_symbols.add(symbol)

    # Snapshots — top movers by |1D change|
    snap_result = await session.execute(
        select(Snapshot).order_by(Snapshot.captured_at.desc()).limit(80)
    )
    seen_snap: set[str] = set()
    movers: list[Snapshot] = []
    for snap in snap_result.scalars().all():
        if snap.symbol in seen_snap:
            continue
        seen_snap.add(snap.symbol)
        if abs(snap.change_1d_pct) >= 1.5:
            movers.append(snap)
    movers.sort(key=lambda s: abs(s.change_1d_pct), reverse=True)
    for snap in movers[:3]:
        add(
            f"What's driving {snap.symbol}'s {_fmt_pct(snap.change_1d_pct)} move today?",
            snap.symbol,
        )

    # Ripple verdicts
    catalysts = await load_catalysts(session)
    symbols = sorted({c["ticker"] for c in catalysts} | {r[0] for c in catalysts for r in c["ripples"]})
    histories = await _load_histories(session, symbols)
    ripple_results = analyze_ripples(histories, catalysts)
    for cat in catalysts:
        rows = ripple_results.get(cat["ticker"], [])
        for row in rows:
            if row["verdict"] not in ("CONFIRMED", "FORMING"):
                continue
            add(
                f"Did {cat['ticker']} ripple confirm for {row['ripple_ticker']}?",
                row["ripple_ticker"],
            )
            break

    # Today's alerts
    day_start = datetime.strptime(date_key, "%Y-%m-%d").replace(tzinfo=ET)
    alert_cutoff = day_start.astimezone(timezone.utc)
    alert_result = await session.execute(
        select(AIAlert)
        .where(AIAlert.created_at >= alert_cutoff)
        .order_by(AIAlert.created_at.desc())
        .limit(10)
    )
    for alert in alert_result.scalars().all():
        add(
            f"{alert.symbol} jumped {_fmt_pct(alert.change_pct)} — is momentum holding?",
            alert.symbol,
        )

    # Recent suggestions
    sug_result = await session.execute(
        select(AISuggestion).order_by(AISuggestion.created_at.desc()).limit(15)
    )
    for sug in sug_result.scalars().all():
        bias_word = sug.bias if sug.bias in ("bullish", "bearish", "neutral") else "active"
        add(
            f"Is {sug.symbol} still {bias_word} after today's session?",
            sug.symbol,
        )

    # Compare top two movers
    if len(movers) >= 2:
        a, b = movers[0].symbol, movers[1].symbol
        add(f"Compare {a} vs {b} over the last week")

    for template in STATIC_FALLBACKS:
        add(template)

    return candidates


async def build_daily_chat_prompts(session: AsyncSession, now: datetime | None = None) -> list[str]:
    """Return exactly four chat prompts, stable for the ET calendar day."""
    date_key = _et_date_key(now)
    candidates = await _collect_candidates(session, date_key)
    if not candidates:
        candidates = list(STATIC_FALLBACKS)

    indices = _pick_indices(len(candidates), PROMPT_COUNT, date_key)
    picked = [candidates[i] for i in indices]

    fallback_idx = 0
    while len(picked) < PROMPT_COUNT:
        fb = STATIC_FALLBACKS[fallback_idx % len(STATIC_FALLBACKS)]
        fallback_idx += 1
        if fb not in picked:
            picked.append(fb)

    return picked[:PROMPT_COUNT]

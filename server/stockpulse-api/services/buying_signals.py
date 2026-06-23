"""Pre-computed research signals for pulse Research Watchlist sections."""

from __future__ import annotations

from dataclasses import dataclass, field
from datetime import datetime, timedelta, timezone
from typing import Literal
from zoneinfo import ZoneInfo

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from models.db_models import AISuggestion, SessionIntelligence, Snapshot
from services.catalyst_catalog import load_catalysts
from services.monitor_tiers import MonitorTier, build_tier_map, favorite_symbols, get_monitor_settings
from services.monitor_universe import monitored_symbol_set
from services.ripple_engine import Bar, analyze_ripples
from services.sector_catalog import SECTOR_BY_ID
from services.session_intelligence import fetch_intelligence_rows

ET = ZoneInfo("America/New_York")

WATCH_THRESHOLD = 15.0
AVOID_THRESHOLD = -10.0
RESERVED_FAVORITE_MIN_SCORE = 10.0

SLOT_WEIGHTS: dict[str, dict[str, float]] = {
    "open": {
        "ripple_confirmed": 30,
        "ripple_forming": 25,
        "intraday_mover": 20,
        "sector_breadth": 15,
        "rsi_oversold": 10,
        "suggestion_bullish": 10,
        "midday_confirm": 0,
        "av_fundamentals": 0,
        "user_favorite": 8,
        "ripple_failed": -25,
        "rsi_overbought": -20,
        "extended_pullback": -15,
        "suggestion_bearish": -10,
    },
    "midday": {
        "ripple_confirmed": 25,
        "ripple_forming": 20,
        "intraday_mover": 10,
        "sector_breadth": 10,
        "rsi_oversold": 10,
        "suggestion_bullish": 10,
        "midday_confirm": 20,
        "av_fundamentals": 0,
        "user_favorite": 8,
        "ripple_failed": -25,
        "rsi_overbought": -20,
        "extended_pullback": -10,
        "suggestion_bearish": -10,
    },
    "close": {
        "ripple_confirmed": 35,
        "ripple_forming": 15,
        "intraday_mover": 5,
        "sector_breadth": 10,
        "rsi_oversold": 15,
        "suggestion_bullish": 10,
        "midday_confirm": 0,
        "av_fundamentals": 15,
        "user_favorite": 8,
        "ripple_failed": -30,
        "rsi_overbought": -25,
        "extended_pullback": -10,
        "suggestion_bearish": -15,
    },
}


@dataclass
class BuyingSignal:
    symbol: str
    score: float
    stance: Literal["WATCH", "AVOID", "NEUTRAL"]
    signals: list[str] = field(default_factory=list)
    tier: str = "COLD"


def _session_date_key() -> str:
    return datetime.now(ET).strftime("%Y-%m-%d")


def _trend_metrics(bars: list[Bar]) -> tuple[float, float]:
    if len(bars) < 2:
        return 0.0, 0.0
    first, last = bars[0].close, bars[-1].close
    pct_30d = ((last - first) / first * 100) if first > 0 else 0.0
    high = max(b.close for b in bars)
    dist_high = ((last - high) / high * 100) if high > 0 else 0.0
    return pct_30d, dist_high


def _open_mover_symbols(intel_rows: list[SessionIntelligence], session_date: str) -> set[str]:
    syms: set[str] = set()
    for row in intel_rows:
        if row.session_date == session_date and row.slot == "open" and row.category == "intraday_mover":
            if row.symbol:
                syms.add(row.symbol.upper())
    return syms


def score_candidate(
    symbol: str,
    *,
    slot: str,
    tier: MonitorTier,
    snap: Snapshot | None,
    bars: list[Bar],
    ripple_verdict: str | None,
    ripple_confidence: float | None,
    catalyst_ticker: str | None,
    is_intraday_mover: bool,
    sector_breadth_positive: bool,
    suggestion_bias: str | None,
    held_morning_move: bool,
    av_positive: bool,
    is_user_favorite: bool = False,
) -> BuyingSignal:
    weights = SLOT_WEIGHTS.get(slot, SLOT_WEIGHTS["open"])
    score = 0.0
    tags: list[str] = []

    if ripple_verdict == "CONFIRMED" and (ripple_confidence is None or ripple_confidence >= 60):
        score += weights["ripple_confirmed"]
        conf = f" {ripple_confidence:.0f}%" if ripple_confidence is not None else ""
        tags.append(f"CONFIRMED ripple {catalyst_ticker}→{symbol} (conf{conf})")
    elif ripple_verdict == "FORMING" and (ripple_confidence is None or ripple_confidence >= 50):
        score += weights["ripple_forming"]
        conf = f" {ripple_confidence:.0f}%" if ripple_confidence is not None else ""
        tags.append(f"FORMING ripple {catalyst_ticker}→{symbol} (conf{conf})")
    elif ripple_verdict == "FAILED":
        score += weights["ripple_failed"]
        tags.append(f"FAILED ripple {catalyst_ticker}→{symbol}")

    if is_intraday_mover:
        score += weights["intraday_mover"]
        tags.append("intraday mover")

    if sector_breadth_positive:
        score += weights["sector_breadth"]
        tags.append("positive focus-sector breadth")

    if snap and snap.rsi is not None:
        if snap.rsi <= 30:
            score += weights["rsi_oversold"]
            tags.append(f"RSI oversold ({snap.rsi:.0f})")
        elif snap.rsi >= 70:
            score += weights["rsi_overbought"]
            tags.append(f"RSI overbought ({snap.rsi:.0f})")

    if suggestion_bias == "bullish":
        score += weights["suggestion_bullish"]
        tags.append("rule-based bullish bias")
    elif suggestion_bias == "bearish":
        score += weights["suggestion_bearish"]
        tags.append("rule-based bearish bias")

    if held_morning_move and slot == "midday":
        score += weights["midday_confirm"]
        tags.append("held morning move into midday")

    if av_positive and slot == "close":
        score += weights["av_fundamentals"]
        tags.append("AV fundamentals positive")

    if is_user_favorite:
        score += weights["user_favorite"]
        tags.append("user favorite")

    if snap and bars:
        _, dist_high = _trend_metrics(bars)
        if dist_high < -5 and snap.change_1d_pct < 0:
            score += weights["extended_pullback"]
            tags.append(f"extended below 30D high ({dist_high:+.1f}%)")

    if snap:
        rsi_txt = f", RSI {snap.rsi:.0f}" if snap.rsi is not None else ""
        tags.append(f"1D {snap.change_1d_pct:+.1f}%{rsi_txt}")

    stance: Literal["WATCH", "AVOID", "NEUTRAL"] = "NEUTRAL"
    if score >= WATCH_THRESHOLD:
        stance = "WATCH"
    elif score <= AVOID_THRESHOLD:
        stance = "AVOID"

    return BuyingSignal(
        symbol=symbol.upper(),
        score=round(score, 1),
        stance=stance,
        signals=tags,
        tier=tier.value,
    )


def rank_buying_signals(
    signals: list[BuyingSignal],
    *,
    favorites: set[str] | None = None,
) -> tuple[list[BuyingSignal], list[BuyingSignal]]:
    watch = sorted(
        [s for s in signals if s.stance == "WATCH"],
        key=lambda s: s.score,
        reverse=True,
    )
    avoid = sorted(
        [s for s in signals if s.stance == "AVOID"],
        key=lambda s: s.score,
    )[:2]

    watch = watch[:3]

    if favorites:
        fav_upper = {f.upper() for f in favorites}
        if not any(s.symbol in fav_upper for s in watch):
            fav_pool = [
                s
                for s in signals
                if s.symbol in fav_upper
                and s.score >= RESERVED_FAVORITE_MIN_SCORE
                and s.stance in ("NEUTRAL", "WATCH")
            ]
            if fav_pool:
                best = max(fav_pool, key=lambda s: s.score)
                promoted = BuyingSignal(
                    symbol=best.symbol,
                    score=best.score,
                    stance="WATCH",
                    signals=best.signals,
                    tier=best.tier,
                )
                if len(watch) >= 3:
                    watch = sorted(watch, key=lambda s: s.score)[:-1]
                watch.append(promoted)
                watch = sorted(watch, key=lambda s: s.score, reverse=True)[:3]

    return watch, avoid


def format_signals_for_packet(
    watch: list[BuyingSignal],
    avoid: list[BuyingSignal],
) -> list[str]:
    if not watch and not avoid:
        return ["No research signal candidates met thresholds for this session."]

    lines: list[str] = []
    if watch:
        lines.append("WATCH:")
        for i, sig in enumerate(watch, 1):
            tag_str = "; ".join(sig.signals[:6])
            lines.append(f"{i}. {sig.symbol} [score {sig.score:.0f}, {sig.tier}] — {tag_str}")
    if avoid:
        lines.append("AVOID:")
        for sig in avoid:
            tag_str = "; ".join(sig.signals[:5])
            lines.append(f"- {sig.symbol} [score {sig.score:.0f}, {sig.tier}] — {tag_str}")
    return lines


async def _load_histories(session: AsyncSession, symbols: list[str], days: int = 30) -> dict[str, list[Bar]]:
    from models.db_models import BarDaily

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


async def _latest_snapshots(session: AsyncSession) -> dict[str, Snapshot]:
    result = await session.execute(select(Snapshot).order_by(Snapshot.captured_at.desc()).limit(200))
    out: dict[str, Snapshot] = {}
    for snap in result.scalars().all():
        if snap.symbol not in out:
            out[snap.symbol] = snap
    return out


async def _recent_suggestions(session: AsyncSession) -> dict[str, str]:
    cutoff = datetime.now(timezone.utc) - timedelta(hours=4)
    result = await session.execute(
        select(AISuggestion)
        .where(AISuggestion.created_at >= cutoff)
        .order_by(AISuggestion.created_at.desc())
    )
    bias_by_sym: dict[str, str] = {}
    for row in result.scalars().all():
        if row.symbol not in bias_by_sym:
            bias_by_sym[row.symbol.upper()] = row.bias
    return bias_by_sym


async def build_buying_signals(session: AsyncSession, slot: str) -> tuple[list[BuyingSignal], list[BuyingSignal]]:
    tier_map = await build_tier_map(session)
    monitor = await get_monitor_settings(session)
    snapshots = await _latest_snapshots(session)
    catalysts = await load_catalysts(session)
    session_date = _session_date_key()
    favorites = await favorite_symbols(session)

    candidates = await monitored_symbol_set(session)
    for cat in catalysts:
        for rip_ticker, _ in cat.get("ripples", []):
            candidates.add(rip_ticker.upper())

    if not candidates:
        return [], []

    conf_by_cat = {c["ticker"]: c.get("confidence_score") for c in catalysts}

    histories = await _load_histories(session, list(candidates))
    ripple_results = analyze_ripples(histories, catalysts)

    ripple_by_sym: dict[str, tuple[str, str]] = {}
    for cat_ticker, rows in ripple_results.items():
        for r in rows:
            ripple_by_sym[r["ripple_ticker"].upper()] = (cat_ticker, r["verdict"])

    intel_rows = await fetch_intelligence_rows(session, session_date)
    open_movers = _open_mover_symbols(intel_rows, session_date)
    intraday_movers = {
        r.symbol.upper()
        for r in intel_rows
        if r.slot == slot and r.category == "intraday_mover" and r.symbol
    }

    sector_breadth_positive = False
    if monitor.focus_sector_id and monitor.focus_sector_id in SECTOR_BY_ID:
        sector = SECTOR_BY_ID[monitor.focus_sector_id]
        changes = [
            snapshots[s].change_1d_pct
            for s in sector.tickers
            if s in snapshots
        ]
        if changes:
            up = sum(1 for c in changes if c > 0)
            avg = sum(changes) / len(changes)
            sector_breadth_positive = up > len(changes) / 2 and avg > 0

    suggestion_bias = await _recent_suggestions(session)

    av_positive_syms: set[str] = set()
    if slot == "close":
        from services.daily_av_ingest import ensure_daily_av_bundle

        bundle = await ensure_daily_av_bundle(session)
        if bundle and bundle.fundamentals_summary:
            for sym in candidates:
                if sym in bundle.fundamentals_summary:
                    av_positive_syms.add(sym)

    scored: list[BuyingSignal] = []
    for sym in sorted(candidates):
        snap = snapshots.get(sym)
        tier = tier_map.get(sym, MonitorTier.COLD)
        cat_ticker, verdict = ripple_by_sym.get(sym, (None, None))
        confidence = conf_by_cat.get(cat_ticker) if cat_ticker else None

        held_morning = (
            sym in open_movers
            and snap is not None
            and (snap.change_5m_pct or 0) > 0
        )

        scored.append(
            score_candidate(
                sym,
                slot=slot,
                tier=tier,
                snap=snap,
                bars=histories.get(sym, []),
                ripple_verdict=verdict,
                ripple_confidence=confidence,
                catalyst_ticker=cat_ticker,
                is_intraday_mover=sym in intraday_movers,
                sector_breadth_positive=sector_breadth_positive,
                suggestion_bias=suggestion_bias.get(sym),
                held_morning_move=held_morning,
                av_positive=sym in av_positive_syms,
                is_user_favorite=sym in favorites,
            )
        )

    return rank_buying_signals(scored, favorites=favorites)

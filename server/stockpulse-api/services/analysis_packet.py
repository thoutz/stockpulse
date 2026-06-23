from __future__ import annotations

from datetime import datetime, timedelta, timezone
from zoneinfo import ZoneInfo

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from config import get_settings
from models.db_models import (
    AIAlert,
    AIReport,
    AISuggestion,
    BarDaily,
    Indicator,
    MarketObservation,
    NewsItem,
    Snapshot,
)
from services.buying_signals import build_buying_signals, format_signals_for_packet
from services.market_stats import build_massive_session_stats
from services.catalyst_catalog import load_catalysts
from services.daily_av_ingest import ensure_daily_av_bundle
from services.monitor_tiers import MonitorTier, build_tier_map, favorite_symbols, get_monitor_settings
from services.ripple_engine import Bar, analyze_ripples, post_event_change
from services.sector_catalog import SECTOR_BY_ID
from services.session_intelligence import fetch_intelligence_rows, format_intelligence_for_packet
from services.tracked import get_tracked_symbols

ET = ZoneInfo("America/New_York")

SESSION_WINDOWS: dict[str, tuple[str, str]] = {
    "open": ("09:30", "10:00"),
    "midday": ("10:00", "13:00"),
    "close": ("09:30", "16:00"),
}

PULSE_SYSTEM_PROMPT = """You are StockPulse AI Analyst synthesizing market pulse reports.
Data source: Finnhub live quotes (5m/15m intraday), Massive.com OHLCV and local RSI/SMA,
Monitor tier context (HOT/WARM/COLD), pre-computed session intelligence, plus once-daily
Alpha Vantage fundamentals/earnings/breadth for the close report. Verdicts: CONFIRMED, FORMING, FAILED, WATCHING.

Rules:
- Answer using ONLY the analysis packet below.
- Be direct, actionable, and session-aware.
- Prioritize HOT tier movers and session intelligence intraday_mover rows for open/midday.
- USER FAVORITES (listed explicitly below) are user-chosen tickers — include them in What's New when they have material moves (>0.5pp vs prior pulse, intraday mover status, RSI cross, or alert), even if not in the bundled config watchlist.
- Context may reference USER FAVORITES for stable background when relevant.
- For pulse_close: synthesize intraday data WITH the Alpha Vantage daily bundle.
- Cite tickers and % moves when relevant.
- Always use signed percentages (+4.2% for gains, -4.2% for losses); never write unsigned percentages after directional words.
- Frame outputs as analysis, not guaranteed predictions.
- Research Watchlist section: cite ONLY tickers listed under RESEARCH SIGNALS.
- Each Research Watchlist bullet must name specific signal tags (verdict, confidence %, RSI, tier).
- Frame Research Watchlist as research context for watchlist monitoring — NOT financial advice.
- Omit Research Watchlist entirely if RESEARCH SIGNALS says no candidates."""

CHAT_SYSTEM_PROMPT = """You are StockPulse AI Analyst answering user questions.
Use ONLY the context below (snapshots, recent observations, news, ripple verdicts).
Be direct and actionable in 2–8 sentences unless comparing multiple tickers.
Always use signed percentages (+4.2% for gains, -4.2% for losses); never write unsigned percentages after directional words."""


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


async def _latest_snapshots(session: AsyncSession) -> dict[str, Snapshot]:
    result = await session.execute(select(Snapshot).order_by(Snapshot.captured_at.desc()).limit(200))
    out: dict[str, Snapshot] = {}
    for snap in result.scalars().all():
        if snap.symbol not in out:
            out[snap.symbol] = snap
    return out


def _et_now() -> datetime:
    return datetime.now(ET)


def _session_date_key() -> str:
    return _et_now().strftime("%Y-%m-%d")


def _format_user_favorites_section(
    favorites: set[str],
    *,
    snapshots: dict[str, Snapshot],
    tier_map: dict[str, MonitorTier],
) -> list[str]:
    lines = [
        "\n=== USER FAVORITES (user-added — prioritize in What's New and Research Watchlist) ==="
    ]
    if not favorites:
        lines.append("- None saved")
        return lines

    for sym in sorted(favorites):
        tier = tier_map.get(sym, MonitorTier.WARM)
        snap = snapshots.get(sym)
        if snap:
            rsi = f", RSI {snap.rsi:.0f}" if snap.rsi is not None else ""
            m5 = f", 5m {snap.change_5m_pct:+.1f}%" if snap.change_5m_pct is not None else ""
            m15 = f", 15m {snap.change_15m_pct:+.1f}%" if snap.change_15m_pct is not None else ""
            lines.append(
                f"- {sym} [{tier.value}]: ${snap.price:.2f}, 1D {snap.change_1d_pct:+.1f}%, "
                f"30D {snap.change_30d_pct:+.1f}%{m5}{m15}{rsi}"
            )
        else:
            lines.append(f"- {sym} [{tier.value}]: (no snapshot yet — data pending)")
    return lines


async def build_pulse_analysis_packet(
    session: AsyncSession,
    session_slot: str = "open",
    since: datetime | None = None,
) -> str:
    settings = get_settings()
    lines: list[str] = []
    now_et = _et_now()
    window = SESSION_WINDOWS.get(session_slot, SESSION_WINDOWS["open"])

    lines.append(PULSE_SYSTEM_PROMPT)
    lines.append(
        f"\n=== SESSION ===\nSlot: {session_slot} | Window: {window[0]}–{window[1]} ET | "
        f"Generated: {now_et.strftime('%Y-%m-%d %H:%M %Z')}"
    )
    if since:
        ago = now_et - since.astimezone(ET)
        mins = int(ago.total_seconds() // 60)
        lines.append(f"Prior pulse: {mins} minutes ago ({since.astimezone(ET).strftime('%H:%M ET')})")

    tier_map = await build_tier_map(session)
    monitor = await get_monitor_settings(session)
    intel_rows = await fetch_intelligence_rows(session, _session_date_key(), slot=session_slot)
    if intel_rows:
        lines.append("\n=== SESSION INTELLIGENCE (pre-computed) ===")
        lines.extend(format_intelligence_for_packet(intel_rows, session_slot))
    elif monitor.focus_sector_id or any(t == MonitorTier.HOT for t in tier_map.values()):
        lines.append("\n=== SESSION INTELLIGENCE ===")
        lines.append("- Pre-pulse intelligence not yet generated for this slot.")

    if monitor.focus_sector_id and monitor.focus_sector_id in SECTOR_BY_ID:
        sector = SECTOR_BY_ID[monitor.focus_sector_id]
        lines.append(f"\n=== MONITOR FOCUS ===\nSector: {sector.name} ({monitor.focus_sector_id})")
    else:
        lines.append("\n=== MONITOR FOCUS ===\nNo sector focus selected.")

    snapshots = await _latest_snapshots(session)
    favorites = await favorite_symbols(session)
    lines.extend(
        _format_user_favorites_section(
            favorites,
            snapshots=snapshots,
            tier_map=tier_map,
        )
    )
    if snapshots:
        lines.append("\n=== TICKER SNAPSHOTS (tier-aware) ===")
        for sym in sorted(snapshots.keys()):
            s = snapshots[sym]
            tier = tier_map.get(sym, MonitorTier.COLD)
            rsi = f", RSI {s.rsi:.1f}" if s.rsi is not None else ""
            sma = f", vs SMA20 {((s.price - s.sma_20) / s.sma_20 * 100):+.1f}%" if s.sma_20 else ""
            m5 = f", 5m {s.change_5m_pct:+.1f}%" if s.change_5m_pct is not None else ""
            m15 = f", 15m {s.change_15m_pct:+.1f}%" if s.change_15m_pct is not None else ""
            src = f", src={s.quote_source}" if s.quote_source else ""
            lines.append(
                f"{sym} [{tier.value}]: ${s.price:.2f}, 1D {s.change_1d_pct:+.1f}%, "
                f"30D {s.change_30d_pct:+.1f}%{m5}{m15}{rsi}{sma}{src}"
            )

    if since:
        obs_result = await session.execute(
            select(MarketObservation)
            .where(MarketObservation.created_at > since)
            .order_by(MarketObservation.created_at.desc())
            .limit(25)
        )
    else:
        obs_result = await session.execute(
            select(MarketObservation)
            .where(MarketObservation.session_date == _session_date_key())
            .order_by(MarketObservation.created_at.desc())
            .limit(25)
        )
    observations = obs_result.scalars().all()
    if observations:
        lines.append("\n=== INTRADAY EVENTS (since last pulse) ===")
        for o in reversed(observations):
            lines.append(f"- [{o.observation_type}] {o.message} ({o.change_pct:+.1f}%, {o.window_minutes}m window)")

    news_cutoff = since or (datetime.now(timezone.utc) - timedelta(hours=24))
    news_result = await session.execute(
        select(NewsItem)
        .where(NewsItem.published_at >= news_cutoff)
        .order_by(NewsItem.published_at.desc())
        .limit(20)
    )
    news_rows = news_result.scalars().all()
    if news_rows:
        lines.append("\n=== NEWS SINCE LAST PULSE ===")
        for n in news_rows:
            pub = n.published_at.astimezone(ET).strftime("%H:%M ET")
            src = f" ({n.source})" if n.source else ""
            lines.append(f"- {n.symbol}: {n.headline}{src} [{pub}]")

    tracked = await get_tracked_symbols(session)
    symbols = sorted(set(tracked) | set(snapshots.keys()))

    session_stats = await build_massive_session_stats(session, symbols)
    if session_stats:
        lines.append("\n=== INTRADAY STATS (Massive — gaps, volume, sectors) ===")
        lines.extend(f"- {line}" for line in session_stats)

    histories = await _load_histories(session, symbols, days=settings.hot_days)
    catalysts = await load_catalysts(session)

    lines.append("\n=== 30-DAY TREND SUMMARY ===")
    for sym in sorted(histories.keys()):
        bars = histories[sym]
        if len(bars) < 2:
            continue
        first, last = bars[0].close, bars[-1].close
        pct = ((last - first) / first * 100) if first > 0 else 0
        high = max(b.close for b in bars)
        low = min(b.close for b in bars)
        dist_high = ((last - high) / high * 100) if high > 0 else 0
        direction = "up" if pct > 2 else "down" if pct < -2 else "flat"
        lines.append(
            f"{sym}: 30D {pct:+.1f}% ({direction}), {dist_high:+.1f}% from 30D high, low ${low:.2f} high ${high:.2f}"
        )

    ripple_results = analyze_ripples(histories, catalysts)
    lines.append("\n=== CATALYSTS & RIPPLE NETWORKS ===")
    for cat in catalysts:
        event_dt = datetime.strptime(cat["event_date"], "%Y-%m-%d").replace(tzinfo=timezone.utc)
        cat_hist = histories.get(cat["ticker"], [])
        post = post_event_change(cat_hist, event_dt) if cat_hist else 0
        days_since = (datetime.now(timezone.utc) - event_dt).days
        lines.append(f"\n--- {cat['ticker']} ({cat['name']}) ---")
        lines.append(f"Event: {cat['event_name']} on {cat['event_date']} ({days_since}d ago)")
        lines.append(f"Catalyst post-event move: {post:+.1f}%")
        for r in ripple_results.get(cat["ticker"], []):
            conf = ""
            if cat.get("confidence_score") is not None:
                conf = f", confidence {cat['confidence_score']:.0f}%"
            lines.append(
                f"  {r['ripple_ticker']}: {r['verdict']}, post {r['post_event_pct']:+.1f}%{conf}"
            )

    ind_result = await session.execute(
        select(Indicator).order_by(Indicator.symbol, Indicator.bar_ts.desc()).limit(50)
    )
    seen_ind: set[tuple[str, str]] = set()
    flags: list[str] = []
    for ind in ind_result.scalars().all():
        key = (ind.symbol, ind.indicator_type)
        if key in seen_ind:
            continue
        seen_ind.add(key)
        if ind.indicator_type == "RSI":
            if ind.value >= 70:
                flags.append(f"{ind.symbol} RSI overbought ({ind.value:.1f})")
            elif ind.value <= 30:
                flags.append(f"{ind.symbol} RSI oversold ({ind.value:.1f})")
    if flags:
        lines.append("\n=== TECHNICAL FLAGS ===")
        lines.extend(f"- {f}" for f in flags[:15])

    watch, avoid = await build_buying_signals(session, session_slot)
    lines.append("\n=== RESEARCH SIGNALS (pre-computed — cite ONLY these in Research Watchlist) ===")
    lines.extend(format_signals_for_packet(watch, avoid))

    suggestion_cutoff = datetime.now(timezone.utc) - timedelta(hours=4)
    suggestion_result = await session.execute(
        select(AISuggestion)
        .where(AISuggestion.created_at >= suggestion_cutoff)
        .order_by(AISuggestion.created_at.desc())
        .limit(15)
    )
    suggestions = suggestion_result.scalars().all()
    if suggestions:
        lines.append("\n=== RULE-BASED BIAS (hourly) ===")
        for s in suggestions:
            lines.append(f"- {s.symbol} {s.bias}: {s.summary[:100]}")

    if since:
        alert_result = await session.execute(
            select(AIAlert)
            .where(AIAlert.created_at > since)
            .order_by(AIAlert.created_at.desc())
            .limit(10)
        )
        alerts = alert_result.scalars().all()
        if alerts:
            lines.append("\n=== ALERTS SINCE LAST PULSE ===")
            for a in alerts:
                lines.append(f"- {a.symbol} {a.change_pct:+.1f}%: {a.message[:120]}")

    if session_slot == "close":
        bundle = await ensure_daily_av_bundle(session)
        if bundle:
            lines.append("\n=== ALPHA VANTAGE DAILY BUNDLE (close report — synthesize with Massive data) ===")
            lines.append("\n-- Upcoming earnings (tracked tickers) --")
            lines.append(bundle.earnings_summary)
            lines.append("\n-- Market breadth (US) --")
            lines.append(bundle.market_breadth)
            lines.append("\n-- Fundamentals snapshot --")
            lines.append(bundle.fundamentals_summary)
            lines.append("\n-- 24h news sentiment aggregate --")
            lines.append(bundle.news_sentiment_summary)
        else:
            lines.append("\n=== ALPHA VANTAGE DAILY BUNDLE ===\nNot available (AV key missing or ingest pending).")

    return "\n".join(lines)


async def build_chat_context(session: AsyncSession) -> str:
    lines: list[str] = [CHAT_SYSTEM_PROMPT]
    lines.append(f"\n[Data freshness] Server UTC: {datetime.now(timezone.utc).isoformat()}")

    tier_map = await build_tier_map(session)
    snapshots = await _latest_snapshots(session)
    favorites = await favorite_symbols(session)
    lines.extend(
        _format_user_favorites_section(
            favorites,
            snapshots=snapshots,
            tier_map=tier_map,
        )
    )

    if snapshots:
        lines.append("\n=== SNAPSHOTS ===")
        for sym in sorted(snapshots.keys()):
            s = snapshots[sym]
            rsi = f", RSI {s.rsi:.1f}" if s.rsi is not None else ""
            lines.append(f"{sym}: ${s.price:.2f}, 1D {s.change_1d_pct:+.1f}%, 30D {s.change_30d_pct:+.1f}%{rsi}")

    cutoff = datetime.now(timezone.utc) - timedelta(hours=4)
    obs_result = await session.execute(
        select(MarketObservation)
        .where(MarketObservation.created_at >= cutoff)
        .order_by(MarketObservation.created_at.desc())
        .limit(15)
    )
    observations = obs_result.scalars().all()
    if observations:
        lines.append("\n=== RECENT OBSERVATIONS (4h) ===")
        for o in observations:
            lines.append(f"- {o.symbol}: {o.message}")

    news_cutoff = datetime.now(timezone.utc) - timedelta(hours=24)
    news_result = await session.execute(
        select(NewsItem)
        .where(NewsItem.published_at >= news_cutoff)
        .order_by(NewsItem.published_at.desc())
        .limit(10)
    )
    for n in news_result.scalars().all():
        lines.append(f"- NEWS {n.symbol}: {n.headline[:120]}")

    last_pulse = (
        await session.execute(
            select(AIReport)
            .where(AIReport.report_type.like("pulse%"))
            .order_by(AIReport.created_at.desc())
            .limit(1)
        )
    ).scalar_one_or_none()
    if last_pulse:
        lines.append(f"\n=== LATEST PULSE ({last_pulse.report_type}) ===")
        lines.append(f"{last_pulse.title}: {last_pulse.body[:600]}")

    tracked = await get_tracked_symbols(session)
    ripple_symbols = sorted(set(tracked))[:20]
    histories = await _load_histories(session, ripple_symbols, days=30)
    catalysts = await load_catalysts(session)
    ripple_results = analyze_ripples(histories, catalysts)
    lines.append("\n=== RIPPLE VERDICTS ===")
    for cat_ticker, rows in ripple_results.items():
        for r in rows:
            lines.append(f"{cat_ticker}→{r['ripple_ticker']}: {r['verdict']} (post {r['post_event_pct']:+.1f}%)")

    return "\n".join(lines)

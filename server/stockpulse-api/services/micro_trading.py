"""Intraday momentum scanner and exit rules for micro day-trading."""

from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime
from zoneinfo import ZoneInfo

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from config import get_settings
from models.db_models import Snapshot
from services.buying_signals import build_buying_signals
from services.fractional_trading import fetch_asset_eligibility
from services.monitor_tiers import favorite_symbols
from services.monitor_universe import monitored_symbol_set
from services.risk_engine import TradeIntent, validate_trade_intent
from services.session_intelligence import fetch_intelligence_rows

ET = ZoneInfo("America/New_York")


@dataclass
class MicroExitSignal:
    symbol: str
    qty: float
    reason: str
    signal_source: str
    unrealized_plpc: float


@dataclass
class MicroScanResult:
    symbol: str
    score: float
    change_5m_pct: float | None
    change_15m_pct: float | None
    rationale: str
    entry_reason: str


def _current_signal_slot() -> str:
    now = datetime.now(ET)
    minutes = now.hour * 60 + now.minute
    if minutes < 13 * 60:
        return "open"
    if minutes < 16 * 60:
        return "midday"
    return "close"


def _session_date_key() -> str:
    return datetime.now(ET).strftime("%Y-%m-%d")


def _is_past_entry_cutoff() -> bool:
    settings = get_settings()
    now = datetime.now(ET)
    cutoff = settings.micro_entry_cutoff_hour * 60 + settings.micro_entry_cutoff_minute
    return now.hour * 60 + now.minute >= cutoff


def _is_eod_flat_window() -> bool:
    settings = get_settings()
    if not settings.micro_eod_flat_enabled:
        return False
    now = datetime.now(ET)
    flat_at = settings.micro_eod_flat_hour * 60 + settings.micro_eod_flat_minute
    return now.hour * 60 + now.minute >= flat_at


def is_daily_profit_cap_hit(day_pl: float) -> bool:
    settings = get_settings()
    cap = settings.micro_daily_profit_cap_usd
    return cap > 0 and day_pl >= cap


async def _latest_snapshots(session: AsyncSession) -> dict[str, Snapshot]:
    result = await session.execute(select(Snapshot).order_by(Snapshot.captured_at.desc()).limit(300))
    out: dict[str, Snapshot] = {}
    for snap in result.scalars().all():
        if snap.symbol not in out:
            out[snap.symbol] = snap
    return out


async def _intraday_mover_symbols(session: AsyncSession, slot: str) -> set[str]:
    session_date = _session_date_key()
    rows = await fetch_intelligence_rows(session, session_date)
    return {
        r.symbol.upper()
        for r in rows
        if r.slot == slot and r.category == "intraday_mover" and r.symbol
    }


def _entry_trigger(
    sym: str,
    snap: Snapshot,
    *,
    watch_by_sym: dict,
    intraday_movers: set[str],
    favorites: set[str],
) -> tuple[bool, str, float]:
    """Return (should_enter, reason_tag, score_boost)."""
    settings = get_settings()
    m5 = snap.change_5m_pct
    m15 = snap.change_15m_pct
    day_chg = snap.change_1d_pct or 0.0

    if sym in watch_by_sym:
        ws = watch_by_sym[sym]
        return True, f"WATCH score {ws.score:.0f}", min(30.0, ws.score * 0.4)

    if sym in intraday_movers:
        return True, "intraday mover", 18.0

    if m5 is not None and m5 >= settings.micro_min_momentum_5m_pct:
        if m5 <= settings.micro_max_momentum_5m_pct:
            return True, f"5m momentum {m5:+.2f}%", m5 * 14.0

    if m15 is not None and m15 >= settings.micro_min_momentum_15m_pct:
        if m5 is None or m5 <= settings.micro_max_momentum_5m_pct:
            return True, f"15m momentum {m15:+.2f}%", m15 * 10.0

    if day_chg > 0 and m5 is not None and m5 >= settings.micro_slow_grind_5m_pct:
        if m15 is None or m15 >= 0:
            return True, f"slow grind 1D {day_chg:+.1f}% 5m {m5:+.2f}%", 8.0 + day_chg

    if sym in favorites and day_chg > 0 and (m5 or 0) >= 0:
        return True, f"favorite green day {day_chg:+.1f}%", 12.0 + day_chg * 0.5

    return False, "", 0.0


async def scan_micro_entries(session: AsyncSession) -> list[MicroScanResult]:
    """Rank all Monitor symbols with a valid entry signal."""
    if _is_past_entry_cutoff():
        return []

    settings = get_settings()
    universe = await monitored_symbol_set(session)
    snapshots = await _latest_snapshots(session)
    favorites = await favorite_symbols(session)
    slot = _current_signal_slot()

    watch, avoid = await build_buying_signals(session, slot)
    avoid_syms = {s.symbol.upper() for s in avoid}
    watch_by_sym = {s.symbol.upper(): s for s in watch}
    intraday_movers = await _intraday_mover_symbols(session, slot)

    scored: list[MicroScanResult] = []
    for sym in sorted(universe):
        if sym in avoid_syms:
            continue
        snap = snapshots.get(sym)
        if snap is None or snap.price is None or snap.price <= 0:
            continue

        m5 = snap.change_5m_pct
        m15 = snap.change_15m_pct
        if m5 is not None and m5 > settings.micro_max_momentum_5m_pct and sym not in watch_by_sym:
            continue
        if m15 is not None and m15 < -0.5 and sym not in watch_by_sym:
            continue

        ok, reason_tag, boost = _entry_trigger(
            sym,
            snap,
            watch_by_sym=watch_by_sym,
            intraday_movers=intraday_movers,
            favorites=favorites,
        )
        if not ok:
            continue

        score = boost
        if sym in favorites:
            score += 6.0

        tags = [reason_tag]
        if m5 is not None:
            tags.append(f"5m {m5:+.2f}%")
        if m15 is not None:
            tags.append(f"15m {m15:+.2f}%")

        scored.append(
            MicroScanResult(
                symbol=sym,
                score=round(score, 2),
                change_5m_pct=m5,
                change_15m_pct=m15,
                rationale="Monitor signal: " + ", ".join(tags),
                entry_reason=reason_tag,
            )
        )

    scored.sort(key=lambda r: r.score, reverse=True)
    return scored


def micro_scan_to_intent(result: MicroScanResult) -> TradeIntent:
    settings = get_settings()
    notional = max(settings.micro_trade_notional, settings.min_fractional_notional)
    confidence = min(0.95, 0.76 + result.score / 100.0)
    return TradeIntent(
        action="BUY",
        symbol=result.symbol,
        confidence=round(confidence, 2),
        notional_usd=notional,
        rationale=result.rationale + f" (buy ${notional:.2f})",
        signal_source="micro_momentum",
        buying_signal_score=result.score,
    )


async def build_micro_entry_intents(
    session: AsyncSession,
    *,
    equity: float,
    buying_power: float,
    open_position_symbols: set[str],
    position_count: int,
    day_pl_pct: float,
) -> list[TradeIntent]:
    scans = await scan_micro_entries(session)
    intents: list[TradeIntent] = []
    for scan in scans:
        try:
            eligibility = await fetch_asset_eligibility(scan.symbol)
            if not eligibility.can_fractional_buy:
                continue
        except Exception:
            continue

        intent = micro_scan_to_intent(scan)
        approved, _reason = validate_trade_intent(
            intent,
            equity=equity,
            buying_power=buying_power,
            open_position_symbols=open_position_symbols,
            position_count=position_count + len(intents),
            day_pl_pct=day_pl_pct,
        )
        if approved:
            intents.append(approved)
    return intents


def evaluate_micro_exits(positions: list[dict]) -> list[MicroExitSignal]:
    """Take-profit / stop-loss on open long positions."""
    settings = get_settings()
    tp = settings.micro_take_profit_pct
    sl = settings.micro_stop_loss_pct
    signals: list[MicroExitSignal] = []

    for pos in positions:
        sym = str(pos.get("symbol", "")).upper()
        qty = float(pos.get("qty") or 0)
        if qty <= 0:
            continue
        plpc = float(pos.get("unrealized_plpc") or 0)
        if plpc >= tp:
            signals.append(
                MicroExitSignal(
                    symbol=sym,
                    qty=qty,
                    reason=f"Take profit {plpc:+.2f}% (target +{tp:.2f}%)",
                    signal_source="micro_take_profit",
                    unrealized_plpc=plpc,
                )
            )
        elif plpc <= -sl:
            signals.append(
                MicroExitSignal(
                    symbol=sym,
                    qty=qty,
                    reason=f"Stop loss {plpc:+.2f}% (limit -{sl:.2f}%)",
                    signal_source="micro_stop_loss",
                    unrealized_plpc=plpc,
                )
            )
    return signals


def evaluate_momentum_flip_exits(
    positions: list[dict],
    snapshots: dict[str, Snapshot],
) -> list[MicroExitSignal]:
    """Sell when short-term momentum turns down (5m rollover)."""
    settings = get_settings()
    flip_at = settings.micro_momentum_flip_5m_pct
    signals: list[MicroExitSignal] = []

    for pos in positions:
        sym = str(pos.get("symbol", "")).upper()
        qty = float(pos.get("qty") or 0)
        if qty <= 0:
            continue
        snap = snapshots.get(sym)
        if snap is None or snap.change_5m_pct is None:
            continue
        m5 = snap.change_5m_pct
        if m5 > flip_at:
            continue
        plpc = float(pos.get("unrealized_plpc") or 0)
        signals.append(
            MicroExitSignal(
                symbol=sym,
                qty=qty,
                reason=f"Momentum flip 5m {m5:+.2f}% (threshold {flip_at:+.2f}%)",
                signal_source="micro_momentum_flip",
                unrealized_plpc=plpc,
            )
        )
    return signals


def evaluate_all_micro_exits(
    positions: list[dict],
    snapshots: dict[str, Snapshot],
) -> list[MicroExitSignal]:
    """TP/SL first, then momentum flip; one signal per symbol."""
    seen: set[str] = set()
    out: list[MicroExitSignal] = []
    for sig in evaluate_micro_exits(positions):
        if sig.symbol not in seen:
            out.append(sig)
            seen.add(sig.symbol)
    for sig in evaluate_momentum_flip_exits(positions, snapshots):
        if sig.symbol not in seen:
            out.append(sig)
            seen.add(sig.symbol)
    return out


def evaluate_eod_flat_exits(positions: list[dict]) -> list[MicroExitSignal]:
    """Close all longs before the bell when enabled."""
    if not _is_eod_flat_window():
        return []
    signals: list[MicroExitSignal] = []
    for pos in positions:
        sym = str(pos.get("symbol", "")).upper()
        qty = float(pos.get("qty") or 0)
        if qty <= 0:
            continue
        plpc = float(pos.get("unrealized_plpc") or 0)
        signals.append(
            MicroExitSignal(
                symbol=sym,
                qty=qty,
                reason=f"End-of-day flat {plpc:+.2f}%",
                signal_source="micro_eod_flat",
                unrealized_plpc=plpc,
            )
        )
    return signals


def micro_trading_config_payload() -> dict:
    settings = get_settings()
    return {
        "micro_trade_enabled": settings.micro_trade_enabled,
        "micro_scan_interval_minutes": settings.micro_scan_interval_minutes,
        "micro_trade_notional": settings.micro_trade_notional,
        "micro_take_profit_pct": settings.micro_take_profit_pct,
        "micro_stop_loss_pct": settings.micro_stop_loss_pct,
        "micro_daily_profit_cap_usd": settings.micro_daily_profit_cap_usd,
        "micro_min_momentum_5m_pct": settings.micro_min_momentum_5m_pct,
        "micro_max_momentum_5m_pct": settings.micro_max_momentum_5m_pct,
        "trading_universe": "all_monitor_symbols",
    }

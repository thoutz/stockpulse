"""Build trade proposals from research signals (WATCH list)."""

from __future__ import annotations

from datetime import datetime
from zoneinfo import ZoneInfo

from sqlalchemy.ext.asyncio import AsyncSession

from config import get_settings
from services.buying_signals import build_buying_signals
from services.fractional_trading import fetch_asset_eligibility
from services.risk_engine import TradeIntent, validate_trade_intent

ET = ZoneInfo("America/New_York")


def _current_signal_slot() -> str:
    now = datetime.now(ET)
    minutes = now.hour * 60 + now.minute
    if minutes < 13 * 60:
        return "open"
    if minutes < 16 * 60:
        return "midday"
    return "close"


def _score_to_confidence(score: float) -> float:
    # WATCH threshold is 15 → min_confidence (0.75); stronger signals → up to 0.95
    return min(0.95, max(0.75, 0.75 + (score - 15) / 80))


async def propose_from_watchlist(
    session: AsyncSession,
    *,
    equity: float,
    buying_power: float,
    open_position_symbols: set[str],
    position_count: int,
    day_pl_pct: float,
    symbol: str | None = None,
) -> list[TradeIntent]:
    settings = get_settings()
    slot = _current_signal_slot()
    watch, _avoid = await build_buying_signals(session, slot)

    if symbol:
        sym = symbol.upper()
        watch = [s for s in watch if s.symbol == sym]

    intents: list[TradeIntent] = []
    for sig in watch[:3]:
        try:
            eligibility = await fetch_asset_eligibility(sig.symbol)
            if not eligibility.can_fractional_buy:
                continue
        except Exception:
            continue

        confidence = _score_to_confidence(sig.score)
        notional = max(settings.default_trade_notional, settings.min_fractional_notional)
        intent = TradeIntent(
            action="BUY",
            symbol=sig.symbol,
            confidence=round(confidence, 2),
            notional_usd=notional,
            rationale=(
                f"WATCH score {sig.score} (fractional buy ${notional:.2f}): "
                + "; ".join(sig.signals[:4])
            ),
            signal_source=f"watch_{slot}",
            buying_signal_score=sig.score,
        )
        approved, _reason = validate_trade_intent(
            intent,
            equity=equity,
            buying_power=buying_power,
            open_position_symbols=open_position_symbols,
            position_count=position_count,
            day_pl_pct=day_pl_pct,
        )
        if approved:
            intents.append(approved)

    return intents

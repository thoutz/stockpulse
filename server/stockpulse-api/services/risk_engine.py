"""Hard rules before any order reaches Alpaca."""

from __future__ import annotations

from dataclasses import dataclass

from config import get_settings


@dataclass
class TradeIntent:
    action: str
    symbol: str
    confidence: float
    notional_usd: float
    rationale: str
    signal_source: str | None = None
    buying_signal_score: float | None = None


def validate_trade_intent(
    intent: TradeIntent,
    *,
    equity: float,
    buying_power: float,
    open_position_symbols: set[str],
    position_count: int,
    day_pl_pct: float,
) -> tuple[TradeIntent | None, str | None]:
    settings = get_settings()

    if intent.action.upper() == "HOLD":
        return None, "hold"

    if intent.confidence < settings.min_confidence:
        return None, f"confidence {intent.confidence:.2f} below min {settings.min_confidence}"

    if intent.notional_usd < settings.min_fractional_notional:
        return None, f"notional below ${settings.min_fractional_notional:.2f} Alpaca fractional minimum"

    max_notional = equity * (settings.max_position_pct / 100.0)
    if intent.notional_usd > max_notional:
        intent.notional_usd = round(max_notional, 2)

    if day_pl_pct <= -settings.daily_loss_limit_pct:
        return None, f"daily loss limit hit ({day_pl_pct:.1f}%)"

    action = intent.action.upper()
    sym = intent.symbol.upper()

    if action == "BUY":
        if position_count >= settings.max_positions:
            return None, f"max positions ({settings.max_positions}) reached"
        if sym in open_position_symbols:
            return None, f"already hold {sym}"
        if buying_power < intent.notional_usd:
            return None, f"insufficient buying power (${buying_power:.2f})"

    if action == "SELL":
        if sym not in open_position_symbols:
            return None, f"no open position in {sym}"

    return intent, None

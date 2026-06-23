"""Alpaca fractional share rules — https://docs.alpaca.markets/us/docs/fractional-trading"""

from __future__ import annotations

from dataclasses import dataclass
from typing import Any

from alpaca.trading.enums import OrderSide, TimeInForce
from alpaca.trading.requests import MarketOrderRequest

from config import get_settings
from services.alpaca_client import get_trading_client


class FractionalTradingError(ValueError):
    """Order rejected before reaching Alpaca."""


@dataclass(frozen=True)
class AssetEligibility:
    symbol: str
    tradable: bool
    fractionable: bool
    status: str
    exchange: str | None = None
    name: str | None = None

    @property
    def can_fractional_buy(self) -> bool:
        return self.tradable and self.fractionable and self.status.lower() == "active"

    def to_dict(self) -> dict[str, Any]:
        return {
            "symbol": self.symbol,
            "tradable": self.tradable,
            "fractionable": self.fractionable,
            "status": self.status,
            "exchange": self.exchange,
            "name": self.name,
            "can_fractional_buy": self.can_fractional_buy,
        }


def normalize_notional(notional: float) -> float:
    """Alpaca accepts notional with up to 9 decimals; we round to cents."""
    settings = get_settings()
    minimum = settings.min_fractional_notional
    value = round(float(notional), 2)
    if value < minimum:
        raise FractionalTradingError(
            f"Notional ${value:.2f} below Alpaca minimum ${minimum:.2f} for fractional orders"
        )
    return value


def normalize_qty(qty: float) -> float:
    """Fractional qty — Alpaca supports up to 9 decimal places."""
    value = float(qty)
    if value <= 0:
        raise FractionalTradingError("Sell qty must be positive")
    return round(value, 9)


async def fetch_asset_eligibility(symbol: str) -> AssetEligibility:
    import asyncio

    client = get_trading_client()
    sym = symbol.upper()
    try:
        asset = await asyncio.to_thread(client.get_asset, sym)
    except Exception as exc:
        raise FractionalTradingError(f"Unknown or inaccessible asset {sym}: {exc}") from exc

    return AssetEligibility(
        symbol=sym,
        tradable=bool(getattr(asset, "tradable", False)),
        fractionable=bool(getattr(asset, "fractionable", False)),
        status=str(getattr(asset, "status", "unknown")),
        exchange=getattr(asset, "exchange", None),
        name=getattr(asset, "name", None),
    )


async def assert_fractional_buy_allowed(symbol: str) -> AssetEligibility:
    eligibility = await fetch_asset_eligibility(symbol)
    if not eligibility.can_fractional_buy:
        if not eligibility.fractionable:
            raise FractionalTradingError(
                f"{eligibility.symbol} is not fractionable on Alpaca "
                "(requested asset is not fractionable)"
            )
        if not eligibility.tradable:
            raise FractionalTradingError(f"{eligibility.symbol} is not tradable")
        raise FractionalTradingError(
            f"{eligibility.symbol} status is {eligibility.status!r}, expected active"
        )
    return eligibility


async def submit_fractional_buy(symbol: str, notional: float) -> dict[str, Any]:
    """
    Market DAY buy by dollar amount (notional).
    Per Alpaca: pass notional OR qty, never both. Market orders only for fractional.
    """
    import asyncio

    from services.alpaca_service import _order_to_dict

    sym = symbol.upper()
    await assert_fractional_buy_allowed(sym)
    dollars = normalize_notional(notional)

    client = get_trading_client()
    req = MarketOrderRequest(
        symbol=sym,
        notional=dollars,
        side=OrderSide.BUY,
        time_in_force=TimeInForce.DAY,
    )
    order = await asyncio.to_thread(client.submit_order, req)
    out = _order_to_dict(order)
    out["order_style"] = "fractional_notional"
    out["notional_requested"] = dollars
    return out


async def submit_fractional_sell_qty(symbol: str, qty: float) -> dict[str, Any]:
    """
    Market DAY sell by fractional share qty (long only — no short fractional).
    """
    import asyncio

    from services.alpaca_service import _order_to_dict

    sym = symbol.upper()
    shares = normalize_qty(qty)

    client = get_trading_client()
    req = MarketOrderRequest(
        symbol=sym,
        qty=shares,
        side=OrderSide.SELL,
        time_in_force=TimeInForce.DAY,
    )
    order = await asyncio.to_thread(client.submit_order, req)
    out = _order_to_dict(order)
    out["order_style"] = "fractional_qty"
    out["qty_requested"] = shares
    return out


async def submit_fractional_trade(
    action: str,
    symbol: str,
    *,
    notional: float | None = None,
    position_qty: float | None = None,
) -> dict[str, Any]:
    """
    Route BUY → notional market order; SELL → qty market order (full position qty).
    """
    act = action.upper()
    if act == "BUY":
        if notional is None:
            raise FractionalTradingError("BUY requires notional amount")
        return await submit_fractional_buy(symbol, notional)
    if act == "SELL":
        if position_qty is None or position_qty <= 0:
            raise FractionalTradingError("SELL requires open position qty")
        return await submit_fractional_sell_qty(symbol, position_qty)
    raise FractionalTradingError(f"Unsupported action {action!r}")

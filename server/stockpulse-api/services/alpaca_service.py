"""Read/write helpers for Alpaca Trading API."""

from __future__ import annotations

import asyncio
from datetime import datetime, timezone
from typing import Any

from alpaca.trading.enums import QueryOrderStatus
from alpaca.trading.requests import GetOrdersRequest

from config import get_settings
from services.alpaca_client import get_trading_client, is_alpaca_configured
from services.auto_trade_state import auto_trade_status_extras
from services.micro_trade_state import micro_trade_status_extras
from services.trading_settings import is_auto_trade_enabled


def _run_sync(fn, *args, **kwargs):
    return asyncio.to_thread(fn, *args, **kwargs)


def trading_status_payload() -> dict[str, Any]:
    settings = get_settings()
    return {
        "configured": is_alpaca_configured(),
        "connected": False,
        "paper": settings.alpaca_paper,
        "account_mode": "paper" if settings.alpaca_paper else "live",
        "trading_enabled": settings.trading_enabled,
        "auto_trade_enabled": is_auto_trade_enabled(),
        "fractional_trading": True,
        "min_fractional_notional": settings.min_fractional_notional,
        "account_status": None,
        "message": None,
        **auto_trade_status_extras(),
        **micro_trade_status_extras(),
    }


async def fetch_account_summary() -> dict[str, Any]:
    client = get_trading_client()
    acct = await _run_sync(client.get_account)
    equity = float(acct.equity or 0)
    last_equity = float(acct.last_equity or equity)
    day_pl = equity - last_equity
    day_pl_pct = (day_pl / last_equity * 100) if last_equity > 0 else 0.0
    return {
        "equity": equity,
        "cash": float(acct.cash or 0),
        "buying_power": float(acct.buying_power or 0),
        "portfolio_value": float(acct.portfolio_value or equity),
        "last_equity": last_equity,
        "day_pl": round(day_pl, 2),
        "day_pl_pct": round(day_pl_pct, 2),
        "status": str(acct.status.value if hasattr(acct.status, "value") else acct.status),
        "currency": acct.currency or "USD",
        "pattern_day_trader": bool(acct.pattern_day_trader),
        "trading_blocked": bool(acct.trading_blocked),
        "account_blocked": bool(acct.account_blocked),
        "account_number": getattr(acct, "account_number", None),
        "needs_paper_funding": bool(
            get_settings().alpaca_paper and equity == 0 and float(acct.cash or 0) == 0
        ),
    }


async def fetch_positions() -> list[dict[str, Any]]:
    client = get_trading_client()
    positions = await _run_sync(client.get_all_positions)
    out: list[dict[str, Any]] = []
    for p in positions:
        out.append(
            {
                "symbol": p.symbol,
                "qty": float(p.qty or 0),
                "side": str(p.side.value if hasattr(p.side, "value") else p.side),
                "avg_entry_price": float(p.avg_entry_price or 0),
                "current_price": float(p.current_price or 0),
                "market_value": float(p.market_value or 0),
                "cost_basis": float(p.cost_basis or 0),
                "unrealized_pl": float(p.unrealized_pl or 0),
                "unrealized_plpc": round(float(p.unrealized_plpc or 0) * 100, 2),
                "change_today": float(p.change_today or 0),
            }
        )
    return out


async def fetch_recent_orders(limit: int = 30) -> list[dict[str, Any]]:
    client = get_trading_client()
    req = GetOrdersRequest(status=QueryOrderStatus.ALL, limit=limit)
    orders = await _run_sync(client.get_orders, req)
    return [_order_to_dict(o) for o in orders]


async def fetch_activities(page_size: int = 50) -> list[dict[str, Any]]:
    """Account activities via Trading API REST (TradingClient has no get_account_activities)."""
    client = get_trading_client()
    cap = min(max(page_size, 1), 100)

    def _fetch_rest() -> list[dict[str, Any]]:
        try:
            raw = client.get(
                "/account/activities",
                {"page_size": cap, "direction": "desc"},
            )
            if isinstance(raw, list):
                rows = raw
            elif isinstance(raw, dict):
                rows = raw.get("activities") or raw.get("data") or []
            else:
                rows = []
            return [_activity_from_raw(a) for a in rows if isinstance(a, dict)]
        except Exception:
            return []

    activities = await _run_sync(_fetch_rest)
    if activities:
        return activities

    # Fallback: filled orders as cash-flow entries
    orders = await fetch_recent_orders(limit=cap)
    out: list[dict[str, Any]] = []
    for o in orders:
        if o.get("status") not in ("filled", "partially_filled"):
            continue
        notional = o.get("notional")
        qty = o.get("filled_qty") or o.get("qty")
        price = o.get("filled_avg_price")
        net = -notional if o.get("side", "").lower() == "buy" and notional else None
        if net is None and qty and price:
            gross = float(qty) * float(price)
            net = -gross if o.get("side", "").lower() == "buy" else gross
        out.append(
            {
                "id": o.get("id", ""),
                "activity_type": "FILL",
                "symbol": o.get("symbol"),
                "side": o.get("side"),
                "qty": qty,
                "price": price,
                "net_amount": net,
                "transaction_time": _normalize_activity_time(o.get("filled_at") or o.get("submitted_at")),
                "description": f"{o.get('side', '').upper()} {o.get('symbol')} order {o.get('status')}",
            }
        )
    return out


def _normalize_activity_time(val) -> str | None:
    if val is None:
        return None
    if isinstance(val, datetime):
        return _iso(val)
    s = str(val).strip()
    if not s:
        return None
    # Alpaca JNLC/deposit activities often return date-only strings.
    if len(s) == 10 and s[4] == "-" and s[7] == "-":
        return f"{s}T12:00:00Z"
    return s


def _activity_from_raw(a: dict[str, Any]) -> dict[str, Any]:
    return {
        "id": str(a.get("id", "")),
        "activity_type": str(a.get("activity_type", a.get("type", ""))),
        "symbol": a.get("symbol"),
        "side": a.get("side"),
        "qty": _float_or_none(a.get("qty")),
        "price": _float_or_none(a.get("price")),
        "net_amount": _float_or_none(a.get("net_amount")),
        "transaction_time": _normalize_activity_time(a.get("transaction_time") or a.get("date")),
        "description": a.get("description") or "",
    }


async def submit_notional_order(symbol: str, side: str, notional: float) -> dict[str, Any]:
    """Legacy wrapper — use fractional_trading for new code."""
    from services.fractional_trading import (
        FractionalTradingError,
        submit_fractional_buy,
        submit_fractional_sell_qty,
    )

    if side.lower() == "buy":
        return await submit_fractional_buy(symbol, notional)
    raise FractionalTradingError("SELL via notional is not supported — use qty or close_position")


async def fetch_asset(symbol: str) -> dict[str, Any]:
    from services.fractional_trading import fetch_asset_eligibility

    return (await fetch_asset_eligibility(symbol)).to_dict()


async def submit_fractional_order(
    action: str,
    symbol: str,
    *,
    notional: float | None = None,
    position_qty: float | None = None,
) -> dict[str, Any]:
    from services.fractional_trading import submit_fractional_trade

    return await submit_fractional_trade(
        action, symbol, notional=notional, position_qty=position_qty
    )


async def close_position_symbol(symbol: str) -> dict[str, Any]:
    client = get_trading_client()
    order = await _run_sync(client.close_position, symbol.upper())
    return _order_to_dict(order)


def _order_to_dict(order) -> dict[str, Any]:
    return {
        "id": str(order.id),
        "client_order_id": order.client_order_id,
        "symbol": order.symbol,
        "side": str(order.side.value if hasattr(order.side, "value") else order.side),
        "type": str(order.type.value if hasattr(order.type, "value") else order.type),
        "qty": _float_or_none(order.qty),
        "notional": _float_or_none(order.notional),
        "filled_qty": _float_or_none(order.filled_qty),
        "filled_avg_price": _float_or_none(order.filled_avg_price),
        "status": str(order.status.value if hasattr(order.status, "value") else order.status),
        "submitted_at": _iso(order.submitted_at),
        "filled_at": _iso(order.filled_at),
    }


def _float_or_none(val) -> float | None:
    if val is None:
        return None
    try:
        return float(val)
    except (TypeError, ValueError):
        return None


def _iso(val) -> str | None:
    if val is None:
        return None
    if isinstance(val, datetime):
        if val.tzinfo is None:
            val = val.replace(tzinfo=timezone.utc)
        return val.isoformat()
    return str(val)

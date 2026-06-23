"""Alpaca trading endpoints for StockPulse Trade tab."""

from __future__ import annotations

import logging

from fastapi import APIRouter, Depends, Header, HTTPException
from pydantic import BaseModel, Field
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from config import get_settings
from database import get_db
from models.db_models import TradeDecisionLog
from services.alpaca_client import is_alpaca_configured
from services.alpaca_service import (
    close_position_symbol,
    fetch_account_summary,
    fetch_activities,
    fetch_asset,
    fetch_positions,
    fetch_recent_orders,
    submit_fractional_order,
    trading_status_payload,
)
from services.fractional_trading import FractionalTradingError
from services.trading_settings import is_auto_trade_enabled, set_auto_trade_enabled

from services.trading_decision import propose_from_watchlist
from services.trading_proposal_guard import filter_new_intents

router = APIRouter(prefix="/api/trading", tags=["trading"])

logger = logging.getLogger(__name__)


class AutoTradeToggleIn(BaseModel):
    enabled: bool


class ProposeIn(BaseModel):
    symbol: str | None = None


def _require_trading_secret(x_trading_secret: str | None) -> None:
    secret = get_settings().trading_api_secret.strip()
    if not secret:
        raise HTTPException(503, "TRADING_API_SECRET not configured on server")
    if x_trading_secret != secret:
        raise HTTPException(403, "Invalid trading secret")


def _require_trading_enabled() -> None:
    if not get_settings().trading_enabled:
        raise HTTPException(503, "Trading disabled (set TRADING_ENABLED=true on server)")


async def _ensure_alpaca() -> None:
    if not is_alpaca_configured():
        raise HTTPException(
            503,
            "Alpaca not configured — add ALPACA_API_KEY and ALPACA_SECRET_KEY to server .env",
        )


@router.get("/status")
async def trading_status() -> dict:
    payload = trading_status_payload()
    if not is_alpaca_configured():
        payload["message"] = "Add Alpaca API keys to server .env (paper: ALPACA_PAPER=true)"
        return payload
    try:
        acct = await fetch_account_summary()
        payload["connected"] = True
        payload["account_status"] = acct["status"]
        payload["account_number"] = acct.get("account_number")
        payload["needs_paper_funding"] = acct.get("needs_paper_funding", False)
        if acct.get("needs_paper_funding"):
            payload["message"] = (
                "Connected to Alpaca Paper — account has $0. "
                "Open a new paper account at alpaca.markets with $100k, then update API keys on the server."
            )
        else:
            payload["message"] = (
                "Connected to Alpaca Live"
                if not get_settings().alpaca_paper
                else "Connected to Alpaca Paper (simulated)"
            )
    except Exception as exc:
        payload["message"] = f"Alpaca connection failed: {exc}"
    return payload


@router.get("/account")
async def trading_account() -> dict:
    await _ensure_alpaca()
    return await fetch_account_summary()


@router.get("/positions")
async def trading_positions(db: AsyncSession = Depends(get_db)) -> dict:
    await _ensure_alpaca()
    positions = await fetch_positions()
    auto_symbols = await _auto_traded_symbols(db)
    for p in positions:
        p["is_auto"] = p["symbol"] in auto_symbols
    return {"positions": positions}


@router.get("/activities")
async def trading_activities(page_size: int = 50) -> dict:
    await _ensure_alpaca()
    cap = min(max(page_size, 1), 100)
    activities = await fetch_activities(page_size=cap)
    return {"activities": activities}


@router.get("/orders")
async def trading_orders(limit: int = 30) -> dict:
    await _ensure_alpaca()
    cap = min(max(limit, 1), 100)
    orders = await fetch_recent_orders(limit=cap)
    return {"orders": orders}


@router.get("/assets/{symbol}")
async def trading_asset(symbol: str) -> dict:
    """Fractional eligibility — fractionable + tradable per Alpaca."""
    await _ensure_alpaca()
    try:
        return await fetch_asset(symbol)
    except FractionalTradingError as exc:
        raise HTTPException(404, str(exc)) from exc


@router.get("/decisions")
async def trading_decisions(limit: int = 50, db: AsyncSession = Depends(get_db)) -> dict:
    cap = min(max(limit, 1), 100)
    result = await db.execute(
        select(TradeDecisionLog).order_by(TradeDecisionLog.created_at.desc()).limit(cap)
    )
    rows = result.scalars().all()
    return {"decisions": [_decision_out(r) for r in rows]}


@router.post("/propose")
async def propose_trades(
    body: ProposeIn | None = None,
    db: AsyncSession = Depends(get_db),
    x_trading_secret: str | None = Header(None, alias="X-Trading-Secret"),
) -> dict:
    _require_trading_secret(x_trading_secret)
    await _ensure_alpaca()

    acct = await fetch_account_summary()
    positions = await fetch_positions()
    open_syms = {p["symbol"] for p in positions}

    intents = await propose_from_watchlist(
        db,
        equity=acct["equity"],
        buying_power=acct["buying_power"],
        open_position_symbols=open_syms,
        position_count=len(positions),
        day_pl_pct=acct["day_pl_pct"],
        symbol=body.symbol if body else None,
    )

    intents, skipped = await filter_new_intents(db, intents)

    created: list[dict] = []
    for intent in intents:
        row = TradeDecisionLog(
            symbol=intent.symbol,
            action=intent.action,
            confidence=intent.confidence,
            notional_usd=intent.notional_usd,
            rationale=intent.rationale,
            signal_source=intent.signal_source,
            buying_signal_score=intent.buying_signal_score,
            status="proposed",
        )
        db.add(row)
        await db.flush()
        created.append(_decision_out(row))

    await db.commit()
    return {"proposals": created, "skipped_symbols": skipped}


@router.post("/execute/{decision_id}")
async def execute_decision(
    decision_id: int,
    db: AsyncSession = Depends(get_db),
    x_trading_secret: str | None = Header(None, alias="X-Trading-Secret"),
) -> dict:
    _require_trading_secret(x_trading_secret)
    _require_trading_enabled()
    await _ensure_alpaca()

    row = await db.get(TradeDecisionLog, decision_id)
    if row is None:
        raise HTTPException(404, "Decision not found")
    if row.status not in ("proposed", "approved"):
        raise HTTPException(400, f"Decision status is {row.status}, not executable")

    acct = await fetch_account_summary()
    positions = await fetch_positions()
    open_syms = {p["symbol"] for p in positions}

    from services.risk_engine import TradeIntent, validate_trade_intent

    intent = TradeIntent(
        action=row.action,
        symbol=row.symbol,
        confidence=row.confidence,
        notional_usd=row.notional_usd,
        rationale=row.rationale,
        signal_source=row.signal_source,
        buying_signal_score=row.buying_signal_score,
    )
    approved, reason = validate_trade_intent(
        intent,
        equity=acct["equity"],
        buying_power=acct["buying_power"],
        open_position_symbols=open_syms,
        position_count=len(positions),
        day_pl_pct=acct["day_pl_pct"],
    )
    if not approved:
        row.status = "rejected"
        await db.commit()
        raise HTTPException(400, reason or "Risk check failed")

    pos_by_symbol = {p["symbol"]: p for p in positions}
    try:
        if row.action.upper() == "BUY":
            order = await submit_fractional_order(
                "BUY",
                row.symbol,
                notional=approved.notional_usd,
            )
        else:
            pos = pos_by_symbol.get(row.symbol.upper())
            if pos is None:
                raise FractionalTradingError(f"No open position for {row.symbol}")
            order = await submit_fractional_order(
                "SELL",
                row.symbol,
                position_qty=float(pos["qty"]),
            )
    except FractionalTradingError as exc:
        row.status = "rejected"
        await db.commit()
        raise HTTPException(400, str(exc)) from exc
    except Exception as exc:
        row.status = "failed"
        await db.commit()
        raise HTTPException(502, f"Alpaca order failed: {exc}") from exc

    row.alpaca_order_id = order["id"]
    row.status = "submitted"
    await db.commit()
    return {"decision": _decision_out(row), "order": order}


@router.post("/auto")
async def toggle_auto_trade(
    body: AutoTradeToggleIn,
    x_trading_secret: str | None = Header(None, alias="X-Trading-Secret"),
) -> dict:
    """Enable/disable auto-trade until server restart (env default on boot)."""
    _require_trading_secret(x_trading_secret)
    if body.enabled and not get_settings().alpaca_paper:
        raise HTTPException(400, "Auto-trade is paper-only (set ALPACA_PAPER=true)")
    set_auto_trade_enabled(body.enabled)
    return {
        "auto_trade_enabled": is_auto_trade_enabled(),
        "message": "Auto-trade enabled" if body.enabled else "Auto-trade disabled",
    }


@router.post("/close/{symbol}")
async def close_position(
    symbol: str,
    db: AsyncSession = Depends(get_db),
    x_trading_secret: str | None = Header(None, alias="X-Trading-Secret"),
) -> dict:
    _require_trading_secret(x_trading_secret)
    _require_trading_enabled()
    await _ensure_alpaca()

    sym = symbol.upper()
    try:
        order = await close_position_symbol(sym)
    except Exception as exc:
        raise HTTPException(502, f"Close position failed: {exc}") from exc

    row = TradeDecisionLog(
        symbol=sym,
        action="SELL",
        confidence=1.0,
        notional_usd=0,
        rationale="Manual close from Trade tab",
        signal_source="manual_close",
        alpaca_order_id=order["id"],
        status="submitted",
    )
    db.add(row)
    await db.commit()
    return {"order": order}


@router.get("/dashboard")
async def trading_dashboard(db: AsyncSession = Depends(get_db)) -> dict:
    """Single payload for iOS Trade tab."""
    status = await trading_status()
    out: dict = {"status": status, "account": None, "positions": [], "activities": [], "decisions": []}

    if not is_alpaca_configured() or not status.get("connected"):
        return out

    try:
        out["account"] = await fetch_account_summary()
    except Exception as exc:
        logger.warning("Dashboard account fetch failed: %s", exc)

    try:
        positions = await fetch_positions()
        auto_symbols = await _auto_traded_symbols(db)
        for p in positions:
            p["is_auto"] = p["symbol"] in auto_symbols
        out["positions"] = positions
    except Exception as exc:
        logger.warning("Dashboard positions fetch failed: %s", exc)

    try:
        out["activities"] = await fetch_activities(page_size=30)
    except Exception as exc:
        logger.warning("Dashboard activities fetch failed: %s", exc)

    try:
        result = await db.execute(
            select(TradeDecisionLog).order_by(TradeDecisionLog.created_at.desc()).limit(20)
        )
        out["decisions"] = [_decision_out(r) for r in result.scalars().all()]
    except Exception as exc:
        logger.warning("Dashboard decisions fetch failed: %s", exc)

    return out


async def _auto_traded_symbols(db: AsyncSession) -> set[str]:
    result = await db.execute(
        select(TradeDecisionLog.symbol).where(
            TradeDecisionLog.status.in_(("submitted", "filled")),
            TradeDecisionLog.action == "BUY",
            TradeDecisionLog.signal_source.in_(("auto_watch", "micro_momentum")),
        )
    )
    return {r.upper() for (r,) in result.all() if r}


def _decision_out(row: TradeDecisionLog) -> dict:
    return {
        "id": row.id,
        "symbol": row.symbol,
        "action": row.action,
        "confidence": row.confidence,
        "notional_usd": row.notional_usd,
        "rationale": row.rationale,
        "signal_source": row.signal_source,
        "buying_signal_score": row.buying_signal_score,
        "alpaca_order_id": row.alpaca_order_id,
        "status": row.status,
        "created_at": row.created_at.isoformat() if row.created_at else None,
        "order_style": "fractional_notional" if row.action.upper() == "BUY" else "fractional_qty",
    }

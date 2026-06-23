"""Scheduled auto-trade from WATCH research signals (paper only)."""

from __future__ import annotations

import logging
from datetime import datetime
from zoneinfo import ZoneInfo

from config import get_settings
from database import SessionLocal
from models.db_models import TradeDecisionLog
from services.alpaca_client import is_alpaca_configured
from services.alpaca_service import (
    fetch_account_summary,
    fetch_positions,
    submit_fractional_order,
)
from services.fractional_trading import FractionalTradingError
from services.risk_engine import validate_trade_intent
from services.trading_decision import propose_from_watchlist
from services.trading_proposal_guard import filter_new_intents
from services.auto_trade_state import record_auto_trade_run
from services.trading_settings import is_auto_trade_enabled
from services.trade_execution import append_failure_reason, append_rejection_reason

logger = logging.getLogger(__name__)

ET = ZoneInfo("America/New_York")


def _is_trading_day() -> bool:
    return datetime.now(ET).weekday() < 5


def _is_market_hours() -> bool:
    now = datetime.now(ET)
    if now.weekday() >= 5:
        return False
    minutes = now.hour * 60 + now.minute
    return (9 * 60 + 30) <= minutes < (16 * 60 + 5)


async def run_auto_trade_cycle() -> dict[str, str | int | list[str]]:
    result = await _run_auto_trade_cycle()
    record_auto_trade_run(result)
    return result


async def _run_auto_trade_cycle() -> dict[str, str | int | list[str]]:
    settings = get_settings()
    if not is_auto_trade_enabled():
        return {"status": "skipped", "reason": "auto_trade_disabled"}
    if not settings.trading_enabled:
        return {"status": "skipped", "reason": "trading_disabled"}
    if not settings.alpaca_paper:
        return {"status": "skipped", "reason": "paper_only"}
    if not is_alpaca_configured():
        return {"status": "skipped", "reason": "alpaca_not_configured"}
    if not _is_trading_day():
        return {"status": "skipped", "reason": "not_trading_day"}
    if not _is_market_hours():
        return {"status": "skipped", "reason": "market_closed"}

    async with SessionLocal() as session:
        try:
            acct = await fetch_account_summary()
            positions = await fetch_positions()
            open_syms = {p["symbol"] for p in positions}

            if acct["buying_power"] < settings.min_fractional_notional:
                return {
                    "status": "skipped",
                    "reason": f"insufficient_buying_power_{acct['buying_power']:.2f}",
                }

            intents = await propose_from_watchlist(
                session,
                equity=acct["equity"],
                buying_power=acct["buying_power"],
                open_position_symbols=open_syms,
                position_count=len(positions),
                day_pl_pct=acct["day_pl_pct"],
            )
            intents, skipped_syms = await filter_new_intents(session, intents)
            if skipped_syms:
                logger.info("Auto-trade skipped recent symbols: %s", ", ".join(skipped_syms))
            if not intents:
                return {
                    "status": "skipped",
                    "reason": "no_approved_proposals",
                    "skipped_symbols": skipped_syms,
                }

            executed = 0
            slots = max(0, settings.max_positions - len(positions))
            for intent in intents[:slots]:
                row = TradeDecisionLog(
                    symbol=intent.symbol,
                    action=intent.action,
                    confidence=intent.confidence,
                    notional_usd=intent.notional_usd,
                    rationale=intent.rationale,
                    signal_source="auto_watch",
                    buying_signal_score=intent.buying_signal_score,
                    status="proposed",
                )
                session.add(row)
                await session.flush()

                approved, reason = validate_trade_intent(
                    intent,
                    equity=acct["equity"],
                    buying_power=acct["buying_power"],
                    open_position_symbols=open_syms,
                    position_count=len(positions) + executed,
                    day_pl_pct=acct["day_pl_pct"],
                )
                if not approved:
                    append_rejection_reason(row, reason or "Risk check failed")
                    logger.info("Auto-trade rejected %s: %s", intent.symbol, reason)
                    continue

                try:
                    order = await submit_fractional_order(
                        "BUY",
                        row.symbol,
                        notional=approved.notional_usd,
                    )
                    row.alpaca_order_id = order["id"]
                    row.status = "submitted"
                    open_syms.add(row.symbol.upper())
                    executed += 1
                    logger.info(
                        "Auto-trade submitted %s $%.2f order=%s",
                        row.symbol,
                        approved.notional_usd,
                        order["id"],
                    )
                except FractionalTradingError as exc:
                    append_rejection_reason(row, str(exc))
                    logger.warning("Auto-trade fractional error %s: %s", row.symbol, exc)
                except Exception as exc:
                    append_failure_reason(row, str(exc))
                    logger.exception("Auto-trade order failed for %s", row.symbol)

            await session.commit()
            if executed:
                return {
                    "status": "ok",
                    "executed": executed,
                    "skipped_symbols": skipped_syms,
                }
            return {
                "status": "skipped",
                "reason": "no_orders_submitted",
                "skipped_symbols": skipped_syms,
            }
        except Exception as exc:
            logger.exception("Auto-trade cycle failed")
            return {"status": "failed", "reason": str(exc)}

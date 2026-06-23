"""Scheduled micro day-trading: intraday entries + take-profit / stop-loss / EOD flat."""

from __future__ import annotations

import logging
from datetime import datetime
from zoneinfo import ZoneInfo

from config import get_settings
from database import SessionLocal
from models.db_models import TradeDecisionLog
from services.alpaca_client import is_alpaca_configured
from services.alpaca_service import fetch_account_summary, fetch_positions, submit_fractional_order
from services.fractional_trading import FractionalTradingError
from services.micro_trade_state import record_micro_trade_run
from services.micro_trading import (
    _latest_snapshots,
    build_micro_entry_intents,
    evaluate_all_micro_exits,
    evaluate_eod_flat_exits,
    is_daily_profit_cap_hit,
)
from services.trade_execution import append_failure_reason, append_rejection_reason
from services.trading_proposal_guard import filter_new_intents
from services.trading_settings import is_auto_trade_enabled

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


def _micro_enabled() -> bool:
    settings = get_settings()
    return settings.micro_trade_enabled and is_auto_trade_enabled()


async def run_micro_trade_cycle() -> dict:
    result = await _run_micro_trade_cycle()
    record_micro_trade_run(result)
    return result


async def _run_micro_trade_cycle() -> dict:
    settings = get_settings()
    if not _micro_enabled():
        return {"status": "skipped", "reason": "micro_or_auto_disabled"}
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

    entries = 0
    exits = 0
    skipped_syms: list[str] = []

    async with SessionLocal() as session:
        try:
            acct = await fetch_account_summary()
            positions = await fetch_positions()
            pos_by_symbol = {p["symbol"].upper(): p for p in positions}
            snapshots = await _latest_snapshots(session)

            # --- Exits first (TP / SL / momentum flip / EOD flat) ---
            exit_signals = evaluate_all_micro_exits(positions, snapshots)
            eod_signals = evaluate_eod_flat_exits(positions)
            # EOD flat overrides individual TP/SL when in flat window
            if eod_signals:
                exit_signals = eod_signals

            for sig in exit_signals:
                pos = pos_by_symbol.get(sig.symbol)
                if pos is None:
                    continue
                row = TradeDecisionLog(
                    symbol=sig.symbol,
                    action="SELL",
                    confidence=1.0,
                    notional_usd=0,
                    rationale=sig.reason,
                    signal_source=sig.signal_source,
                    status="proposed",
                )
                session.add(row)
                await session.flush()
                try:
                    order = await submit_fractional_order(
                        "SELL",
                        sig.symbol,
                        position_qty=float(pos["qty"]),
                    )
                    row.alpaca_order_id = order["id"]
                    row.status = "submitted"
                    exits += 1
                    logger.info(
                        "Micro exit %s %s order=%s",
                        sig.symbol,
                        sig.signal_source,
                        order["id"],
                    )
                except FractionalTradingError as exc:
                    append_rejection_reason(row, str(exc))
                    logger.warning("Micro exit rejected %s: %s", sig.symbol, exc)
                except Exception as exc:
                    append_failure_reason(row, str(exc))
                    logger.exception("Micro exit failed for %s", sig.symbol)

            if exits:
                await session.commit()
                positions = await fetch_positions()
                pos_by_symbol = {p["symbol"].upper(): p for p in positions}
                open_syms = set(pos_by_symbol.keys())
                acct = await fetch_account_summary()
            else:
                open_syms = set(pos_by_symbol.keys())

            # --- Entries (skip if daily profit cap hit) ---
            if is_daily_profit_cap_hit(acct["day_pl"]):
                await session.commit()
                return {
                    "status": "ok" if exits else "skipped",
                    "reason": "daily_profit_cap_hit" if not exits else None,
                    "entries": entries,
                    "exits": exits,
                    "skipped_symbols": skipped_syms,
                }

            if acct["buying_power"] < settings.min_fractional_notional:
                await session.commit()
                return {
                    "status": "ok" if exits else "skipped",
                    "reason": f"insufficient_buying_power_{acct['buying_power']:.2f}",
                    "entries": entries,
                    "exits": exits,
                    "skipped_symbols": skipped_syms,
                }

            intents = await build_micro_entry_intents(
                session,
                equity=acct["equity"],
                buying_power=acct["buying_power"],
                open_position_symbols=open_syms,
                position_count=len(positions),
                day_pl_pct=acct["day_pl_pct"],
            )
            cooldown_h = settings.micro_propose_cooldown_minutes / 60.0
            intents, skipped_syms = await filter_new_intents(
                session, intents, cooldown_hours=cooldown_h
            )

            slots = max(0, settings.max_positions - len(positions))
            for intent in intents[:slots]:
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
                session.add(row)
                await session.flush()
                try:
                    order = await submit_fractional_order(
                        "BUY",
                        intent.symbol,
                        notional=intent.notional_usd,
                    )
                    row.alpaca_order_id = order["id"]
                    row.status = "submitted"
                    open_syms.add(intent.symbol.upper())
                    entries += 1
                    logger.info(
                        "Micro entry %s $%.2f order=%s",
                        intent.symbol,
                        intent.notional_usd,
                        order["id"],
                    )
                except FractionalTradingError as exc:
                    append_rejection_reason(row, str(exc))
                    logger.warning("Micro entry rejected %s: %s", intent.symbol, exc)
                except Exception as exc:
                    append_failure_reason(row, str(exc))
                    logger.exception("Micro entry failed for %s", intent.symbol)

            await session.commit()

            if entries or exits:
                return {
                    "status": "ok",
                    "entries": entries,
                    "exits": exits,
                    "skipped_symbols": skipped_syms,
                }
            return {
                "status": "skipped",
                "reason": "no_micro_signals",
                "entries": 0,
                "exits": 0,
                "skipped_symbols": skipped_syms,
            }
        except Exception as exc:
            logger.exception("Micro-trade cycle failed")
            return {"status": "failed", "reason": str(exc), "entries": entries, "exits": exits}

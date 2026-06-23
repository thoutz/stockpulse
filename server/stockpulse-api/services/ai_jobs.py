from __future__ import annotations

import asyncio
import logging
from datetime import datetime, timedelta, timezone
from zoneinfo import ZoneInfo

from sqlalchemy import delete, select
from sqlalchemy.ext.asyncio import AsyncSession

from config import get_settings
from services.monitor_tiers import MonitorTier, build_tier_map
from database import SessionLocal
from models.db_models import AIAlert, AIReport, AISuggestion, MarketObservation, Snapshot
from services.analysis_packet import build_pulse_analysis_packet
from services.groq_budget import can_spend_tokens
from services.groq_client import chat_completion
from services.pulse_report import PULSE_USER_PROMPT, SESSION_PROMPTS, parse_pulse_response

logger = logging.getLogger(__name__)

ET = ZoneInfo("America/New_York")
VALID_PULSE_SLOTS = frozenset({"open", "midday", "close"})


def _is_trading_day() -> bool:
    return datetime.now(ET).weekday() < 5


def _is_market_hours() -> bool:
    now = datetime.now(ET)
    if now.weekday() >= 5:
        return False
    minutes = now.hour * 60 + now.minute
    return (9 * 60 + 30) <= minutes < (16 * 60)


async def run_pulse_report(session_slot: str = "open") -> None:
    if session_slot not in VALID_PULSE_SLOTS:
        logger.warning("Unknown pulse slot %s", session_slot)
        return
    if not _is_trading_day():
        logger.info("Skipping pulse_%s — not a trading day", session_slot)
        return
    if not can_spend_tokens(4500):
        logger.warning("Groq token budget too low — skipping pulse_%s", session_slot)
        return

    report_type = f"pulse_{session_slot}"
    async with SessionLocal() as session:
        last = (
            await session.execute(
                select(AIReport)
                .where(AIReport.report_type.like("pulse%"))
                .order_by(AIReport.created_at.desc())
                .limit(1)
            )
        ).scalar_one_or_none()

        since = last.created_at if last else None

        from services.session_intelligence import build_session_intelligence, fetch_intelligence_rows

        session_date = datetime.now(ET).strftime("%Y-%m-%d")
        existing = await fetch_intelligence_rows(session, session_date, slot=session_slot)
        if not existing:
            await build_session_intelligence(session, session_slot)
            await session.flush()

        context = await build_pulse_analysis_packet(session, session_slot=session_slot, since=since)

        session_note = SESSION_PROMPTS.get(session_slot, SESSION_PROMPTS["open"])
        user_parts = [PULSE_USER_PROMPT, f"\n{session_note}"]
        if last:
            user_parts.append(
                "\n=== PREVIOUS PULSE REPORT (dedupe only) ===\n"
                f"Title: {last.title}\n{last.body[:1200]}"
            )

        body = await chat_completion(context, "\n".join(user_parts), max_tokens=950)
        title, content = parse_pulse_response(body)
        session.add(
            AIReport(report_type=report_type, title=title, body=content.strip())
        )
        await session.commit()
        logger.info("Pulse report created (%s): %s", report_type, title)

    await _maybe_run_auto_trade_after_pulse(session_slot)


async def _maybe_run_auto_trade_after_pulse(session_slot: str) -> None:
    """Run paper auto-trade once fresh pulse + watchlist data is committed."""
    try:
        from services.trading_jobs import run_auto_trade_cycle

        result = await run_auto_trade_cycle()
        logger.info("Auto-trade after pulse_%s: %s", session_slot, result)
    except Exception:
        logger.exception("Auto-trade after pulse_%s failed", session_slot)


async def run_pulse_open() -> None:
    await run_pulse_report("open")


async def run_pulse_midday() -> None:
    await run_pulse_report("midday")


async def run_pulse_close() -> None:
    async with SessionLocal() as session:
        try:
            from services.daily_av_ingest import ingest_daily_av_bundle

            await ingest_daily_av_bundle(session)
            await session.commit()
        except Exception:
            logger.exception("Pre-close AV bundle ingest failed")
    await run_pulse_report("close")


PULSE_SLOT_SCHEDULE: list[tuple[str, int, int]] = [
    ("open", 10, 0),
    ("midday", 13, 0),
    ("close", 16, 0),
]


async def run_missed_pulse_slots_today() -> dict[str, str]:
    results: dict[str, str] = {}
    if not _is_trading_day():
        return {"status": "skipped", "reason": "not a trading day"}

    now = datetime.now(ET)
    today_start = now.replace(hour=0, minute=0, second=0, microsecond=0)

    async with SessionLocal() as session:
        pending: list[str] = []
        for slot_name, hour, minute in PULSE_SLOT_SCHEDULE:
            slot_time = now.replace(hour=hour, minute=minute, second=0, microsecond=0)
            if now < slot_time:
                results[slot_name] = "not_due"
                continue
            report_type = f"pulse_{slot_name}"
            existing = (
                await session.execute(
                    select(AIReport.id)
                    .where(
                        AIReport.report_type == report_type,
                        AIReport.created_at >= today_start,
                    )
                    .limit(1)
                )
            ).scalar_one_or_none()
            if existing is not None:
                results[slot_name] = "already_exists"
            else:
                pending.append(slot_name)

    for i, slot_name in enumerate(pending):
        if not can_spend_tokens(4500):
            results[slot_name] = "skipped: token budget"
            continue
        if i > 0:
            await asyncio.sleep(90)
        logger.info("Catch-up: generating missed pulse_%s for today", slot_name)
        try:
            await run_pulse_report(slot_name)
            results[slot_name] = "created"
        except Exception as exc:
            logger.exception("Catch-up failed for pulse_%s", slot_name)
            results[slot_name] = f"failed: {exc}"

    results["status"] = "ok"
    return results


async def _recent_alert_exists(
    session: AsyncSession, symbol: str, alert_type: str, hours: float
) -> bool:
    cutoff = datetime.now(timezone.utc) - timedelta(hours=hours)
    result = await session.execute(
        select(AIAlert.id)
        .where(
            AIAlert.symbol == symbol,
            AIAlert.alert_type == alert_type,
            AIAlert.created_at >= cutoff,
        )
        .limit(1)
    )
    return result.scalar_one_or_none() is not None


async def _snapshot_at(
    session: AsyncSession, symbol: str, minutes_ago: int
) -> Snapshot | None:
    cutoff = datetime.now(timezone.utc) - timedelta(minutes=minutes_ago)
    result = await session.execute(
        select(Snapshot)
        .where(Snapshot.symbol == symbol, Snapshot.captured_at <= cutoff)
        .order_by(Snapshot.captured_at.desc())
        .limit(1)
    )
    return result.scalar_one_or_none()


async def _record_observation(
    session: AsyncSession,
    symbol: str,
    observation_type: str,
    change_pct: float,
    window_minutes: int,
    message: str,
) -> None:
    session.add(
        MarketObservation(
            symbol=symbol,
            observation_type=observation_type,
            change_pct=change_pct,
            window_minutes=window_minutes,
            message=message,
            session_date=datetime.now(ET).strftime("%Y-%m-%d"),
        )
    )


async def prune_old_alerts(session: AsyncSession) -> int:
    """Keep only the newest N alerts in the database (sliding window for the UI)."""
    settings = get_settings()
    keep = settings.alerts_retain_count
    keep_result = await session.execute(
        select(AIAlert.id).order_by(AIAlert.created_at.desc()).limit(keep)
    )
    keep_ids = list(keep_result.scalars().all())
    if not keep_ids:
        return 0
    result = await session.execute(delete(AIAlert).where(AIAlert.id.notin_(keep_ids)))
    return result.rowcount or 0


async def run_movement_alerts(session: AsyncSession | None = None) -> None:
    settings = get_settings()
    own_session = session is None
    if own_session:
        session = SessionLocal()
    assert session is not None
    try:
        tier_map = await build_tier_map(session)
        snap_result = await session.execute(
            select(Snapshot).order_by(Snapshot.captured_at.desc()).limit(100)
        )
        seen: set[str] = set()
        for snap in snap_result.scalars().all():
            if snap.symbol in seen:
                continue
            seen.add(snap.symbol)
            tier = tier_map.get(snap.symbol, MonitorTier.COLD)

            triggers: list[tuple[str, str, float]] = []

            if tier == MonitorTier.HOT and snap.change_5m_pct is not None:
                if abs(snap.change_5m_pct) >= settings.alert_velocity_pct:
                    direction = "up" if snap.change_5m_pct > 0 else "down"
                    triggers.append(
                        (
                            f"velocity_{direction}",
                            f"{snap.symbol} moved {snap.change_5m_pct:+.1f}% in ~5 min (now ${snap.price:.2f})",
                            snap.change_5m_pct,
                        )
                    )

            if abs(snap.change_1d_pct) >= settings.alert_threshold_pct:
                direction = "up" if snap.change_1d_pct > 0 else "down"
                triggers.append(
                    (
                        f"movement_{direction}",
                        f"{snap.symbol} big daily move {snap.change_1d_pct:+.1f}% at ${snap.price:.2f}",
                        snap.change_1d_pct,
                    )
                )

            if tier != MonitorTier.HOT:
                prior = await _snapshot_at(session, snap.symbol, 20)
                if prior and prior.price > 0:
                    velocity = (snap.price - prior.price) / prior.price * 100
                    if abs(velocity) >= settings.alert_velocity_pct:
                        direction = "up" if velocity > 0 else "down"
                        triggers.append(
                            (
                                f"velocity_{direction}",
                                f"{snap.symbol} fast move {velocity:+.1f}% in ~20 min (now ${snap.price:.2f})",
                                velocity,
                            )
                        )

            for alert_type, msg, pct in triggers:
                if await _recent_alert_exists(
                    session, snap.symbol, alert_type, settings.alert_cooldown_hours
                ):
                    continue
                session.add(
                    AIAlert(
                        symbol=snap.symbol,
                        alert_type=alert_type,
                        message=msg,
                        change_pct=pct,
                        delivered_push=False,
                    )
                )
                await _record_observation(
                    session,
                    snap.symbol,
                    alert_type.replace("movement_", "daily_swing_").replace("velocity_", "velocity_spike_"),
                    pct,
                    20 if "velocity" in alert_type else 390,
                    msg,
                )

        if own_session:
            await prune_old_alerts(session)
            await session.commit()
    finally:
        if own_session:
            await session.close()


async def run_snapshot_suggestions() -> None:
    """Rule-based suggestions from snapshots — no Groq."""
    if not _is_market_hours():
        return

    async with SessionLocal() as session:
        snap_result = await session.execute(
            select(Snapshot).order_by(Snapshot.captured_at.desc()).limit(50)
        )
        seen: set[str] = set()
        for snap in snap_result.scalars().all():
            if snap.symbol in seen:
                continue
            seen.add(snap.symbol)

            bias = "neutral"
            parts: list[str] = []
            if snap.change_1d_pct >= 3:
                parts.append(f"strong +{snap.change_1d_pct:.1f}% day")
                bias = "bullish"
            elif snap.change_1d_pct <= -3:
                parts.append(f"weak {snap.change_1d_pct:.1f}% day")
                bias = "bearish"
            if snap.rsi is not None:
                if snap.rsi >= 70:
                    parts.append(f"RSI {snap.rsi:.0f} overbought")
                    if bias == "bullish":
                        bias = "neutral"
                elif snap.rsi <= 30:
                    parts.append(f"RSI {snap.rsi:.0f} oversold")
                    if bias == "bearish":
                        bias = "neutral"
            if not parts:
                continue

            summary = f"{snap.symbol} at ${snap.price:.2f}: " + ", ".join(parts) + "."
            session.add(
                AISuggestion(symbol=snap.symbol, bias=bias, summary=summary[:2000])
            )
        await session.commit()


async def run_ai_insight_alert() -> None:
    """Deprecated — Groq digest removed to save token budget."""
    return

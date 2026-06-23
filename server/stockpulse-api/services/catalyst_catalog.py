"""DB-backed catalyst catalog with fallback to built-in definitions."""

from __future__ import annotations

import logging
from typing import Any

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from models.db_models import CatalystEvent, CatalystRipple
from services.ripple_engine import CATALYSTS as BUILTIN_CATALYSTS

logger = logging.getLogger(__name__)


def builtin_catalyst_dicts() -> list[dict[str, Any]]:
    return [
        {
            "ticker": c["ticker"],
            "name": c["name"],
            "event_name": c["event_name"],
            "event_date": c["event_date"],
            "ripples": list(c["ripples"]),
            "confidence_score": None,
            "source": "builtin",
        }
        for c in BUILTIN_CATALYSTS
    ]


async def seed_builtin_catalysts(session: AsyncSession) -> int:
    count_result = await session.execute(select(func.count()).select_from(CatalystEvent))
    if (count_result.scalar() or 0) > 0:
        return 0

    created = 0
    for cat in BUILTIN_CATALYSTS:
        event = CatalystEvent(
            ticker=cat["ticker"],
            name=cat["name"],
            event_name=cat["event_name"],
            event_date=cat["event_date"],
            active=True,
            source="builtin",
        )
        session.add(event)
        await session.flush()
        for ripple_ticker, description in cat["ripples"]:
            session.add(
                CatalystRipple(
                    catalyst_event_id=event.id,
                    ripple_ticker=ripple_ticker,
                    description=description,
                )
            )
        created += 1
    logger.info("Seeded %d builtin catalyst events", created)
    return created


async def ensure_catalysts_seeded(session: AsyncSession) -> None:
    await seed_builtin_catalysts(session)


async def load_catalysts(session: AsyncSession, *, active_only: bool = True) -> list[dict[str, Any]]:
    await ensure_catalysts_seeded(session)
    stmt = select(CatalystEvent).order_by(CatalystEvent.event_date.desc(), CatalystEvent.ticker)
    if active_only:
        stmt = stmt.where(CatalystEvent.active.is_(True))
    events = (await session.execute(stmt)).scalars().all()
    if not events:
        return builtin_catalyst_dicts()

    out: list[dict[str, Any]] = []
    for event in events:
        ripples_result = await session.execute(
            select(CatalystRipple)
            .where(CatalystRipple.catalyst_event_id == event.id)
            .order_by(CatalystRipple.ripple_ticker)
        )
        ripples = ripples_result.scalars().all()
        out.append(
            {
                "id": event.id,
                "ticker": event.ticker,
                "name": event.name,
                "event_name": event.event_name,
                "event_date": event.event_date,
                "ripples": [(r.ripple_ticker, r.description) for r in ripples],
                "confidence_score": event.confidence_score,
                "source": event.source,
                "active": event.active,
            }
        )
    return out


def sectors_payload() -> list[dict[str, Any]]:
    from services.sector_catalog import SECTORS

    return [
        {
            "id": s.id,
            "name": s.name,
            "description": s.description,
            "tickers": list(s.tickers),
            "accent_hex": s.accent_hex,
        }
        for s in SECTORS
    ]


async def catalysts_api_payload(session: AsyncSession) -> dict[str, Any]:
    catalysts = await load_catalysts(session, active_only=False)
    return {
        "count": len(catalysts),
        "catalysts": [
            {
                "id": c.get("id"),
                "ticker": c["ticker"],
                "name": c["name"],
                "event_name": c["event_name"],
                "event_date": c["event_date"],
                "active": c.get("active", True),
                "confidence_score": c.get("confidence_score"),
                "source": c.get("source", "manual"),
                "ripples": [
                    {"ticker": t, "description": d} for t, d in c["ripples"]
                ],
            }
            for c in catalysts
        ],
    }

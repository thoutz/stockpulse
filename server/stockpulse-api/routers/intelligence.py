from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession

from database import get_db
from services.session_intelligence import VALID_SLOTS, fetch_intelligence_rows

router = APIRouter(prefix="/api/intelligence", tags=["intelligence"])


def _row_out(row) -> dict:
    return {
        "id": row.id,
        "session_date": row.session_date,
        "slot": row.slot,
        "category": row.category,
        "symbol": row.symbol,
        "tier": row.tier,
        "metric_key": row.metric_key,
        "metric_value": row.metric_value,
        "summary_text": row.summary_text,
        "created_at": row.created_at.isoformat() if row.created_at else None,
    }


@router.get("/session/{session_date}")
async def get_session_intelligence(
    session_date: str,
    db: AsyncSession = Depends(get_db),
) -> dict:
    if len(session_date) != 10 or session_date[4] != "-":
        raise HTTPException(400, "session_date must be YYYY-MM-DD")
    rows = await fetch_intelligence_rows(db, session_date)
    return {
        "session_date": session_date,
        "count": len(rows),
        "rows": [_row_out(r) for r in rows],
    }


@router.get("/session/{session_date}/{slot}")
async def get_session_intelligence_slot(
    session_date: str,
    slot: str,
    db: AsyncSession = Depends(get_db),
) -> dict:
    if slot not in VALID_SLOTS:
        raise HTTPException(400, f"slot must be one of: {', '.join(sorted(VALID_SLOTS))}")
    if len(session_date) != 10 or session_date[4] != "-":
        raise HTTPException(400, "session_date must be YYYY-MM-DD")
    rows = await fetch_intelligence_rows(db, session_date, slot=slot)
    return {
        "session_date": session_date,
        "slot": slot,
        "count": len(rows),
        "rows": [_row_out(r) for r in rows],
    }

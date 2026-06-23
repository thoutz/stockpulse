from __future__ import annotations

from pydantic import BaseModel, Field

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession

from database import get_db
from services.monitor_service import build_monitor_payload
from services.monitor_tiers import set_focus_sector
from services.sector_catalog import SECTOR_BY_ID

router = APIRouter(prefix="/api/monitor", tags=["monitor"])


class FocusIn(BaseModel):
    focus_sector_id: str | None = Field(
        None, description="semiconductors | space | ev, or null to clear focus"
    )


@router.get("")
async def get_monitor(db: AsyncSession = Depends(get_db)) -> dict:
    return await build_monitor_payload(db)


@router.put("/focus")
async def update_focus(body: FocusIn, db: AsyncSession = Depends(get_db)) -> dict:
    if body.focus_sector_id is not None and body.focus_sector_id not in SECTOR_BY_ID:
        raise HTTPException(400, f"Unknown sector: {body.focus_sector_id}")
    try:
        await set_focus_sector(db, body.focus_sector_id)
        await db.commit()
    except ValueError as exc:
        raise HTTPException(400, str(exc)) from exc
    return await build_monitor_payload(db)

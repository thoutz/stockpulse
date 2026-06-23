from __future__ import annotations

from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from database import get_db
from services.catalyst_catalog import sectors_payload
from services.provider_health import build_provider_health

router = APIRouter(prefix="/api/catalog", tags=["catalog"])


@router.get("/sectors")
async def get_sectors() -> dict:
    sectors = sectors_payload()
    return {"count": len(sectors), "sectors": sectors}


@router.get("/catalysts")
async def get_catalysts(
    active: bool = True,
    db: AsyncSession = Depends(get_db),
) -> dict:
    from services.catalyst_catalog import load_catalysts

    rows = await load_catalysts(db, active_only=active)
    return {
        "count": len(rows),
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
            for c in rows
        ],
    }

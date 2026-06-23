"""Password-protected admin monitoring endpoints."""

from __future__ import annotations

from fastapi import APIRouter, Depends, Header, HTTPException
from pydantic import BaseModel
from sqlalchemy.ext.asyncio import AsyncSession

from config import get_settings
from database import get_db
from services.admin_stats import build_admin_dashboard
from services.app_runtime import get_scheduler

router = APIRouter(prefix="/api/admin", tags=["admin"])


class AdminLoginIn(BaseModel):
    password: str


def _require_admin_password(x_admin_password: str | None = Header(default=None)) -> None:
    expected = get_settings().admin_password.strip()
    if not expected:
        raise HTTPException(503, "ADMIN_PASSWORD not configured on server")
    if x_admin_password != expected:
        raise HTTPException(403, "Invalid admin password")


@router.post("/login")
async def admin_login(body: AdminLoginIn) -> dict:
    expected = get_settings().admin_password.strip()
    if not expected:
        raise HTTPException(503, "ADMIN_PASSWORD not configured on server")
    if body.password != expected:
        raise HTTPException(403, "Invalid password")
    return {"ok": True}


@router.get("/dashboard")
async def admin_dashboard(
    _: None = Depends(_require_admin_password),
    db: AsyncSession = Depends(get_db),
) -> dict:
    scheduler = get_scheduler()
    if scheduler is None:
        raise HTTPException(503, "Scheduler not ready")
    return await build_admin_dashboard(db, scheduler)

from __future__ import annotations

from collections import defaultdict
from datetime import datetime, timedelta, timezone
from zoneinfo import ZoneInfo

import logging

from fastapi import APIRouter, Depends, HTTPException

logger = logging.getLogger(__name__)
from pydantic import BaseModel
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from database import get_db
from models.db_models import AIAlert, AIReport, AISuggestion
from services.ai_context import build_chat_context
from services.ai_jobs import run_missed_pulse_slots_today
from services.chat_prompts import build_daily_chat_prompts
from services.groq_budget import chat_questions_remaining, reserve_chat_question, usage_summary
from services.groq_client import chat_completion

router = APIRouter(prefix="/api/ai", tags=["ai"])

ET = ZoneInfo("America/New_York")
ALERTS_DISPLAY_LIMIT = 50


class ReportOut(BaseModel):
    id: int
    report_type: str
    title: str
    body: str
    created_at: datetime


class SuggestionOut(BaseModel):
    id: int
    symbol: str
    bias: str
    summary: str
    created_at: datetime


class AlertOut(BaseModel):
    id: int
    symbol: str
    alert_type: str
    message: str
    change_pct: float
    created_at: datetime
    delivered_push: bool


class ChatRequest(BaseModel):
    prompt: str
    selected_catalyst_index: int = 0


class ChatResponse(BaseModel):
    response: str
    questions_remaining: int | None = None


class GroqUsageOut(BaseModel):
    day: str
    tokens_used: int
    tokens_budget: int
    tokens_remaining: int
    chat_used: int
    chat_limit: int
    chat_remaining: int


class DigestDayOut(BaseModel):
    date: str
    reports: list[ReportOut]
    alerts: list[AlertOut]
    suggestions: list[SuggestionOut]


class DigestOut(BaseModel):
    days: list[DigestDayOut]


def _day_key(dt: datetime) -> str:
    if dt.tzinfo is None:
        dt = dt.replace(tzinfo=timezone.utc)
    return dt.astimezone(ET).strftime("%Y-%m-%d")


def _et_day_keys(window: int, now: datetime | None = None) -> list[str]:
    """Calendar day keys in US/Eastern for the last `window` days (oldest first)."""
    anchor = (now or datetime.now(timezone.utc)).astimezone(ET)
    return [
        (anchor - timedelta(days=window - 1 - i)).strftime("%Y-%m-%d")
        for i in range(window)
    ]


@router.get("/digest", response_model=DigestOut)
async def digest(days: int = 7, db: AsyncSession = Depends(get_db)) -> DigestOut:
    """Last N calendar days of reports, alerts, and suggestions (newest day last)."""
    window = min(max(days, 1), 7)
    now = datetime.now(timezone.utc)
    cutoff = now - timedelta(days=window)
    day_keys = _et_day_keys(window, now)

    reports_by_day: dict[str, list[ReportOut]] = defaultdict(list)
    alerts_by_day: dict[str, list[AlertOut]] = defaultdict(list)
    suggestions_by_day: dict[str, list[SuggestionOut]] = defaultdict(list)

    report_rows = await db.execute(
        select(AIReport).where(AIReport.created_at >= cutoff).order_by(AIReport.created_at.desc())
    )
    for r in report_rows.scalars().all():
        key = _day_key(r.created_at)
        reports_by_day[key].append(
            ReportOut(
                id=r.id,
                report_type=r.report_type,
                title=r.title,
                body=r.body,
                created_at=r.created_at,
            )
        )

    alert_rows = await db.execute(
        select(AIAlert)
        .where(AIAlert.created_at >= cutoff)
        .order_by(AIAlert.created_at.desc())
        .limit(ALERTS_DISPLAY_LIMIT)
    )
    for a in alert_rows.scalars().all():
        key = _day_key(a.created_at)
        alerts_by_day[key].append(
            AlertOut(
                id=a.id,
                symbol=a.symbol,
                alert_type=a.alert_type,
                message=a.message,
                change_pct=a.change_pct,
                created_at=a.created_at,
                delivered_push=a.delivered_push,
            )
        )

    suggestion_rows = await db.execute(
        select(AISuggestion).where(AISuggestion.created_at >= cutoff).order_by(AISuggestion.created_at.desc())
    )
    for s in suggestion_rows.scalars().all():
        key = _day_key(s.created_at)
        suggestions_by_day[key].append(
            SuggestionOut(
                id=s.id,
                symbol=s.symbol,
                bias=s.bias,
                summary=s.summary,
                created_at=s.created_at,
            )
        )

    return DigestOut(
        days=[
            DigestDayOut(
                date=d,
                reports=reports_by_day.get(d, []),
                alerts=alerts_by_day.get(d, []),
                suggestions=suggestions_by_day.get(d, []),
            )
            for d in day_keys
        ]
    )


@router.post("/reports/catch-up")
async def catch_up_pulse_reports() -> dict:
    """Generate any missed open/midday/close pulse reports for today (ET)."""
    try:
        return await run_missed_pulse_slots_today()
    except Exception as exc:
        logger.exception("Pulse catch-up failed")
        raise HTTPException(status_code=503, detail=str(exc)) from exc


@router.get("/reports", response_model=list[ReportOut])
async def list_reports(limit: int = 20, db: AsyncSession = Depends(get_db)) -> list[ReportOut]:
    result = await db.execute(select(AIReport).order_by(AIReport.created_at.desc()).limit(limit))
    return [
        ReportOut(
            id=r.id,
            report_type=r.report_type,
            title=r.title,
            body=r.body,
            created_at=r.created_at,
        )
        for r in result.scalars().all()
    ]


@router.get("/chat-prompts", response_model=list[str])
async def chat_prompts(db: AsyncSession = Depends(get_db)) -> list[str]:
    return await build_daily_chat_prompts(db)


@router.get("/suggestions", response_model=list[SuggestionOut])
async def list_suggestions(limit: int = 30, db: AsyncSession = Depends(get_db)) -> list[SuggestionOut]:
    result = await db.execute(select(AISuggestion).order_by(AISuggestion.created_at.desc()).limit(limit))
    return [
        SuggestionOut(
            id=s.id,
            symbol=s.symbol,
            bias=s.bias,
            summary=s.summary,
            created_at=s.created_at,
        )
        for s in result.scalars().all()
    ]


@router.get("/alerts", response_model=list[AlertOut])
async def list_alerts(limit: int = ALERTS_DISPLAY_LIMIT, db: AsyncSession = Depends(get_db)) -> list[AlertOut]:
    cap = min(max(limit, 1), ALERTS_DISPLAY_LIMIT)
    result = await db.execute(select(AIAlert).order_by(AIAlert.created_at.desc()).limit(cap))
    return [
        AlertOut(
            id=a.id,
            symbol=a.symbol,
            alert_type=a.alert_type,
            message=a.message,
            change_pct=a.change_pct,
            created_at=a.created_at,
            delivered_push=a.delivered_push,
        )
        for a in result.scalars().all()
    ]


@router.get("/groq-usage", response_model=GroqUsageOut)
async def groq_usage() -> GroqUsageOut:
    s = usage_summary()
    return GroqUsageOut(
        day=str(s["day"]),
        tokens_used=int(s["tokens_used"]),
        tokens_budget=int(s["tokens_budget"]),
        tokens_remaining=int(s["tokens_remaining"]),
        chat_used=int(s["chat_used"]),
        chat_limit=int(s["chat_limit"]),
        chat_remaining=int(s["chat_remaining"]),
    )


@router.post("/chat", response_model=ChatResponse)
async def chat(req: ChatRequest, db: AsyncSession = Depends(get_db)) -> ChatResponse:
    if not reserve_chat_question():
        raise HTTPException(
            status_code=429,
            detail="Daily AI question limit reached (10). Try again tomorrow.",
        )
    try:
        context = await build_chat_context(db)
        if req.selected_catalyst_index >= 0:
            context += f"\n[USER SELECTED CATALYST INDEX] {req.selected_catalyst_index}"
        text = await chat_completion(context, req.prompt, max_tokens=800)
        return ChatResponse(response=text, questions_remaining=chat_questions_remaining())
    except RuntimeError as exc:
        logger.warning("AI chat misconfigured: %s", exc)
        raise HTTPException(status_code=503, detail=str(exc)) from exc
    except Exception as exc:
        logger.exception("AI chat failed")
        raise HTTPException(
            status_code=503,
            detail="AI analysis temporarily unavailable. Try again shortly.",
        ) from exc

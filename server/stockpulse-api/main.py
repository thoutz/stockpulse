from __future__ import annotations

from apscheduler.schedulers.asyncio import AsyncIOScheduler
from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from starlette.middleware.base import BaseHTTPMiddleware

import asyncio
import logging
from contextlib import asynccontextmanager
from zoneinfo import ZoneInfo

from config import get_settings
from database import init_db
from routers import admin, ai, catalog, data, intelligence, monitor, session, trading
from services.request_metrics import record_request
from services.ai_jobs import (
    run_missed_pulse_slots_today,
    run_movement_alerts,
    run_pulse_close,
    run_pulse_midday,
    run_pulse_open,
    run_snapshot_suggestions,
)
from services.ingest import ingest_scheduler
from services.daily_av_ingest import run_daily_av_ingest_job
from services.provider_health import run_provider_health_check
from services.quote_history import load_quote_history_from_db
from services.quote_scheduler import run_quote_cycle
from services.session_intelligence import run_pre_pulse_intelligence
from services.catalyst_catalog import seed_builtin_catalysts
from services.session_tracker import run_news_ingest_job, run_session_tracker_job
from services.news_ingest import news_ingest_interval_minutes
from services.trading_jobs import run_auto_trade_cycle
from services.micro_trading_jobs import run_micro_trade_cycle

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

scheduler = AsyncIOScheduler()


class RequestMetricsMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request: Request, call_next):
        response = await call_next(request)
        if request.url.path.startswith("/api/"):
            record_request(request.method, request.url.path)
        return response


@asynccontextmanager
async def lifespan(app: FastAPI):
    await init_db()
    try:
        await load_quote_history_from_db()
    except Exception:
        logger.exception("Quote history load failed (5m/15m windows will rebuild)")

    try:
        from database import SessionLocal

        async with SessionLocal() as session:
            seeded = await seed_builtin_catalysts(session)
            await session.commit()
            if seeded:
                logger.info("Seeded %d catalyst events on startup", seeded)
    except Exception:
        logger.exception("Catalyst seed failed")

    logger.info("Running initial Massive warm-up (daily bars for all tickers)...")
    try:
        await ingest_scheduler.full_refresh()
    except Exception:
        logger.exception("Initial warm-up failed (will retry on schedule)")

    scheduler.add_job(ingest_scheduler.run_cycle, "interval", seconds=12, id="ingest")
    scheduler.add_job(
        run_quote_cycle,
        "interval",
        seconds=get_settings().quote_scheduler_seconds,
        id="quote_ingest",
    )
    scheduler.add_job(run_movement_alerts, "interval", minutes=1, id="alerts")
    scheduler.add_job(run_session_tracker_job, "interval", minutes=10, id="session_tracker")
    scheduler.add_job(run_provider_health_check, "interval", minutes=30, id="provider_health")
    scheduler.add_job(run_news_ingest_job, "interval", minutes=news_ingest_interval_minutes(), id="news_ingest")
    scheduler.add_job(run_snapshot_suggestions, "interval", minutes=60, id="suggestions")
    scheduler.add_job(ingest_scheduler.request_full_name_resync, "interval", hours=12, id="name_resync")
    et = ZoneInfo("America/New_York")
    scheduler.add_job(run_daily_av_ingest_job, "cron", hour=15, minute=45, timezone=et, id="av_daily")
    scheduler.add_job(run_pre_pulse_intelligence, "cron", hour=9, minute=55, args=["open"], timezone=et, id="intel_open")
    scheduler.add_job(run_pre_pulse_intelligence, "cron", hour=12, minute=55, args=["midday"], timezone=et, id="intel_midday")
    scheduler.add_job(run_pre_pulse_intelligence, "cron", hour=15, minute=55, args=["close"], timezone=et, id="intel_close")
    scheduler.add_job(run_pulse_open, "cron", hour=10, minute=0, timezone=et, id="pulse_open")
    scheduler.add_job(run_pulse_midday, "cron", hour=13, minute=0, timezone=et, id="pulse_midday")
    scheduler.add_job(run_pulse_close, "cron", hour=16, minute=0, timezone=et, id="pulse_close")
    scheduler.add_job(run_auto_trade_cycle, "cron", hour=10, minute=15, timezone=et, id="auto_trade_open")
    scheduler.add_job(run_auto_trade_cycle, "cron", hour=13, minute=15, timezone=et, id="auto_trade_midday")
    scheduler.add_job(run_auto_trade_cycle, "cron", hour=16, minute=5, timezone=et, id="auto_trade_close")
    scheduler.add_job(
        run_micro_trade_cycle,
        "interval",
        minutes=get_settings().micro_scan_interval_minutes,
        id="micro_trade",
    )
    scheduler.start()
    logger.info("Scheduler started")

    from services.app_runtime import set_scheduler

    set_scheduler(scheduler)

    async def _background_catch_up() -> None:
        await asyncio.sleep(30)
        try:
            catch_up_result = await run_missed_pulse_slots_today()
            logger.info("Pulse catch-up result: %s", catch_up_result)
        except Exception:
            logger.exception("Missed pulse catch-up failed")
        try:
            await ingest_scheduler.request_full_name_resync()
        except Exception:
            logger.exception("Startup name resync enqueue failed")

    asyncio.create_task(_background_catch_up())
    yield
    scheduler.shutdown(wait=False)


app = FastAPI(
    title="StockPulse API",
    description="Massive data ingestion + Groq autonomous assistant",
    version="1.0.0",
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "https://tryan.app",
        "https://www.tryan.app",
        "http://localhost:5173",
        "http://127.0.0.1:5173",
    ],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)
app.add_middleware(RequestMetricsMiddleware)

app.include_router(data.router)
app.include_router(catalog.router)
app.include_router(monitor.router)
app.include_router(intelligence.router)
app.include_router(ai.router)
app.include_router(session.router)
app.include_router(trading.router)
app.include_router(admin.router)

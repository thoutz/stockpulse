"""Database and scheduler stats for the admin dashboard."""

from __future__ import annotations

from datetime import datetime, timezone

from sqlalchemy import func, select, text
from sqlalchemy.ext.asyncio import AsyncSession

from config import get_settings
from models.db_models import (
    BarDaily,
    BarMinute,
    Favorite,
    QuoteTick,
    SessionFavorite,
    Snapshot,
    Ticker,
)
from services.dashboard_build import build_data_status
from services.groq_budget import usage_summary
from services.ingest import ingest_scheduler
from services.provider_health import build_provider_health
from services.request_metrics import build_request_metrics
from services.tracked import get_tracked_symbols


def _format_bytes(num: int) -> str:
    if num < 1024:
        return f"{num} B"
    if num < 1024**2:
        return f"{num / 1024:.1f} KB"
    if num < 1024**3:
        return f"{num / 1024**2:.1f} MB"
    return f"{num / 1024**3:.2f} GB"


async def _db_health(session: AsyncSession) -> dict:
    started = datetime.now(timezone.utc)
    try:
        await session.execute(text("SELECT 1"))
        latency_ms = (datetime.now(timezone.utc) - started).total_seconds() * 1000
        healthy = True
        error = None
    except Exception as exc:
        latency_ms = None
        healthy = False
        error = str(exc)

    size_result = await session.execute(text("SELECT pg_database_size(current_database())"))
    db_size_bytes = size_result.scalar() or 0

    table_stats_result = await session.execute(
        text(
            """
            SELECT
                relname AS table_name,
                n_live_tup AS row_estimate,
                pg_total_relation_size(relid) AS size_bytes
            FROM pg_stat_user_tables
            ORDER BY pg_total_relation_size(relid) DESC
            """
        )
    )
    tables = [
        {
            "table": row.table_name,
            "rows": int(row.row_estimate or 0),
            "size_bytes": int(row.size_bytes or 0),
            "size_human": _format_bytes(int(row.size_bytes or 0)),
        }
        for row in table_stats_result
    ]

    return {
        "healthy": healthy,
        "latency_ms": round(latency_ms, 2) if latency_ms is not None else None,
        "error": error,
        "database_size_bytes": int(db_size_bytes),
        "database_size_human": _format_bytes(int(db_size_bytes)),
        "tables": tables,
    }


async def _symbol_stats(session: AsyncSession) -> dict:
    settings = get_settings()

    total_tickers = (await session.execute(select(func.count()).select_from(Ticker))).scalar() or 0
    active_tickers = (
        await session.execute(select(func.count()).select_from(Ticker).where(Ticker.active.is_(True)))
    ).scalar() or 0
    favorites_count = (await session.execute(select(func.count()).select_from(Favorite))).scalar() or 0
    session_favorites_count = (
        await session.execute(select(func.count()).select_from(SessionFavorite))
    ).scalar() or 0
    tracked = await get_tracked_symbols(session)
    snapshots_count = (await session.execute(select(func.count()).select_from(Snapshot))).scalar() or 0
    daily_bars = (await session.execute(select(func.count()).select_from(BarDaily))).scalar() or 0
    minute_bars = (await session.execute(select(func.count()).select_from(BarMinute))).scalar() or 0
    quote_ticks = (await session.execute(select(func.count()).select_from(QuoteTick))).scalar() or 0

    distinct_symbols_daily = (
        await session.execute(select(func.count(func.distinct(BarDaily.symbol))))
    ).scalar() or 0

    return {
        "config_tickers": settings.ticker_list,
        "config_ticker_count": len(settings.ticker_list),
        "tracked_count": len(tracked),
        "tracked_symbols": tracked,
        "db_ticker_count": int(total_tickers),
        "active_ticker_count": int(active_tickers),
        "inactive_ticker_count": int(total_tickers) - int(active_tickers),
        "favorites_count": int(favorites_count),
        "session_favorites_count": int(session_favorites_count),
        "symbols_with_daily_bars": int(distinct_symbols_daily),
        "total_daily_bars": int(daily_bars),
        "total_minute_bars": int(minute_bars),
        "total_snapshots": int(snapshots_count),
        "total_quote_ticks": int(quote_ticks),
    }


def _scheduler_stats(scheduler) -> dict:
    jobs = []
    for job in scheduler.get_jobs():
        next_run = job.next_run_time.isoformat() if job.next_run_time else None
        jobs.append(
            {
                "id": job.id,
                "name": job.name,
                "next_run": next_run,
                "trigger": str(job.trigger),
            }
        )
    return {
        "running": scheduler.running,
        "job_count": len(jobs),
        "jobs": jobs,
        "ingest_warm_complete": ingest_scheduler.warm_complete,
    }


async def build_admin_dashboard(session: AsyncSession, scheduler) -> dict:
    now = datetime.now(timezone.utc)
    provider_health = await build_provider_health(session)
    data_status = await build_data_status(session)
    db_health = await _db_health(session)
    symbol_stats = await _symbol_stats(session)

    return {
        "generated_at": now.isoformat(),
        "api": build_request_metrics(),
        "providers": provider_health,
        "database": db_health,
        "symbols": symbol_stats,
        "symbol_data": data_status,
        "groq": usage_summary(),
        "scheduler": _scheduler_stats(scheduler),
    }

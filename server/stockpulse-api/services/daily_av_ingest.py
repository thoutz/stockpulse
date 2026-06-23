from __future__ import annotations

import logging
import re
from datetime import datetime, timedelta, timezone
from zoneinfo import ZoneInfo

from sqlalchemy import select
from sqlalchemy.dialects.postgresql import insert
from sqlalchemy.ext.asyncio import AsyncSession

from models.db_models import AVDailyBundle, NewsItem
from services.alphavantage_client import (
    AlphaVantageClient,
    format_breadth_summary,
    format_earnings_summary,
    format_overview_summary,
    pick_overview_symbols,
)
from services.tracked import get_tracked_symbols

logger = logging.getLogger(__name__)
ET = ZoneInfo("America/New_York")


def _session_date_key() -> str:
    return datetime.now(ET).strftime("%Y-%m-%d")


async def _aggregate_news_sentiment(session: AsyncSession, symbols: set[str]) -> str:
    cutoff = datetime.now(timezone.utc) - timedelta(hours=24)
    result = await session.execute(
        select(NewsItem)
        .where(NewsItem.published_at >= cutoff, NewsItem.symbol.in_(symbols))
        .order_by(NewsItem.published_at.desc())
    )
    rows = result.scalars().all()
    if not rows:
        return "No news sentiment in the last 24h for tracked tickers."

    by_sym: dict[str, list[float]] = {}
    for row in rows:
        score = row.sentiment_score
        if score is None and row.summary:
            m = re.search(r"sentiment\s*([+-]?\d+\.\d+)", row.summary, re.I)
            if m:
                score = float(m.group(1))
        if score is not None:
            by_sym.setdefault(row.symbol, []).append(score)

    lines: list[str] = []
    for sym in sorted(by_sym.keys()):
        scores = by_sym[sym]
        avg = sum(scores) / len(scores)
        label = "bullish" if avg >= 0.15 else "bearish" if avg <= -0.15 else "neutral"
        lines.append(f"{sym}: avg sentiment {avg:+.2f} ({label}, {len(scores)} articles)")

    headline_count = len(rows)
    lines.insert(0, f"24h headline count: {headline_count} across {len(by_sym)} tickers with scores")
    return "\n".join(lines)


async def ingest_daily_av_bundle(session: AsyncSession, force: bool = False) -> AVDailyBundle | None:
    client = AlphaVantageClient()
    if not client.configured:
        logger.info("Alpha Vantage not configured — skipping daily bundle")
        return None

    session_date = _session_date_key()
    existing = (
        await session.execute(
            select(AVDailyBundle).where(AVDailyBundle.session_date == session_date).limit(1)
        )
    ).scalar_one_or_none()
    if existing and not force:
        return existing

    tracked = await get_tracked_symbols(session)
    symbol_set = {s.upper() for s in tracked}
    overview_syms = pick_overview_symbols(tracked, session_date)

    earnings_rows, breadth, overviews = await client.fetch_daily_bundle_parts(
        symbol_set, overview_syms
    )

    bundle = AVDailyBundle(
        session_date=session_date,
        earnings_summary=format_earnings_summary(earnings_rows, symbol_set),
        market_breadth=format_breadth_summary(breadth),
        fundamentals_summary=format_overview_summary(overviews),
        news_sentiment_summary=await _aggregate_news_sentiment(session, symbol_set),
    )

    if existing:
        existing.earnings_summary = bundle.earnings_summary
        existing.market_breadth = bundle.market_breadth
        existing.fundamentals_summary = bundle.fundamentals_summary
        existing.news_sentiment_summary = bundle.news_sentiment_summary
        await session.flush()
        logger.info("Updated AV daily bundle for %s", session_date)
        return existing

    session.add(bundle)
    await session.flush()
    logger.info(
        "Created AV daily bundle for %s (%d overview symbols)",
        session_date,
        len(overviews),
    )
    return bundle


async def ensure_daily_av_bundle(session: AsyncSession) -> AVDailyBundle | None:
    session_date = _session_date_key()
    existing = (
        await session.execute(
            select(AVDailyBundle).where(AVDailyBundle.session_date == session_date).limit(1)
        )
    ).scalar_one_or_none()
    if existing:
        existing.news_sentiment_summary = await _aggregate_news_sentiment(
            session, {s.upper() for s in await get_tracked_symbols(session)}
        )
        return existing
    return await ingest_daily_av_bundle(session, force=False)


async def run_daily_av_ingest_job() -> None:
    from database import SessionLocal

    async with SessionLocal() as session:
        await ingest_daily_av_bundle(session)
        await session.commit()

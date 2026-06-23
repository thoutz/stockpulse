from __future__ import annotations

from datetime import datetime, timedelta, timezone
from zoneinfo import ZoneInfo

from sqlalchemy import delete, select
from sqlalchemy.dialects.postgresql import insert
from sqlalchemy.ext.asyncio import AsyncSession

from config import get_settings
from models.db_models import NewsItem
from services.alphavantage_client import AlphaVantageClient
from services.finnhub_client import FinnhubClient
from services.monitor_tiers import MonitorTier, build_tier_map
from services.tracked import get_tracked_symbols

ET = ZoneInfo("America/New_York")
_news_ticker_index = 0


def _active_news_provider() -> str | None:
    settings = get_settings()
    if settings.alphavantage_api_key.strip():
        return "alphavantage"
    if settings.finnhub_api_key.strip():
        return "finnhub"
    return None


def news_ingest_interval_minutes() -> int:
    """Alpha Vantage free tier: 25 req/day — use 60 min. Finnhub can run every 15 min."""
    return 60 if _active_news_provider() == "alphavantage" else 15


async def _tier_sorted_tickers(session: AsyncSession) -> list[str]:
    """HOT symbols polled most often, then WARM, then COLD."""
    tier_map = await build_tier_map(session)
    tracked = await get_tracked_symbols(session)
    hot = [s for s in tracked if tier_map.get(s) == MonitorTier.HOT]
    warm = [s for s in tracked if tier_map.get(s) == MonitorTier.WARM]
    cold = [s for s in tracked if tier_map.get(s) == MonitorTier.COLD]
    other = [s for s in tracked if s not in hot and s not in warm and s not in cold]
    return hot + warm + cold + other


async def ingest_news_for_next_ticker(session: AsyncSession) -> tuple[str | None, str | None]:
    """Returns (symbol, provider) or (None, None)."""
    global _news_ticker_index
    provider = _active_news_provider()
    if not provider:
        return None, None

    tickers = await _tier_sorted_tickers(session)
    if not tickers:
        return None, None

    symbol = tickers[_news_ticker_index % len(tickers)]
    _news_ticker_index += 1

    if provider == "alphavantage":
        articles = await AlphaVantageClient().fetch_company_news(symbol, limit=20)
    else:
        articles = await FinnhubClient().fetch_company_news(symbol, days=7)

    for article in articles:
        stmt = insert(NewsItem).values(
            symbol=article["symbol"],
            headline=article["headline"],
            summary=article["summary"],
            source=article["source"],
            url=article["url"],
            published_at=article["published_at"],
            sentiment_score=article.get("sentiment_score"),
        )
        stmt = stmt.on_conflict_do_nothing(index_elements=["url"])
        await session.execute(stmt)

    cutoff = datetime.now(timezone.utc) - timedelta(days=14)
    await session.execute(delete(NewsItem).where(NewsItem.published_at < cutoff))
    return symbol, provider

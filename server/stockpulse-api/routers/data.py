from __future__ import annotations

import logging
from datetime import datetime, timedelta, timezone

from fastapi import APIRouter, BackgroundTasks, Depends, HTTPException, Query
from pydantic import BaseModel
from sqlalchemy import func, select
from sqlalchemy.dialects.postgresql import insert as pg_insert
from sqlalchemy.ext.asyncio import AsyncSession

from config import get_settings
from database import get_db
from models.db_models import BarDaily, BarMinute, Favorite, Indicator, NewsItem, Snapshot, Ticker
from services.dashboard_build import build_dashboard, build_data_status
from services.ingest import ingest_scheduler
from services.provider_health import build_provider_health
from services.ticker_search import hybrid_search_tickers

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api", tags=["data"])


class TickerOut(BaseModel):
    symbol: str
    name: str | None = None
    active: bool


class TickerSearchOut(BaseModel):
    symbol: str
    name: str = ""


class FavoriteOut(BaseModel):
    symbol: str
    name: str | None = None


class FavoriteIn(BaseModel):
    symbol: str
    name: str | None = None


class BarOut(BaseModel):
    date: datetime
    open: float
    high: float
    low: float
    close: float
    volume: float


class SnapshotOut(BaseModel):
    symbol: str
    price: float
    change_1d_pct: float
    change_30d_pct: float
    change_5m_pct: float | None = None
    change_15m_pct: float | None = None
    rsi: float | None
    sma_20: float | None
    quote_source: str | None = None
    captured_at: datetime


class HistoriesOut(BaseModel):
    histories: dict[str, list[BarOut]]


class NewsOut(BaseModel):
    symbol: str
    headline: str
    summary: str | None = None
    source: str | None = None
    url: str
    published_at: datetime
    sentiment_score: float | None = None


@router.get("/health")
async def health() -> dict:
    return {"status": "ok", "service": "stockpulse-api"}


@router.get("/health/providers")
async def health_providers(db: AsyncSession = Depends(get_db)) -> dict:
    return await build_provider_health(db)


@router.get("/dashboard")
async def get_dashboard(db: AsyncSession = Depends(get_db)) -> dict:
    return await build_dashboard(db)


@router.get("/data-status")
async def get_data_status(db: AsyncSession = Depends(get_db)) -> dict:
    return await build_data_status(db)


@router.get("/tickers", response_model=list[TickerOut])
async def list_tickers(db: AsyncSession = Depends(get_db)) -> list[TickerOut]:
    result = await db.execute(select(Ticker).where(Ticker.active == True).order_by(Ticker.symbol))
    rows = result.scalars().all()
    return [TickerOut(symbol=r.symbol, name=r.name, active=r.active) for r in rows]


@router.get("/search", response_model=list[TickerSearchOut])
async def search_tickers(
    q: str = Query(..., min_length=1),
    db: AsyncSession = Depends(get_db),
) -> list[TickerSearchOut]:
    try:
        results = await hybrid_search_tickers(db, q.strip())
    except Exception as exc:  # noqa: BLE001
        raise HTTPException(502, f"Search failed: {exc}") from exc
    return [TickerSearchOut(symbol=r["symbol"], name=r.get("name", "")) for r in results]


class FavoriteListOut(BaseModel):
    favorites: list[FavoriteOut]
    count: int
    limit: int


@router.get("/favorites", response_model=FavoriteListOut)
async def list_favorites(db: AsyncSession = Depends(get_db)) -> FavoriteListOut:
    settings = get_settings()
    result = await db.execute(select(Favorite).order_by(Favorite.symbol))
    rows = [FavoriteOut(symbol=f.symbol, name=f.name) for f in result.scalars().all()]
    return FavoriteListOut(
        favorites=rows,
        count=len(rows),
        limit=settings.favorite_limit,
    )


async def _backfill_favorite(symbol: str) -> None:
    """Pull daily bars + snapshot for a newly favorited symbol so it appears quickly."""
    try:
        await ingest_scheduler._ingest_daily_only(symbol)
    except Exception:
        logger.exception("Favorite backfill failed for %s", symbol)


@router.post("/favorites", response_model=FavoriteOut)
async def add_favorite(
    body: FavoriteIn,
    background_tasks: BackgroundTasks,
    db: AsyncSession = Depends(get_db),
) -> FavoriteOut:
    symbol = body.symbol.strip().upper()
    if not symbol:
        raise HTTPException(400, "symbol is required")

    settings = get_settings()
    existing = await db.get(Favorite, symbol)
    if existing is None:
        count_result = await db.execute(select(func.count()).select_from(Favorite))
        if (count_result.scalar() or 0) >= settings.favorite_limit:
            raise HTTPException(
                409,
                f"Favorite limit reached ({settings.favorite_limit}). Remove one to add another.",
            )
    await db.execute(
        pg_insert(Favorite)
        .values(symbol=symbol, name=body.name)
        .on_conflict_do_update(index_elements=["symbol"], set_={"name": body.name})
    )
    ticker_stmt = pg_insert(Ticker).values(symbol=symbol, name=body.name, active=True)
    if body.name:
        ticker_stmt = ticker_stmt.on_conflict_do_update(
            index_elements=["symbol"], set_={"name": body.name, "active": True}
        )
    else:
        ticker_stmt = ticker_stmt.on_conflict_do_nothing(index_elements=["symbol"])
    await db.execute(ticker_stmt)
    await db.commit()

    background_tasks.add_task(_backfill_favorite, symbol)
    return FavoriteOut(symbol=symbol, name=body.name)


@router.delete("/favorites/{symbol}")
async def remove_favorite(symbol: str, db: AsyncSession = Depends(get_db)) -> dict:
    sym = symbol.strip().upper()
    fav = await db.get(Favorite, sym)
    if fav is None:
        raise HTTPException(404, f"{sym} is not a favorite")
    await db.delete(fav)
    await db.commit()
    return {"removed": sym}


@router.get("/histories", response_model=HistoriesOut)
async def get_histories(
    tickers: str | None = Query(None, description="Comma-separated tickers"),
    days: int = 90,
    db: AsyncSession = Depends(get_db),
) -> HistoriesOut:
    settings = get_settings()
    symbols = (
        [t.strip().upper() for t in tickers.split(",") if t.strip()]
        if tickers
        else settings.ticker_list
    )
    cutoff = datetime.now(timezone.utc) - timedelta(days=max(days, 1))
    out: dict[str, list[BarOut]] = {}
    for sym in symbols:
        result = await db.execute(
            select(BarDaily)
            .where(BarDaily.symbol == sym, BarDaily.bar_date >= cutoff)
            .order_by(BarDaily.bar_date)
        )
        bars = result.scalars().all()
        if bars:
            out[sym] = [
                BarOut(
                    date=b.bar_date,
                    open=b.open,
                    high=b.high,
                    low=b.low,
                    close=b.close,
                    volume=b.volume,
                )
                for b in bars
            ]
    return HistoriesOut(histories=out)


@router.get("/history/{symbol}", response_model=list[BarOut])
async def get_history(symbol: str, days: int = 90, db: AsyncSession = Depends(get_db)) -> list[BarOut]:
    sym = symbol.upper()
    cutoff = datetime.now(timezone.utc) - timedelta(days=max(days, 1))
    result = await db.execute(
        select(BarDaily)
        .where(BarDaily.symbol == sym, BarDaily.bar_date >= cutoff)
        .order_by(BarDaily.bar_date)
    )
    bars = result.scalars().all()
    if not bars:
        raise HTTPException(404, f"No history for {sym}")
    return [
        BarOut(
            date=b.bar_date,
            open=b.open,
            high=b.high,
            low=b.low,
            close=b.close,
            volume=b.volume,
        )
        for b in bars
    ]


@router.get("/snapshot", response_model=list[SnapshotOut])
async def get_snapshot(db: AsyncSession = Depends(get_db)) -> list[SnapshotOut]:
    result = await db.execute(select(Snapshot).order_by(Snapshot.captured_at.desc()).limit(50))
    rows = result.scalars().all()
    seen: set[str] = set()
    out: list[SnapshotOut] = []
    for s in rows:
        if s.symbol in seen:
            continue
        seen.add(s.symbol)
        out.append(
            SnapshotOut(
                symbol=s.symbol,
                price=s.price,
                change_1d_pct=s.change_1d_pct,
                change_30d_pct=s.change_30d_pct,
                change_5m_pct=s.change_5m_pct,
                change_15m_pct=s.change_15m_pct,
                rsi=s.rsi,
                sma_20=s.sma_20,
                quote_source=s.quote_source,
                captured_at=s.captured_at,
            )
        )
    return sorted(out, key=lambda x: x.symbol)


@router.get("/indicators/{symbol}")
async def get_indicators(symbol: str, db: AsyncSession = Depends(get_db)) -> list[dict]:
    sym = symbol.upper()
    result = await db.execute(
        select(Indicator).where(Indicator.symbol == sym).order_by(Indicator.bar_ts.desc()).limit(60)
    )
    rows = result.scalars().all()
    return [
        {
            "type": r.indicator_type,
            "ts": r.bar_ts.isoformat(),
            "value": r.value,
        }
        for r in rows
    ]


@router.get("/news", response_model=list[NewsOut])
async def get_news(
    symbol: str | None = Query(None, description="Single ticker symbol"),
    symbols: str | None = Query(None, description="Comma-separated tickers"),
    limit: int = Query(8, ge=1, le=50),
    hours: int = Query(72, ge=1, le=168),
    db: AsyncSession = Depends(get_db),
) -> list[NewsOut]:
    """Recent headlines for one or more tickers (ingested every 15–60 min)."""
    requested: list[str] = []
    if symbol and symbol.strip():
        requested.append(symbol.strip().upper())
    if symbols and symbols.strip():
        requested.extend(s.strip().upper() for s in symbols.split(",") if s.strip())
    if not requested:
        raise HTTPException(400, "Provide symbol or symbols query parameter")

    unique_symbols = list(dict.fromkeys(requested))
    cutoff = datetime.now(timezone.utc) - timedelta(hours=hours)
    result = await db.execute(
        select(NewsItem)
        .where(NewsItem.symbol.in_(unique_symbols), NewsItem.published_at >= cutoff)
        .order_by(NewsItem.published_at.desc())
        .limit(limit * len(unique_symbols))
    )
    rows = result.scalars().all()
    out: list[NewsOut] = []
    seen_urls: set[str] = set()
    for row in rows:
        if row.url in seen_urls:
            continue
        seen_urls.add(row.url)
        out.append(
            NewsOut(
                symbol=row.symbol,
                headline=row.headline,
                summary=row.summary,
                source=row.source,
                url=row.url,
                published_at=row.published_at,
                sentiment_score=row.sentiment_score,
            )
        )
        if len(out) >= limit:
            break
    return out


@router.get("/minute/{symbol}", response_model=list[BarOut])
async def get_minute(symbol: str, limit: int = 100, db: AsyncSession = Depends(get_db)) -> list[BarOut]:
    sym = symbol.upper()
    result = await db.execute(
        select(BarMinute).where(BarMinute.symbol == sym).order_by(BarMinute.bar_ts.desc()).limit(limit)
    )
    bars = list(reversed(result.scalars().all()))
    return [
        BarOut(date=b.bar_ts, open=b.open, high=b.high, low=b.low, close=b.close, volume=b.volume)
        for b in bars
    ]

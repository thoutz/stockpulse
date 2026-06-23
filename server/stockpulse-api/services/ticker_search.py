from __future__ import annotations

from sqlalchemy import or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from models.db_models import Ticker
from services.finnhub_client import FinnhubClient
from services.massive_client import MassiveClient

LOCAL_RESULT_THRESHOLD = 5


async def search_tickers_local(
    db: AsyncSession, query: str, limit: int = 15
) -> list[dict[str, str]]:
    q = query.strip()
    if not q:
        return []

    pattern = f"%{q}%"
    prefix = f"{q.upper()}%"
    result = await db.execute(
        select(Ticker)
        .where(Ticker.active.is_(True))
        .where(or_(Ticker.symbol.ilike(prefix), Ticker.name.ilike(pattern)))
        .order_by(Ticker.symbol)
        .limit(limit)
    )
    rows = result.scalars().all()
    return [{"symbol": row.symbol, "name": row.name or ""} for row in rows]


async def _remote_search(query: str, limit: int) -> list[dict[str, str]]:
    finnhub = FinnhubClient()
    if finnhub.configured:
        results = await finnhub.search_symbols(query, limit=limit)
        if results:
            return results
    return await MassiveClient().search_tickers(query, limit=limit)


async def hybrid_search_tickers(
    db: AsyncSession, query: str, limit: int = 15
) -> list[dict[str, str]]:
    local = await search_tickers_local(db, query, limit)
    if len(local) >= LOCAL_RESULT_THRESHOLD:
        return local[:limit]

    try:
        remote = await _remote_search(query, limit=limit)
    except Exception:
        if local:
            return local[:limit]
        raise

    seen = {item["symbol"] for item in local}
    merged = list(local)
    for item in remote:
        symbol = item["symbol"]
        if symbol in seen:
            continue
        merged.append(item)
        seen.add(symbol)
        if len(merged) >= limit:
            break
    return merged[:limit]

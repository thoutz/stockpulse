from __future__ import annotations

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from config import get_settings
from models.db_models import Favorite


async def get_tracked_symbols(session: AsyncSession) -> list[str]:
    """Symbols the server actively ingests: static config list plus user favorites."""
    settings = get_settings()
    symbols: list[str] = list(settings.ticker_list)
    seen = {s for s in symbols}

    result = await session.execute(select(Favorite.symbol))
    for (symbol,) in result.all():
        sym = symbol.upper()
        if sym not in seen:
            seen.add(sym)
            symbols.append(sym)
    return symbols

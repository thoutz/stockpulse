"""Single source of truth: symbols on Monitor are analyzed and tradable."""

from __future__ import annotations

from sqlalchemy.ext.asyncio import AsyncSession

from services.tracked import get_tracked_symbols


async def monitored_symbols(session: AsyncSession) -> list[str]:
    """All symbols the user sees on Monitor (config seed list + favorites)."""
    return await get_tracked_symbols(session)


async def monitored_symbol_set(session: AsyncSession) -> set[str]:
    return {s.upper() for s in await monitored_symbols(session)}

"""Canonical sector groupings — keep in sync with ios/StockPulse/Data/IndustryCatalog.swift."""

from __future__ import annotations

from dataclasses import dataclass


@dataclass(frozen=True)
class SectorDef:
    id: str
    name: str
    description: str
    tickers: tuple[str, ...]
    accent_hex: str


SECTORS: tuple[SectorDef, ...] = (
    SectorDef(
        id="semiconductors",
        name="Semiconductors",
        description="AI chips, networking, and compute",
        tickers=("NVDA", "AMD", "AVGO"),
        accent_hex="a78bfa",
    ),
    SectorDef(
        id="space",
        name="Space & Aerospace",
        description="Launch, satellites, and defense components",
        tickers=("RKLB", "ASTS", "LUNR", "RDW", "HWM"),
        accent_hex="60a5fa",
    ),
    SectorDef(
        id="ev",
        name="EV & Auto",
        description="Electric vehicles and mobility",
        tickers=("TSLA",),
        accent_hex="f59e0b",
    ),
)

SECTOR_BY_ID: dict[str, SectorDef] = {s.id: s for s in SECTORS}

SYMBOL_TO_SECTOR: dict[str, str] = {}
for _sector in SECTORS:
    for _sym in _sector.tickers:
        SYMBOL_TO_SECTOR[_sym] = _sector.id

# Legacy labels used in pulse reports
SECTOR_GROUPS: dict[str, list[str]] = {
    "Chips/AI": list(SECTOR_BY_ID["semiconductors"].tickers),
    "Space": list(SECTOR_BY_ID["space"].tickers),
    "EV/Tech": list(SECTOR_BY_ID["ev"].tickers),
}


def sector_for_symbol(symbol: str) -> SectorDef | None:
    sid = SYMBOL_TO_SECTOR.get(symbol.upper())
    return SECTOR_BY_ID.get(sid) if sid else None

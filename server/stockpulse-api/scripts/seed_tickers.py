#!/usr/bin/env python3
"""Seed the tickers table with S&P 500, NASDAQ-100, and Dow 30 constituents."""

from __future__ import annotations

import asyncio
import csv
import io
import sys
from dataclasses import dataclass
from pathlib import Path

import httpx
from sqlalchemy.dialects.postgresql import insert as pg_insert

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from database import SessionLocal, init_db  # noqa: E402
from models.db_models import Ticker  # noqa: E402

SP500_URL = "https://raw.githubusercontent.com/datasets/s-and-p-500-companies/master/data/constituents.csv"
NASDAQ100_URL = "https://raw.githubusercontent.com/mhyavas/SP500-NASDAQ100/main/nasdaq100.csv"
FALLBACK_JSON = ROOT / "data" / "ticker_universe.json"

DOW_30: list[tuple[str, str]] = [
    ("AAPL", "Apple Inc."),
    ("AMGN", "Amgen Inc."),
    ("AMZN", "Amazon.com Inc."),
    ("AXP", "American Express Co."),
    ("BA", "Boeing Co."),
    ("CAT", "Caterpillar Inc."),
    ("CRM", "Salesforce Inc."),
    ("CSCO", "Cisco Systems Inc."),
    ("CVX", "Chevron Corp."),
    ("DIS", "Walt Disney Co."),
    ("GS", "Goldman Sachs Group Inc."),
    ("HD", "Home Depot Inc."),
    ("HON", "Honeywell International Inc."),
    ("IBM", "International Business Machines Corp."),
    ("JNJ", "Johnson & Johnson"),
    ("JPM", "JPMorgan Chase & Co."),
    ("KO", "Coca-Cola Co."),
    ("MCD", "McDonald's Corp."),
    ("MMM", "3M Co."),
    ("MRK", "Merck & Co. Inc."),
    ("MSFT", "Microsoft Corp."),
    ("NKE", "Nike Inc."),
    ("NVDA", "Nvidia Corp."),
    ("PG", "Procter & Gamble Co."),
    ("SHW", "Sherwin-Williams Co."),
    ("TRV", "Travelers Cos. Inc."),
    ("UNH", "UnitedHealth Group Inc."),
    ("V", "Visa Inc."),
    ("VZ", "Verizon Communications Inc."),
    ("WMT", "Walmart Inc."),
]


@dataclass
class SeedTicker:
    symbol: str
    name: str
    exchange: str | None = None
    index_tag: str | None = None


async def _fetch_csv(url: str) -> str:
    async with httpx.AsyncClient(timeout=30.0) as client:
        resp = await client.get(url)
        resp.raise_for_status()
        return resp.text


def _parse_sp500(csv_text: str) -> list[SeedTicker]:
    rows: list[SeedTicker] = []
    reader = csv.DictReader(io.StringIO(csv_text))
    for row in reader:
        symbol = (row.get("Symbol") or "").strip().upper()
        name = (row.get("Security") or row.get("Name") or "").strip()
        if symbol and name:
            rows.append(SeedTicker(symbol=symbol, name=name, index_tag="SP500"))
    return rows


def _parse_nasdaq100(csv_text: str) -> list[SeedTicker]:
    rows: list[SeedTicker] = []
    reader = csv.DictReader(io.StringIO(csv_text))
    for row in reader:
        symbol = (row.get("Symbol") or "").strip().upper()
        name = (row.get("Description") or row.get("Name") or "").strip()
        if symbol and name:
            rows.append(SeedTicker(symbol=symbol, name=name, exchange="NASDAQ", index_tag="NDX100"))
    return rows


def _load_fallback_json() -> list[SeedTicker]:
    if not FALLBACK_JSON.exists():
        return []
    import json

    payload = json.loads(FALLBACK_JSON.read_text(encoding="utf-8"))
    rows: list[SeedTicker] = []
    for item in payload:
        symbol = str(item.get("symbol", "")).strip().upper()
        name = str(item.get("name", "")).strip()
        if not symbol or not name:
            continue
        rows.append(
            SeedTicker(
                symbol=symbol,
                name=name,
                exchange=item.get("exchange"),
                index_tag=item.get("index_tag"),
            )
        )
    return rows


async def load_seed_tickers() -> list[SeedTicker]:
    by_symbol: dict[str, SeedTicker] = {}

    def merge(items: list[SeedTicker]) -> None:
        for item in items:
            existing = by_symbol.get(item.symbol)
            if existing is None:
                by_symbol[item.symbol] = item
                continue
            if not existing.name and item.name:
                existing.name = item.name
            if not existing.exchange and item.exchange:
                existing.exchange = item.exchange
            if existing.index_tag and item.index_tag and existing.index_tag != item.index_tag:
                existing.index_tag = f"{existing.index_tag},{item.index_tag}"
            elif not existing.index_tag and item.index_tag:
                existing.index_tag = item.index_tag

    merge([SeedTicker(symbol=s, name=n, exchange="NYSE", index_tag="DJIA") for s, n in DOW_30])

    try:
        sp500_csv = await _fetch_csv(SP500_URL)
        merge(_parse_sp500(sp500_csv))
    except Exception as exc:
        print(f"Warning: could not fetch S&P 500 list ({exc}); using fallback if available.")

    try:
        ndx_csv = await _fetch_csv(NASDAQ100_URL)
        merge(_parse_nasdaq100(ndx_csv))
    except Exception as exc:
        print(f"Warning: could not fetch NASDAQ-100 list ({exc}); using fallback if available.")

    if len(by_symbol) <= len(DOW_30):
        merge(_load_fallback_json())

    return sorted(by_symbol.values(), key=lambda t: t.symbol)


async def upsert_tickers(tickers: list[SeedTicker]) -> int:
    await init_db()
    async with SessionLocal() as session:
        for batch_start in range(0, len(tickers), 200):
            batch = tickers[batch_start : batch_start + 200]
            for item in batch:
                await session.execute(
                    pg_insert(Ticker)
                    .values(
                        symbol=item.symbol,
                        name=item.name,
                        exchange=item.exchange,
                        index_tag=item.index_tag,
                        active=True,
                    )
                    .on_conflict_do_update(
                        index_elements=["symbol"],
                        set_={
                            "name": item.name,
                            "exchange": item.exchange,
                            "index_tag": item.index_tag,
                            "active": True,
                        },
                    )
                )
            await session.commit()
    return len(tickers)


async def main() -> None:
    tickers = await load_seed_tickers()
    if not tickers:
        raise SystemExit("No tickers loaded. Check network access or add data/ticker_universe.json.")
    count = await upsert_tickers(tickers)
    print(f"Seeded {count} tickers into Postgres.")


if __name__ == "__main__":
    asyncio.run(main())

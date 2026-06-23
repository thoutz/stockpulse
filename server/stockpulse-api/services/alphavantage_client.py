from __future__ import annotations

import asyncio
import csv
import io
import logging
from datetime import datetime, timedelta, timezone
from typing import Any

import httpx

from config import get_settings

logger = logging.getLogger(__name__)

BASE_URL = "https://www.alphavantage.co/query"

# Priority symbols for daily OVERVIEW calls (catalyst + core watchlist)
OVERVIEW_PRIORITY = ["NVDA", "RKLB", "AMD", "AVGO", "TSLA"]


class AlphaVantageClient:
    """Alpha Vantage — free tier 25 requests/day, 5/min."""

    def __init__(self) -> None:
        self.settings = get_settings()

    @property
    def configured(self) -> bool:
        return bool(self.settings.alphavantage_api_key.strip())

    async def _get(self, params: dict[str, str]) -> dict[str, Any] | str | None:
        if not self.configured:
            return None
        params = {**params, "apikey": self.settings.alphavantage_api_key}
        try:
            async with httpx.AsyncClient(timeout=60.0) as client:
                resp = await client.get(BASE_URL, params=params)
                resp.raise_for_status()
                text = resp.text.strip()
                if text.startswith("{"):
                    data = resp.json()
                    if "Note" in data or "Information" in data:
                        msg = data.get("Note") or data.get("Information")
                        logger.warning("Alpha Vantage limit: %s", msg)
                        return None
                    return data
                return text
        except Exception:
            logger.exception("Alpha Vantage request failed: %s", params.get("function"))
            return None

    async def fetch_company_news(self, symbol: str, limit: int = 20) -> list[dict[str, Any]]:
        data = await self._get(
            {
                "function": "NEWS_SENTIMENT",
                "tickers": symbol.upper(),
                "sort": "LATEST",
                "limit": str(min(limit, 50)),
            }
        )
        if not isinstance(data, dict):
            return []

        feed = data.get("feed") or []
        if not isinstance(feed, list):
            return []

        cutoff = datetime.now(timezone.utc) - timedelta(days=7)
        out: list[dict[str, Any]] = []
        for item in feed:
            title = (item.get("title") or "").strip()
            if not title:
                continue
            time_published = item.get("time_published") or ""
            published = _parse_av_time(time_published)
            if published < cutoff:
                continue
            url = item.get("url") or f"alphavantage:{symbol}:{time_published}"
            summary = (item.get("summary") or "")[:2000] or None
            source = item.get("source")
            sentiment_score: float | None = None
            for ts in item.get("ticker_sentiment") or []:
                if (ts.get("ticker") or "").upper() == symbol.upper():
                    raw = ts.get("ticker_sentiment_score")
                    if raw is not None:
                        sentiment_score = float(raw)
                    break

            out.append(
                {
                    "symbol": symbol.upper(),
                    "headline": title[:512],
                    "summary": summary,
                    "source": source,
                    "url": url[:1024],
                    "published_at": published,
                    "sentiment_score": sentiment_score,
                }
            )
        return out

    async def fetch_earnings_calendar(self, horizon: str = "3month") -> list[dict[str, str]]:
        raw = await self._get({"function": "EARNINGS_CALENDAR", "horizon": horizon})
        if not isinstance(raw, str) or not raw.strip():
            return []
        reader = csv.DictReader(io.StringIO(raw))
        rows: list[dict[str, str]] = []
        for row in reader:
            sym = (row.get("symbol") or "").strip().upper()
            if not sym:
                continue
            rows.append(
                {
                    "symbol": sym,
                    "name": (row.get("name") or "")[:80],
                    "report_date": (row.get("reportDate") or "").strip(),
                    "estimate": (row.get("estimate") or "").strip(),
                    "time_of_day": (row.get("timeOfTheDay") or "").strip(),
                }
            )
        return rows

    async def fetch_top_gainers_losers(self) -> dict[str, list[dict[str, str]]]:
        data = await self._get({"function": "TOP_GAINERS_LOSERS"})
        if not isinstance(data, dict):
            return {}
        out: dict[str, list[dict[str, str]]] = {}
        for key in ("top_gainers", "top_losers", "most_actively_traded"):
            items = data.get(key) or []
            if isinstance(items, list):
                out[key] = [
                    {
                        "ticker": str(i.get("ticker", "")),
                        "change_percentage": str(i.get("change_percentage", "")),
                        "price": str(i.get("price", "")),
                        "volume": str(i.get("volume", "")),
                    }
                    for i in items[:5]
                ]
        out["last_updated"] = str(data.get("last_updated") or "")
        return out

    async def fetch_company_overview(self, symbol: str) -> dict[str, str] | None:
        data = await self._get({"function": "OVERVIEW", "symbol": symbol.upper()})
        if not isinstance(data, dict) or not data.get("Symbol"):
            return None

        def _f(key: str) -> str:
            v = data.get(key)
            return str(v).strip() if v not in (None, "None", "-") else ""

        return {
            "symbol": symbol.upper(),
            "name": _f("Name")[:60],
            "sector": _f("Sector"),
            "industry": _f("Industry")[:40],
            "pe_ratio": _f("PERatio"),
            "eps": _f("EPS"),
            "market_cap": _f("MarketCapitalization"),
            "dividend_yield": _f("DividendYield"),
            "week52_high": _f("52WeekHigh"),
            "week52_low": _f("52WeekLow"),
            "beta": _f("Beta"),
            "analyst_target": _f("AnalystTargetPrice"),
        }

    async def fetch_daily_bundle_parts(
        self, tracked_symbols: set[str], overview_symbols: list[str]
    ) -> tuple[list[dict], dict, list[dict]]:
        """Sequential fetches with 13s pause for 5/min rate limit. Returns earnings, breadth, overviews."""
        earnings = await self.fetch_earnings_calendar()
        await asyncio.sleep(13)
        breadth_raw = await self.fetch_top_gainers_losers()
        overviews: list[dict] = []
        for sym in overview_symbols[:4]:
            ov = await self.fetch_company_overview(sym)
            if ov:
                overviews.append(ov)
            await asyncio.sleep(13)
        return earnings, breadth_raw, overviews


def _parse_av_time(raw: str) -> datetime:
    raw = raw.strip()
    if len(raw) >= 15:
        try:
            return datetime.strptime(raw[:15], "%Y%m%dT%H%M%S").replace(tzinfo=timezone.utc)
        except ValueError:
            pass
    return datetime.now(timezone.utc)


def format_earnings_summary(rows: list[dict[str, str]], symbols: set[str], days_ahead: int = 30) -> str:
    today = datetime.now(timezone.utc).date()
    cutoff = today + timedelta(days=days_ahead)
    lines: list[str] = []
    for row in sorted(rows, key=lambda r: r.get("report_date") or ""):
        sym = row.get("symbol") or ""
        if sym not in symbols:
            continue
        rd = row.get("report_date") or ""
        try:
            d = datetime.strptime(rd, "%Y-%m-%d").date()
        except ValueError:
            continue
        if d < today or d > cutoff:
            continue
        est = row.get("estimate") or "—"
        tod = row.get("time_of_day") or ""
        extra = f" ({tod})" if tod else ""
        lines.append(f"{sym} reports {rd}, est EPS {est}{extra}")
    return "\n".join(lines) if lines else "No upcoming earnings in the next 30 days for tracked tickers."


def format_breadth_summary(breadth: dict) -> str:
    if not breadth:
        return "Market breadth unavailable."
    lines: list[str] = []
    if lu := breadth.get("last_updated"):
        lines.append(f"Last updated: {lu}")
    for label, key in (("Top gainers", "top_gainers"), ("Top losers", "top_losers"), ("Most active", "most_actively_traded")):
        items = breadth.get(key) or []
        if not isinstance(items, list):
            continue
        parts = [
            f"{i.get('ticker')} {i.get('change_percentage')}"
            for i in items[:3]
            if isinstance(i, dict) and i.get("ticker")
        ]
        if parts:
            lines.append(f"{label}: " + ", ".join(parts))
    return "\n".join(lines) if lines else "Market breadth unavailable."


def format_overview_summary(overviews: list[dict]) -> str:
    lines: list[str] = []
    for o in overviews:
        sym = o.get("symbol") or "?"
        pe = o.get("pe_ratio") or "—"
        eps = o.get("eps") or "—"
        sector = o.get("sector") or "—"
        hi = o.get("week52_high") or "—"
        lo = o.get("week52_low") or "—"
        beta = o.get("beta") or "—"
        target = o.get("analyst_target") or "—"
        lines.append(
            f"{sym}: P/E {pe}, EPS {eps}, {sector}, 52wk ${lo}–${hi}, beta {beta}, analyst target ${target}"
        )
    return "\n".join(lines) if lines else "No fundamental overviews fetched."


def pick_overview_symbols(tracked: list[str], session_date: str) -> list[str]:
    """Catalyst priority + daily rotation through watchlist."""
    seen: set[str] = set()
    ordered: list[str] = []
    for sym in OVERVIEW_PRIORITY:
        if sym in tracked or sym.upper() in {t.upper() for t in tracked}:
            s = sym.upper()
            if s not in seen:
                seen.add(s)
                ordered.append(s)
    rest = [t.upper() for t in tracked if t.upper() not in seen]
    if rest:
        day_idx = int(session_date.replace("-", "")) % len(rest)
        for i in range(min(2, len(rest))):
            sym = rest[(day_idx + i) % len(rest)]
            if sym not in seen:
                seen.add(sym)
                ordered.append(sym)
    return ordered[:4]

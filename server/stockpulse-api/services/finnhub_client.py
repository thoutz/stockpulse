from __future__ import annotations

import logging
from datetime import datetime, timedelta, timezone
from typing import Any

import httpx

from config import get_settings

logger = logging.getLogger(__name__)


class FinnhubClient:
    def __init__(self) -> None:
        self.settings = get_settings()
        self.base = "https://finnhub.io/api/v1"

    @property
    def configured(self) -> bool:
        return bool(self.settings.finnhub_api_key.strip())

    def _token_params(self, extra: dict[str, Any] | None = None) -> dict[str, Any]:
        p: dict[str, Any] = {"token": self.settings.finnhub_api_key}
        if extra:
            p.update(extra)
        return p

    async def fetch_quote(self, symbol: str) -> dict[str, Any] | None:
        if not self.configured:
            return None
        url = f"{self.base}/quote"
        try:
            async with httpx.AsyncClient(timeout=15.0) as client:
                resp = await client.get(url, params=self._token_params({"symbol": symbol.upper()}))
                if resp.status_code == 429:
                    logger.warning("Finnhub rate limit on quote for %s", symbol)
                    return None
                resp.raise_for_status()
                data = resp.json()
                if not isinstance(data, dict) or data.get("c") in (None, 0):
                    return None
                return data
        except Exception:
            logger.exception("Finnhub quote failed for %s", symbol)
            return None

    async def search_symbols(self, query: str, limit: int = 15) -> list[dict[str, str]]:
        if not self.configured:
            return []
        url = f"{self.base}/search"
        try:
            async with httpx.AsyncClient(timeout=15.0) as client:
                resp = await client.get(
                    url, params=self._token_params({"q": query.strip()}),
                )
                if resp.status_code == 429:
                    logger.warning("Finnhub rate limit on search")
                    return []
                resp.raise_for_status()
                data = resp.json()
                results = data.get("result") or []
                out: list[dict[str, str]] = []
                for r in results:
                    sym = (r.get("symbol") or "").upper()
                    if not sym:
                        continue
                    if r.get("type") and "Stock" not in str(r.get("type")):
                        continue
                    out.append({"symbol": sym, "name": r.get("description") or ""})
                    if len(out) >= limit:
                        break
                return out
        except Exception:
            logger.exception("Finnhub search failed")
            return []

    async def fetch_profile(self, symbol: str) -> dict[str, str] | None:
        if not self.configured:
            return None
        url = f"{self.base}/stock/profile2"
        try:
            async with httpx.AsyncClient(timeout=15.0) as client:
                resp = await client.get(url, params=self._token_params({"symbol": symbol.upper()}))
                if resp.status_code == 429:
                    logger.warning("Finnhub rate limit on profile for %s", symbol)
                    return None
                if resp.status_code == 404:
                    return None
                resp.raise_for_status()
                data = resp.json()
                if not isinstance(data, dict) or not data.get("name"):
                    return None
                return {
                    "name": data["name"],
                    "exchange": data.get("exchange") or "",
                }
        except Exception:
            logger.exception("Finnhub profile failed for %s", symbol)
            return None

    async def fetch_company_news(self, symbol: str, days: int = 7) -> list[dict[str, Any]]:
        if not self.configured:
            return []

        to_dt = datetime.now(timezone.utc)
        from_dt = to_dt - timedelta(days=days)
        params = self._token_params(
            {
                "symbol": symbol.upper(),
                "from": from_dt.strftime("%Y-%m-%d"),
                "to": to_dt.strftime("%Y-%m-%d"),
            }
        )
        url = f"{self.base}/company-news"
        try:
            async with httpx.AsyncClient(timeout=30.0) as client:
                resp = await client.get(url, params=params)
                if resp.status_code == 429:
                    logger.warning("Finnhub rate limit for %s", symbol)
                    return []
                resp.raise_for_status()
                data = resp.json()
                if not isinstance(data, list):
                    return []
                out: list[dict[str, Any]] = []
                for item in data:
                    ts = item.get("datetime")
                    if ts is None:
                        continue
                    published = datetime.fromtimestamp(int(ts), tz=timezone.utc)
                    out.append(
                        {
                            "symbol": symbol.upper(),
                            "headline": (item.get("headline") or "")[:512],
                            "summary": (item.get("summary") or "")[:2000] or None,
                            "source": item.get("source"),
                            "url": item.get("url") or f"finnhub:{symbol}:{ts}",
                            "published_at": published,
                        }
                    )
                return out
        except Exception:
            logger.exception("Finnhub news fetch failed for %s", symbol)
            return []

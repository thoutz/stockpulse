from __future__ import annotations

from datetime import datetime, timedelta, timezone
from typing import Any

import httpx

from config import get_settings


class MassiveClient:
    def __init__(self) -> None:
        self.settings = get_settings()
        self.base = self.settings.massive_base_url.rstrip("/")
        self.api_key = self.settings.massive_api_key

    def _params(self, extra: dict[str, Any] | None = None) -> dict[str, Any]:
        p: dict[str, Any] = {"apiKey": self.api_key}
        if extra:
            p.update(extra)
        return p

    async def fetch_daily_bars(self, symbol: str, days: int = 90) -> list[dict[str, Any]]:
        to_dt = datetime.now(timezone.utc)
        from_dt = to_dt - timedelta(days=days)
        return await self.fetch_daily_bars_range(
            symbol, from_dt.strftime("%Y-%m-%d"), to_dt.strftime("%Y-%m-%d"), limit=days + 5
        )

    async def fetch_daily_bars_range(
        self, symbol: str, from_str: str, to_str: str, limit: int = 100
    ) -> list[dict[str, Any]]:
        url = f"{self.base}/v2/aggs/ticker/{symbol}/range/1/day/{from_str}/{to_str}"
        params = self._params({"adjusted": "true", "sort": "asc", "limit": limit})
        return await self._fetch_aggs(url, params, symbol)

    async def search_tickers(self, query: str, limit: int = 15) -> list[dict[str, str]]:
        """Symbol/name lookup via the Polygon-compatible reference endpoint."""
        url = f"{self.base}/v3/reference/tickers"
        params = self._params(
            {"search": query, "active": "true", "market": "stocks", "limit": limit}
        )
        async with httpx.AsyncClient(timeout=30.0) as client:
            resp = await client.get(url, params=params)
            if resp.status_code == 429:
                raise RuntimeError("Massive rate limit (5 calls/min)")
            resp.raise_for_status()
            data = resp.json()
            if data.get("status") == "ERROR" or data.get("error"):
                raise RuntimeError(data.get("error") or "Massive search error")
            results = data.get("results") or []
            out: list[dict[str, str]] = []
            for r in results:
                symbol = r.get("ticker")
                if not symbol:
                    continue
                out.append({"symbol": symbol.upper(), "name": r.get("name") or ""})
            return out

    async def fetch_ticker_details(self, symbol: str) -> dict[str, str] | None:
        """Resolve a single symbol's company name + exchange via reference details.

        Returns None when the symbol is unknown (404) or has no name. Raises on
        transient errors (429/5xx/network) so the caller can retry later.
        """
        url = f"{self.base}/v3/reference/tickers/{symbol}"
        params = self._params()
        async with httpx.AsyncClient(timeout=30.0) as client:
            resp = await client.get(url, params=params)
            if resp.status_code == 429:
                raise RuntimeError("Massive rate limit (5 calls/min)")
            if resp.status_code == 404:
                return None
            resp.raise_for_status()
            data = resp.json()
            res = data.get("results") or {}
            name = res.get("name")
            if not name:
                return None
            return {"name": name, "exchange": res.get("primary_exchange") or ""}

    async def fetch_minute_bars(self, symbol: str, days: int = 5) -> list[dict[str, Any]]:
        to_dt = datetime.now(timezone.utc)
        from_dt = to_dt - timedelta(days=days)
        from_str = from_dt.strftime("%Y-%m-%d")
        to_str = to_dt.strftime("%Y-%m-%d")
        url = f"{self.base}/v2/aggs/ticker/{symbol}/range/1/minute/{from_str}/{to_str}"
        params = self._params({"adjusted": "true", "sort": "asc", "limit": 5000})
        return await self._fetch_aggs(url, params, symbol)

    async def fetch_rsi(self, symbol: str, limit: int = 30) -> list[dict[str, Any]]:
        url = f"{self.base}/v1/indicators/rsi/{symbol}"
        params = self._params({"timespan": "day", "adjusted": "true", "limit": limit, "order": "asc"})
        return await self._fetch_indicator(url, params)

    async def fetch_sma(self, symbol: str, window: int = 20, limit: int = 30) -> list[dict[str, Any]]:
        url = f"{self.base}/v1/indicators/sma/{symbol}"
        params = self._params(
            {"timespan": "day", "adjusted": "true", "window": window, "limit": limit, "order": "asc"}
        )
        return await self._fetch_indicator(url, params)

    async def _fetch_aggs(self, url: str, params: dict[str, Any], symbol: str) -> list[dict[str, Any]]:
        async with httpx.AsyncClient(timeout=60.0) as client:
            resp = await client.get(url, params=params)
            if resp.status_code == 429:
                raise RuntimeError("Massive rate limit (5 calls/min)")
            resp.raise_for_status()
            data = resp.json()
            if data.get("status") == "ERROR" or data.get("error"):
                raise RuntimeError(data.get("error") or f"Massive error for {symbol}")
            results = data.get("results") or []
            bars = []
            for bar in results:
                ts_ms = bar.get("t")
                if ts_ms is None:
                    continue
                bars.append(
                    {
                        "ts": datetime.fromtimestamp(ts_ms / 1000, tz=timezone.utc),
                        "open": float(bar["o"]),
                        "high": float(bar["h"]),
                        "low": float(bar["l"]),
                        "close": float(bar["c"]),
                        "volume": float(bar.get("v", 0)),
                    }
                )
            return bars

    async def _fetch_indicator(self, url: str, params: dict[str, Any]) -> list[dict[str, Any]]:
        async with httpx.AsyncClient(timeout=60.0) as client:
            resp = await client.get(url, params=params)
            if resp.status_code == 429:
                raise RuntimeError("Massive rate limit (5 calls/min)")
            resp.raise_for_status()
            data = resp.json()
            values = (data.get("results") or {}).get("values") or []
            out = []
            for v in values:
                ts = v.get("timestamp") or v.get("t")
                val = v.get("value")
                if ts is None or val is None:
                    continue
                if isinstance(ts, (int, float)):
                    dt = datetime.fromtimestamp(ts / 1000 if ts > 1e12 else ts, tz=timezone.utc)
                else:
                    dt = datetime.strptime(str(ts)[:10], "%Y-%m-%d").replace(tzinfo=timezone.utc)
                out.append({"ts": dt, "value": float(val)})
            return out

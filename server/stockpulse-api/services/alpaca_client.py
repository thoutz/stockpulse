"""Alpaca Trading API client (paper or live)."""

from __future__ import annotations

from functools import lru_cache

from alpaca.trading.client import TradingClient

from config import get_settings


def is_alpaca_configured() -> bool:
    s = get_settings()
    return bool(s.alpaca_api_key.strip() and s.alpaca_secret_key.strip())


@lru_cache
def get_trading_client() -> TradingClient:
    settings = get_settings()
    if not is_alpaca_configured():
        raise RuntimeError("Alpaca API keys not configured (ALPACA_API_KEY / ALPACA_SECRET_KEY)")
    return TradingClient(
        api_key=settings.alpaca_api_key.strip(),
        secret_key=settings.alpaca_secret_key.strip(),
        paper=settings.alpaca_paper,
    )


def clear_trading_client_cache() -> None:
    get_trading_client.cache_clear()

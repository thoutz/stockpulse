"""Runtime trading toggles (env defaults + optional in-memory override)."""

from __future__ import annotations

from config import get_settings

_runtime_auto_trade: bool | None = None


def is_auto_trade_enabled() -> bool:
    if _runtime_auto_trade is not None:
        return _runtime_auto_trade
    return get_settings().auto_trade_enabled


def set_auto_trade_enabled(enabled: bool) -> None:
    global _runtime_auto_trade
    _runtime_auto_trade = enabled

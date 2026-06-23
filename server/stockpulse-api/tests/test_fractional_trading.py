"""Tests for Alpaca fractional order rules."""

from __future__ import annotations

import pytest

from services.fractional_trading import (
    AssetEligibility,
    FractionalTradingError,
    normalize_notional,
    normalize_qty,
)


def test_normalize_notional_minimum():
    with pytest.raises(FractionalTradingError, match="minimum"):
        normalize_notional(0.5)
    assert normalize_notional(1.0) == 1.0
    assert normalize_notional(12.456) == 12.46


def test_normalize_qty():
    assert normalize_qty(0.000123456) == 0.000123456
    with pytest.raises(FractionalTradingError):
        normalize_qty(0)


def test_asset_eligibility_fractional_buy():
    ok = AssetEligibility("AMD", tradable=True, fractionable=True, status="active")
    assert ok.can_fractional_buy is True

    bad = AssetEligibility("XYZ", tradable=True, fractionable=False, status="active")
    assert bad.can_fractional_buy is False

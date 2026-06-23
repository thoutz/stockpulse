from unittest.mock import MagicMock

from services.analysis_packet import _format_user_favorites_section
from services.monitor_tiers import MonitorTier


def _snap(
    *,
    price: float = 100.0,
    change_1d: float = 1.0,
    change_30d: float = 5.0,
    change_5m: float | None = 0.3,
    change_15m: float | None = None,
    rsi: float | None = 55.0,
):
    s = MagicMock()
    s.price = price
    s.change_1d_pct = change_1d
    s.change_30d_pct = change_30d
    s.change_5m_pct = change_5m
    s.change_15m_pct = change_15m
    s.rsi = rsi
    return s


def test_format_user_favorites_section_empty():
    lines = _format_user_favorites_section(set(), snapshots={}, tier_map={})
    assert any("USER FAVORITES" in line for line in lines)
    assert any("None saved" in line for line in lines)


def test_format_user_favorites_section_with_snapshot():
    favorites = {"AAPL", "PLTR"}
    snapshots = {"AAPL": _snap(price=182.4, change_1d=1.2, change_5m=0.3)}
    tier_map = {"AAPL": MonitorTier.WARM, "PLTR": MonitorTier.WARM}
    lines = _format_user_favorites_section(
        favorites,
        snapshots=snapshots,
        tier_map=tier_map,
    )
    text = "\n".join(lines)
    assert "USER FAVORITES" in text
    assert "AAPL [warm]: $182.40" in text
    assert "PLTR [warm]: (no snapshot yet — data pending)" in text

from services.monitor_tiers import MonitorTier, resolve_tier


def test_resolve_tier_hot_when_in_focus_sector():
    tier = resolve_tier(
        "NVDA",
        focus_sector_id="semiconductors",
        favorites=set(),
        config_tickers={"RKLB"},
    )
    assert tier == MonitorTier.HOT


def test_resolve_tier_warm_when_favorite():
    tier = resolve_tier(
        "RKLB",
        focus_sector_id=None,
        favorites={"RKLB"},
        config_tickers={"RKLB"},
    )
    assert tier == MonitorTier.WARM


def test_resolve_tier_cold_for_config_only():
    tier = resolve_tier(
        "RKLB",
        focus_sector_id=None,
        favorites=set(),
        config_tickers={"RKLB"},
    )
    assert tier == MonitorTier.COLD

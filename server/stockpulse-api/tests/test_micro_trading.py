"""Unit tests for micro-trading scanner and exit rules."""

from types import SimpleNamespace

from services.micro_trading import (
    MicroScanResult,
    _entry_trigger,
    evaluate_all_micro_exits,
    evaluate_micro_exits,
    evaluate_momentum_flip_exits,
    is_daily_profit_cap_hit,
    micro_scan_to_intent,
)


def test_take_profit_exit():
    positions = [{"symbol": "NVDA", "qty": 0.5, "unrealized_plpc": 0.80}]
    signals = evaluate_micro_exits(positions)
    assert len(signals) == 1
    assert signals[0].signal_source == "micro_take_profit"
    assert signals[0].symbol == "NVDA"


def test_stop_loss_exit():
    positions = [{"symbol": "TSLA", "qty": 1.0, "unrealized_plpc": -0.55}]
    signals = evaluate_micro_exits(positions)
    assert len(signals) == 1
    assert signals[0].signal_source == "micro_stop_loss"


def test_momentum_flip_exit():
    positions = [{"symbol": "AMD", "qty": 1.0, "unrealized_plpc": 0.2}]
    snap = SimpleNamespace(change_5m_pct=-0.2)
    signals = evaluate_momentum_flip_exits(positions, {"AMD": snap})
    assert len(signals) == 1
    assert signals[0].signal_source == "micro_momentum_flip"


def test_tp_beats_momentum_flip():
    positions = [{"symbol": "AMD", "qty": 1.0, "unrealized_plpc": 0.9}]
    snap = SimpleNamespace(change_5m_pct=-0.2)
    signals = evaluate_all_micro_exits(positions, {"AMD": snap})
    assert len(signals) == 1
    assert signals[0].signal_source == "micro_take_profit"


def test_entry_trigger_watch():
    snap = SimpleNamespace(change_5m_pct=0.1, change_15m_pct=0.2, change_1d_pct=1.0, price=100.0)
    watch = SimpleNamespace(score=22.0, symbol="AMD")
    ok, tag, boost = _entry_trigger(
        "AMD",
        snap,
        watch_by_sym={"AMD": watch},
        intraday_movers=set(),
        favorites=set(),
    )
    assert ok is True
    assert "WATCH" in tag
    assert boost > 0


def test_entry_trigger_slow_grind():
    snap = SimpleNamespace(change_5m_pct=0.12, change_15m_pct=0.05, change_1d_pct=1.5, price=100.0)
    ok, tag, _ = _entry_trigger(
        "AMD",
        snap,
        watch_by_sym={},
        intraday_movers=set(),
        favorites=set(),
    )
    assert ok is True
    assert "slow grind" in tag


def test_daily_profit_cap():
    assert is_daily_profit_cap_hit(49.99) is False
    assert is_daily_profit_cap_hit(50.0) is True


def test_micro_scan_to_intent():
    scan = MicroScanResult(
        symbol="RKLB",
        score=42.0,
        change_5m_pct=0.6,
        change_15m_pct=0.3,
        rationale="test",
        entry_reason="5m momentum",
    )
    intent = micro_scan_to_intent(scan)
    assert intent.symbol == "RKLB"
    assert intent.action == "BUY"
    assert intent.signal_source == "micro_momentum"
    assert intent.notional_usd >= 1.0
    assert intent.confidence >= 0.75

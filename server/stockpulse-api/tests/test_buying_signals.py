from datetime import datetime, timezone
from unittest.mock import MagicMock

from services.buying_signals import (
    BuyingSignal,
    format_signals_for_packet,
    rank_buying_signals,
    score_candidate,
)
from services.monitor_tiers import MonitorTier
from services.ripple_engine import Bar


def _snap(change_1d: float = 0.0, rsi: float | None = None, change_5m: float | None = None):
    s = MagicMock()
    s.change_1d_pct = change_1d
    s.rsi = rsi
    s.change_5m_pct = change_5m
    return s


def test_confirmed_ripple_hot_tier_ranks_watch():
    bars = [
        Bar(date=datetime(2026, 5, 1, tzinfo=timezone.utc), close=100.0),
        Bar(date=datetime(2026, 6, 1, tzinfo=timezone.utc), close=105.0),
    ]
    sig = score_candidate(
        "AMD",
        slot="open",
        tier=MonitorTier.HOT,
        snap=_snap(change_1d=4.2, rsi=58),
        bars=bars,
        ripple_verdict="CONFIRMED",
        ripple_confidence=85.0,
        catalyst_ticker="NVDA",
        is_intraday_mover=True,
        sector_breadth_positive=True,
        suggestion_bias="bullish",
        held_morning_move=False,
        av_positive=False,
    )
    assert sig.stance == "WATCH"
    assert sig.score >= 15


def test_failed_ripple_overbought_ranks_avoid():
    sig = score_candidate(
        "ASTS",
        slot="open",
        tier=MonitorTier.WARM,
        snap=_snap(change_1d=-1.0, rsi=74),
        bars=[],
        ripple_verdict="FAILED",
        ripple_confidence=60.0,
        catalyst_ticker="RKLB",
        is_intraday_mover=False,
        sector_breadth_positive=False,
        suggestion_bias=None,
        held_morning_move=False,
        av_positive=False,
    )
    assert sig.stance == "AVOID"
    assert sig.score <= -10


def test_midday_confirmation_bonus():
    sig = score_candidate(
        "AMD",
        slot="midday",
        tier=MonitorTier.HOT,
        snap=_snap(change_1d=3.0, change_5m=0.5),
        bars=[],
        ripple_verdict="FORMING",
        ripple_confidence=70.0,
        catalyst_ticker="NVDA",
        is_intraday_mover=True,
        sector_breadth_positive=False,
        suggestion_bias=None,
        held_morning_move=True,
        av_positive=False,
    )
    assert "held morning move" in " ".join(sig.signals)
    assert sig.stance == "WATCH"


def test_rank_and_format_empty():
    watch, avoid = rank_buying_signals([])
    lines = format_signals_for_packet(watch, avoid)
    assert "No research signal" in lines[0]


def test_format_signals_with_candidates():
    watch = [
        BuyingSignal(symbol="AMD", score=72, stance="WATCH", signals=["FORMING ripple"], tier="HOT"),
    ]
    avoid = [
        BuyingSignal(symbol="ASTS", score=-22, stance="AVOID", signals=["FAILED ripple"], tier="WARM"),
    ]
    lines = format_signals_for_packet(watch, avoid)
    assert any("WATCH:" in ln for ln in lines)
    assert any("AMD" in ln for ln in lines)
    assert any("AVOID:" in ln for ln in lines)


def test_user_favorite_bonus_adds_score_and_tag():
    sig = score_candidate(
        "AAPL",
        slot="open",
        tier=MonitorTier.WARM,
        snap=_snap(change_1d=1.5, rsi=50),
        bars=[],
        ripple_verdict=None,
        ripple_confidence=None,
        catalyst_ticker=None,
        is_intraday_mover=False,
        sector_breadth_positive=False,
        suggestion_bias=None,
        held_morning_move=False,
        av_positive=False,
        is_user_favorite=True,
    )
    assert sig.score == 8.0
    assert "user favorite" in sig.signals


def test_user_favorite_bonus_can_push_to_watch():
    sig = score_candidate(
        "AAPL",
        slot="open",
        tier=MonitorTier.WARM,
        snap=_snap(change_1d=2.0, rsi=28),
        bars=[],
        ripple_verdict=None,
        ripple_confidence=None,
        catalyst_ticker=None,
        is_intraday_mover=True,
        sector_breadth_positive=False,
        suggestion_bias=None,
        held_morning_move=False,
        av_positive=False,
        is_user_favorite=True,
    )
    assert sig.stance == "WATCH"
    assert sig.score >= 15


def test_rank_reserves_watch_slot_for_favorite():
    signals = [
        BuyingSignal(symbol="NVDA", score=40, stance="WATCH", signals=["ripple"], tier="HOT"),
        BuyingSignal(symbol="AMD", score=35, stance="WATCH", signals=["ripple"], tier="HOT"),
        BuyingSignal(symbol="TSLA", score=30, stance="WATCH", signals=["ripple"], tier="HOT"),
        BuyingSignal(
            symbol="AAPL",
            score=12,
            stance="NEUTRAL",
            signals=["user favorite (WARM tier)", "1D +1.5%"],
            tier="warm",
        ),
    ]
    watch, _ = rank_buying_signals(signals, favorites={"AAPL"})
    symbols = [s.symbol for s in watch]
    assert "AAPL" in symbols
    assert len(watch) == 3


def test_rank_does_not_reserve_when_favorite_already_in_watch():
    signals = [
        BuyingSignal(symbol="AAPL", score=40, stance="WATCH", signals=["ripple"], tier="warm"),
        BuyingSignal(symbol="AMD", score=35, stance="WATCH", signals=["ripple"], tier="HOT"),
    ]
    watch, _ = rank_buying_signals(signals, favorites={"AAPL"})
    assert len(watch) == 2
    assert watch[0].symbol == "AAPL"

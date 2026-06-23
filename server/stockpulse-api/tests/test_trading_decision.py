from services.trading_decision import _score_to_confidence


def test_watch_threshold_meets_min_confidence():
    assert _score_to_confidence(15) == 0.75


def test_strong_watch_high_confidence():
    assert _score_to_confidence(35) >= 0.9


def test_weak_watch_still_passes_floor():
    assert _score_to_confidence(16) >= 0.75

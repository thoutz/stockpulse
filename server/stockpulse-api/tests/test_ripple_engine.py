from datetime import datetime, timezone

from services.ripple_engine import Bar, analyze_ripples, post_event_change, verdict


def test_verdict_confirmed():
    assert verdict(5.0, 3.0) == "CONFIRMED"


def test_verdict_forming():
    assert verdict(4.0, 1.0) == "FORMING"


def test_verdict_failed():
    assert verdict(5.0, -1.0) == "FAILED"


def test_verdict_watching():
    assert verdict(1.0, 1.0) == "WATCHING"


def test_post_event_change():
    bars = [
        Bar(date=datetime(2026, 5, 27, tzinfo=timezone.utc), close=100.0),
        Bar(date=datetime(2026, 5, 28, tzinfo=timezone.utc), close=100.0),
        Bar(date=datetime(2026, 6, 1, tzinfo=timezone.utc), close=110.0),
    ]
    event = datetime(2026, 5, 28, tzinfo=timezone.utc)
    assert post_event_change(bars, event) == 10.0


def test_analyze_ripples_with_custom_catalysts():
    histories = {
        "NVDA": [
            Bar(date=datetime(2026, 5, 27, tzinfo=timezone.utc), close=100.0),
            Bar(date=datetime(2026, 5, 28, tzinfo=timezone.utc), close=100.0),
            Bar(date=datetime(2026, 6, 1, tzinfo=timezone.utc), close=110.0),
        ],
        "AMD": [
            Bar(date=datetime(2026, 5, 27, tzinfo=timezone.utc), close=50.0),
            Bar(date=datetime(2026, 5, 28, tzinfo=timezone.utc), close=50.0),
            Bar(date=datetime(2026, 6, 1, tzinfo=timezone.utc), close=55.0),
        ],
    }
    catalysts = [
        {
            "ticker": "NVDA",
            "name": "NVIDIA",
            "event_name": "Test",
            "event_date": "2026-05-28",
            "ripples": [("AMD", "peer")],
        }
    ]
    results = analyze_ripples(histories, catalysts)
    assert "NVDA" in results
    assert results["NVDA"][0]["ripple_ticker"] == "AMD"
    assert results["NVDA"][0]["verdict"] == "CONFIRMED"

from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime, timezone


@dataclass
class Bar:
    date: datetime
    close: float


CATALYSTS = [
    {
        "ticker": "NVDA",
        "name": "NVIDIA",
        "event_name": "Q1 FY2026 Earnings Beat",
        "event_date": "2026-05-28",
        "ripples": [("AMD", "Chip sector peer"), ("AVGO", "AI networking")],
    },
    {
        "ticker": "RKLB",
        "name": "Rocket Lab",
        "event_name": "Q1 Earnings + Neutron Update",
        "event_date": "2026-05-14",
        "ripples": [
            ("ASTS", "Satellite connectivity play"),
            ("LUNR", "Lunar infrastructure"),
            ("HWM", "Aerospace components"),
            ("RDW", "Spacecraft components"),
        ],
    },
]


def _day(d: datetime) -> datetime:
    if d.tzinfo is None:
        d = d.replace(tzinfo=timezone.utc)
    return d.replace(hour=0, minute=0, second=0, microsecond=0)


def _parse_event_date(ymd: str) -> datetime:
    return datetime.strptime(ymd, "%Y-%m-%d").replace(tzinfo=timezone.utc)


def post_event_change(history: list[Bar], event_date: datetime) -> float:
    sorted_bars = sorted(history, key=lambda b: b.date)
    event_day = _day(event_date)
    idx = next((i for i, b in enumerate(sorted_bars) if _day(b.date) >= event_day), None)
    if idx is None or not sorted_bars:
        return 0.0
    event_price = sorted_bars[idx].close
    last = sorted_bars[-1].close
    if event_price <= 0:
        return 0.0
    return ((last - event_price) / event_price) * 100


def pre_event_change(history: list[Bar], event_date: datetime) -> float:
    sorted_bars = sorted(history, key=lambda b: b.date)
    if not sorted_bars:
        return 0.0
    event_day = _day(event_date)
    idx = next((i for i, b in enumerate(sorted_bars) if _day(b.date) >= event_day), None)
    if idx is None:
        return 0.0
    first = sorted_bars[0].close
    event_price = sorted_bars[idx].close
    if first <= 0:
        return 0.0
    return ((event_price - first) / first) * 100


def verdict(cat_post: float, rip_post: float) -> str:
    if cat_post > 3.0 and rip_post > 2.0:
        return "CONFIRMED"
    if cat_post > 3.0 and rip_post > 0.5:
        return "FORMING"
    if cat_post > 3.0 and rip_post <= 0:
        return "FAILED"
    return "WATCHING"


def analyze_ripples(
    histories: dict[str, list[Bar]],
    catalysts: list[dict] | None = None,
) -> dict[str, list[dict]]:
    cats = catalysts if catalysts is not None else CATALYSTS
    results: dict[str, list[dict]] = {}
    for cat in cats:
        cat_hist = histories.get(cat["ticker"], [])
        if not cat_hist:
            continue
        event_dt = _parse_event_date(cat["event_date"])
        cat_post = post_event_change(cat_hist, event_dt)
        rows = []
        for rip_ticker, desc in cat["ripples"]:
            rip_hist = histories.get(rip_ticker, [])
            if not rip_hist:
                continue
            rip_post = post_event_change(rip_hist, event_dt)
            v = verdict(cat_post, rip_post)
            rows.append(
                {
                    "catalyst_ticker": cat["ticker"],
                    "ripple_ticker": rip_ticker,
                    "description": desc,
                    "verdict": v,
                    "pre_event_pct": pre_event_change(rip_hist, event_dt),
                    "post_event_pct": rip_post,
                }
            )
        results[cat["ticker"]] = rows
    return results

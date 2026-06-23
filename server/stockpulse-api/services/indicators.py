"""Compute RSI and SMA from daily closes — no external API."""

from __future__ import annotations

from datetime import datetime, timezone


def compute_sma(closes: list[float], window: int) -> list[tuple[int, float]]:
    if len(closes) < window:
        return []
    out: list[tuple[int, float]] = []
    for i in range(window - 1, len(closes)):
        chunk = closes[i - window + 1 : i + 1]
        out.append((i, sum(chunk) / window))
    return out


def compute_rsi(closes: list[float], period: int = 14) -> list[tuple[int, float]]:
    if len(closes) <= period:
        return []
    gains: list[float] = []
    losses: list[float] = []
    for i in range(1, len(closes)):
        delta = closes[i] - closes[i - 1]
        gains.append(max(delta, 0.0))
        losses.append(max(-delta, 0.0))

    avg_gain = sum(gains[:period]) / period
    avg_loss = sum(losses[:period]) / period
    out: list[tuple[int, float]] = []

    def _rsi(ag: float, al: float) -> float:
        if al == 0:
            return 100.0
        rs = ag / al
        return 100.0 - (100.0 / (1.0 + rs))

    out.append((period, _rsi(avg_gain, avg_loss)))

    for i in range(period, len(gains)):
        avg_gain = (avg_gain * (period - 1) + gains[i]) / period
        avg_loss = (avg_loss * (period - 1) + losses[i]) / period
        out.append((i + 1, _rsi(avg_gain, avg_loss)))

    return out


def indicators_from_bars(
    bars: list[tuple[datetime, float]], *, rsi_limit: int = 30, sma_window: int = 20, sma_limit: int = 30
) -> tuple[list[tuple[datetime, float]], list[tuple[datetime, float]]]:
    """bars: (bar_date, close) ascending. Returns (rsi rows, sma rows)."""
    if not bars:
        return [], []
    dates = [b[0] for b in bars]
    closes = [b[1] for b in bars]

    rsi_rows: list[tuple[datetime, float]] = []
    for idx, val in compute_rsi(closes)[-rsi_limit:]:
        rsi_rows.append((dates[idx], val))

    sma_rows: list[tuple[datetime, float]] = []
    for idx, val in compute_sma(closes, sma_window)[-sma_limit:]:
        sma_rows.append((dates[idx], val))

    return rsi_rows, sma_rows

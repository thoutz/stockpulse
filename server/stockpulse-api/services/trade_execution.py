"""Shared helpers for logging trade outcomes."""

from __future__ import annotations

from models.db_models import TradeDecisionLog


def append_rejection_reason(row: TradeDecisionLog, reason: str) -> None:
    row.status = "rejected"
    prefix = f"REJECTED: {reason.strip()}"
    if row.rationale and prefix not in row.rationale:
        row.rationale = f"{row.rationale} | {prefix}"
    else:
        row.rationale = prefix or row.rationale


def append_failure_reason(row: TradeDecisionLog, reason: str) -> None:
    row.status = "failed"
    prefix = f"FAILED: {reason.strip()}"
    if row.rationale and prefix not in row.rationale:
        row.rationale = f"{row.rationale} | {prefix}"
    else:
        row.rationale = prefix or row.rationale

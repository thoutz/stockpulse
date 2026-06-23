from __future__ import annotations

import re
from datetime import datetime

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from models.db_models import AIReport
from services.analysis_packet import build_pulse_analysis_packet
from services.groq_budget import can_spend_tokens
from services.groq_client import chat_completion

PULSE_USER_PROMPT = """Write a StockPulse market pulse report using EXACTLY this structure:

TITLE: <one short headline about the NEWEST development only — not a generic recap>

## What's New
- 2-4 bullet points covering ONLY changes since the last report
- New alerts, verdict changes, RSI crossings, direction reversals, or tickers entering/leaving top movers
- Include USER FAVORITES when they have material session activity (see analysis packet), even if not in the bundled config watchlist
- Do NOT restate unchanged daily % moves (if AMD was +4% last report and is still ~+4%, omit it)

## Context
- 0-2 bullets of stable background ONLY if needed; may reference USER FAVORITES when relevant
- Omit this entire section if What's New stands alone

## Research Watchlist
- 0-3 bullets for WATCH candidates from RESEARCH SIGNALS (omit section if none)
- 0-1 bullet for AVOID candidates if score ≤ -10
- Each bullet: ticker, stance (WATCH/AVOID), 1-sentence rationale citing signal tags + confidence %
- End section with: "(Research context — not financial advice.)"
- Do NOT recommend tickers absent from RESEARCH SIGNALS

Rules:
- Lead with novelty. What's New is read first — put the freshest insight there.
- Never open with the same ticker and % as the previous report unless the move changed materially (>0.5 percentage points).
- Always write percentage moves with an explicit sign: +4.2% for gains, -4.2% for losses.
- Never pair loss language with an unsigned positive number (bad: "drops 4%"; good: "drops -4%" or "-4%").
- The previous report is for deduplication only — do not summarize or repeat it verbatim."""

SESSION_PROMPTS: dict[str, str] = {
    "open": (
        "SESSION: Market Open (10:00 AM ET — 30 minutes after the 9:30 AM open). "
        "Review opening gaps, first-hour movers, early ripple signals, and overnight news. "
        "Include user favorites with notable session activity in What's New. "
        "Research Watchlist: prioritize FORMING ripples and opening-gap + sector-breadth alignment."
    ),
    "midday": (
        "SESSION: Midday (1:00 PM ET). "
        "Compare the morning session to the open — what confirmed, faded, or reversed. "
        "Include user favorites with notable session activity in What's New. "
        "Research Watchlist: emphasize confirmation vs fade for open WATCH candidates."
    ),
    "close": (
        "SESSION: Market Close (4:00 PM ET — end of regular session). "
        "Synthesize Massive intraday stats with the Alpha Vantage daily bundle (earnings, breadth, "
        "fundamentals, news sentiment). Summarize how the full day resolved vs morning/midday themes. "
        "Include user favorites with notable session activity in What's New. "
        "Research Watchlist: prioritize CONFIRMED ripples, EOD resolution, AV fundamentals."
    ),
}


def parse_pulse_response(body: str) -> tuple[str, str]:
    text = body.strip()
    title = "Market Pulse"
    content = text

    title_match = re.match(r"^TITLE:\s*(.+?)(?:\n|$)", text, re.IGNORECASE)
    if title_match:
        title = title_match.group(1).strip()[:256] or title
        content = text[title_match.end() :].strip()
    elif "\n" in text:
        first, rest = text.split("\n", 1)
        if len(first) < 80 and not first.startswith("#"):
            title = first.strip()[:256]
            content = rest.strip()

    return title, content


async def generate_pulse_report(session: AsyncSession, session_slot: str = "open") -> tuple[str, str]:
    if not can_spend_tokens(4500):
        raise RuntimeError("Groq daily token budget exhausted")

    last = (
        await session.execute(
            select(AIReport)
            .where(AIReport.report_type.like("pulse%"))
            .order_by(AIReport.created_at.desc())
            .limit(1)
        )
    ).scalar_one_or_none()

    since = last.created_at if last else None
    context = await build_pulse_analysis_packet(session, session_slot=session_slot, since=since)

    session_note = SESSION_PROMPTS.get(session_slot, SESSION_PROMPTS["open"])
    user_parts = [PULSE_USER_PROMPT, f"\n{session_note}"]
    if last:
        user_parts.append(
            "\n=== PREVIOUS PULSE REPORT (dedupe only) ===\n"
            f"Title: {last.title}\n{last.body[:1200]}"
        )

    body = await chat_completion(context, "\n".join(user_parts), max_tokens=950)
    return parse_pulse_response(body)

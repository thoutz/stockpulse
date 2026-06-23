from __future__ import annotations

from datetime import datetime, timezone
from zoneinfo import ZoneInfo

from config import get_settings

ET = ZoneInfo("America/New_York")

_tokens_used_today: int = 0
_tokens_day_key: str = ""
_chat_count_today: int = 0
_chat_day_key: str = ""


def _et_day_key() -> str:
    return datetime.now(ET).strftime("%Y-%m-%d")


def _reset_if_new_day() -> None:
    global _tokens_used_today, _tokens_day_key, _chat_count_today, _chat_day_key
    key = _et_day_key()
    if _tokens_day_key != key:
        _tokens_day_key = key
        _tokens_used_today = 0
    if _chat_day_key != key:
        _chat_day_key = key
        _chat_count_today = 0


def record_token_usage(input_tokens: int, output_tokens: int) -> None:
    _reset_if_new_day()
    global _tokens_used_today
    _tokens_used_today += input_tokens + output_tokens


def tokens_used_today() -> int:
    _reset_if_new_day()
    return _tokens_used_today


def tokens_remaining() -> int:
    settings = get_settings()
    _reset_if_new_day()
    return max(0, settings.groq_daily_token_budget - _tokens_used_today)


def can_spend_tokens(estimated: int = 4000) -> bool:
    _reset_if_new_day()
    return _tokens_used_today + estimated <= get_settings().groq_daily_token_budget


def chat_questions_used_today() -> int:
    _reset_if_new_day()
    return _chat_count_today


def chat_questions_remaining() -> int:
    settings = get_settings()
    _reset_if_new_day()
    return max(0, settings.groq_chat_daily_limit - _chat_count_today)


def reserve_chat_question() -> bool:
    """Returns True if a chat slot was reserved, False if daily limit reached."""
    global _chat_count_today
    _reset_if_new_day()
    settings = get_settings()
    if _chat_count_today >= settings.groq_chat_daily_limit:
        return False
    _chat_count_today += 1
    return True


def usage_summary() -> dict[str, int | str]:
    settings = get_settings()
    _reset_if_new_day()
    return {
        "day": _et_day_key(),
        "tokens_used": _tokens_used_today,
        "tokens_budget": settings.groq_daily_token_budget,
        "tokens_remaining": tokens_remaining(),
        "chat_used": _chat_count_today,
        "chat_limit": settings.groq_chat_daily_limit,
        "chat_remaining": chat_questions_remaining(),
    }

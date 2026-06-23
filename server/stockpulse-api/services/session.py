from __future__ import annotations

import uuid

from fastapi import Cookie

SESSION_COOKIE = "sp_session"


def get_or_create_session_id(sp_session: str | None = Cookie(default=None, alias=SESSION_COOKIE)) -> str:
    if sp_session and len(sp_session) >= 8:
        return sp_session
    return str(uuid.uuid4())

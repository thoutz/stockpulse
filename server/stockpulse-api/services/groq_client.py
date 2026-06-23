from __future__ import annotations

import asyncio
import logging

import httpx

from config import get_settings
from services.groq_budget import record_token_usage

logger = logging.getLogger(__name__)

_groq_lock = asyncio.Lock()


def _is_tpd_limit(body_text: str) -> bool:
    return "tokens per day" in body_text.lower() or "tpd" in body_text.lower()


async def chat_completion(system: str, user: str, max_tokens: int = 1200) -> str:
    settings = get_settings()
    if not settings.groq_api_key:
        raise RuntimeError("GROQ_API_KEY not configured")

    body = {
        "model": settings.groq_model,
        "messages": [
            {"role": "system", "content": system},
            {"role": "user", "content": user},
        ],
        "max_tokens": max_tokens,
        "temperature": 0.4,
    }
    headers = {
        "Authorization": f"Bearer {settings.groq_api_key}",
        "Content-Type": "application/json",
    }

    async with _groq_lock:
        last_error: Exception | None = None
        for attempt in range(5):
            try:
                async with httpx.AsyncClient(timeout=120.0) as client:
                    resp = await client.post(
                        "https://api.groq.com/openai/v1/chat/completions",
                        headers=headers,
                        json=body,
                    )
                    resp_text = resp.text
                    if resp.status_code == 429:
                        if _is_tpd_limit(resp_text):
                            logger.error("Groq daily token limit reached — not retrying")
                            raise RuntimeError(
                                "Groq daily token limit reached. Pulse reports resume tomorrow."
                            )
                        wait = 20 * (attempt + 1)
                        logger.warning("Groq rate limit, retry in %ss (attempt %s)", wait, attempt + 1)
                        await asyncio.sleep(wait)
                        continue
                    resp.raise_for_status()
                    data = resp.json()
                    usage = data.get("usage") or {}
                    record_token_usage(
                        int(usage.get("prompt_tokens") or 0),
                        int(usage.get("completion_tokens") or 0),
                    )
                    return data["choices"][0]["message"]["content"]
            except httpx.HTTPStatusError as exc:
                last_error = exc
                resp_text = exc.response.text
                if exc.response.status_code == 429:
                    if _is_tpd_limit(resp_text):
                        raise RuntimeError(
                            "Groq daily token limit reached. Pulse reports resume tomorrow."
                        ) from exc
                    wait = 20 * (attempt + 1)
                    logger.warning("Groq rate limit, retry in %ss (attempt %s)", wait, attempt + 1)
                    await asyncio.sleep(wait)
                    continue
                raise
            except RuntimeError:
                raise
            except Exception as exc:
                last_error = exc
                raise

        raise RuntimeError("Groq rate limit exceeded after retries") from last_error

"""In-memory API request counters for the admin dashboard."""

from __future__ import annotations

import threading
from collections import defaultdict, deque
from datetime import datetime, timedelta, timezone

_lock = threading.Lock()
_started_at = datetime.now(timezone.utc)
_total_requests = 0
_recent: deque[tuple[datetime, str, str]] = deque(maxlen=5000)
_by_path: dict[str, int] = defaultdict(int)
_by_method: dict[str, int] = defaultdict(int)


def record_request(method: str, path: str) -> None:
    now = datetime.now(timezone.utc)
    with _lock:
        global _total_requests
        _total_requests += 1
        _recent.append((now, method.upper(), path))
        _by_path[path] += 1
        _by_method[method.upper()] += 1


def build_request_metrics() -> dict:
    now = datetime.now(timezone.utc)
    hour_ago = now - timedelta(hours=1)
    with _lock:
        recent_hour = [(ts, method, path) for ts, method, path in _recent if ts >= hour_ago]
        top_paths = sorted(_by_path.items(), key=lambda x: x[1], reverse=True)[:15]
        by_method = dict(_by_method)
        total = _total_requests
        started_at = _started_at.isoformat()

    hour_by_path: dict[str, int] = defaultdict(int)
    for _, _, path in recent_hour:
        hour_by_path[path] += 1

    return {
        "started_at": started_at,
        "total_requests": total,
        "requests_last_hour": len(recent_hour),
        "by_method": by_method,
        "top_paths_all_time": [{"path": p, "count": c} for p, c in top_paths],
        "top_paths_last_hour": [
            {"path": p, "count": c}
            for p, c in sorted(hour_by_path.items(), key=lambda x: x[1], reverse=True)[:15]
        ],
    }

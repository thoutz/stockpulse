from __future__ import annotations

from services.analysis_packet import build_chat_context, build_pulse_analysis_packet

# Backward-compatible aliases
build_ai_context = build_chat_context

__all__ = ["build_ai_context", "build_chat_context", "build_pulse_analysis_packet"]

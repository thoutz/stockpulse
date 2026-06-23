# AI Daily Prompt Chips

**Date:** 2026-06-20

## Summary

Replaced hardcoded Ask AI suggestion chips with **4 centered prompts** that rotate daily based on live market data (iOS + web).

## Server

**New:** [`server/stockpulse-api/services/chat_prompts.py`](../server/stockpulse-api/services/chat_prompts.py)

- Builds candidate prompts from snapshots (top 1D movers), ripple CONFIRMED/FORMING verdicts, today's alerts, recent `AISuggestion` rows, and static fallbacks
- Deterministic daily selection via SHA-256 shuffle keyed on ET calendar date
- Always returns exactly 4 strings

**Endpoint:** `GET /api/ai/chat-prompts` → `string[]`

**Router:** [`server/stockpulse-api/routers/ai.py`](../server/stockpulse-api/routers/ai.py)

No Groq tokens used. No DB migration.

## iOS

| File | Change |
|------|--------|
| `Services/ChatPromptPicker.swift` | ET-date fallback pool + shuffle (offline) |
| `Services/StockPulseAPIService.swift` | `chatPrompts()` |
| `ViewModels/StockPulseViewModel.swift` | `aiChatPrompts`, `syncChatPrompts()` (called from `syncAssistantFeed` + AI tab `.task`) |
| `Views/AI/AIAnalystView.swift` | 2-column centered `LazyVGrid`, 4 dynamic prompts |

## Web

| File | Change |
|------|--------|
| `web/src/lib/chatPrompts.ts` | Fallback shuffle (mirrors server static pool) |
| `web/src/lib/api.ts` | `api.chatPrompts()` |
| `web/src/views/AIAnalystView.tsx` | Fetch on mount, 4 chips |
| `web/src/views/AIAnalystView.css` | `justify-content: center`, `text-align: center`, 2×2 mobile / 1×4 desktop |

## CSS (web)

```css
.suggestion-chips {
  display: flex;
  flex-wrap: wrap;
  justify-content: center;
  gap: var(--space-sm);
}
.suggestion-chip {
  flex: 1 1 calc(50% - var(--space-sm));
  text-align: center;
}
```

## Deploy

```bash
# API
rsync server/stockpulse-api/services/chat_prompts.py mspclientpro:/opt/stockpulse-api/services/
rsync server/stockpulse-api/routers/ai.py mspclientpro:/opt/stockpulse-api/routers/
ssh mspclientpro 'systemctl restart stockpulse-api'

# Web
cd web && npm run build && rsync -avz --delete dist/ mspclientpro:/var/www/tryan.app/
```

Verified live: `curl https://api.tryan.app/api/ai/chat-prompts`

## Test checklist

- [ ] Ask AI shows 4 centered chips (not 5 left-aligned)
- [ ] Tapping a chip sends that prompt
- [ ] Same 4 prompts all day; changes after midnight ET
- [ ] Offline / API error → date-rotated fallback prompts still show 4 chips

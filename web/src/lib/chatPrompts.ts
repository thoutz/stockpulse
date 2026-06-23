const FALLBACK_POOL = [
  "Summarize my watchlist for today",
  "Which ripple network looks strongest?",
  "Compare the top two movers this week",
  "What's the broad market telling us today?",
  "Which catalyst has the best ripple confirmation?",
  "Did NVDA earnings actually lift AMD?",
  "Which space stock has best risk/reward?",
  "Summarize the full watchlist",
];

function etDateKey(now = new Date()): string {
  return now.toLocaleDateString("en-CA", { timeZone: "America/New_York" });
}

async function sha256Hex(input: string): Promise<string> {
  const data = new TextEncoder().encode(input);
  const hash = await crypto.subtle.digest("SHA-256", data);
  return Array.from(new Uint8Array(hash))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

export async function fallbackChatPrompts(count = 4, now = new Date()): Promise<string[]> {
  const dateKey = etDateKey(now);
  const pool = FALLBACK_POOL;
  if (pool.length === 0) return [];

  const order = pool.map((_, i) => i);
  for (let i = order.length - 1; i > 0; i -= 1) {
    const digest = await sha256Hex(`${dateKey}:sort:${i}`);
    const j = parseInt(digest.slice(0, 8), 16) % (i + 1);
    [order[i], order[j]] = [order[j], order[i]];
  }

  const picked: string[] = [];
  for (const idx of order.slice(0, count)) {
    const prompt = pool[idx];
    if (!picked.includes(prompt)) picked.push(prompt);
  }

  let fallbackIndex = 0;
  while (picked.length < count) {
    const candidate = FALLBACK_POOL[fallbackIndex % FALLBACK_POOL.length];
    fallbackIndex += 1;
    if (!picked.includes(candidate)) picked.push(candidate);
  }

  return picked.slice(0, count);
}

export function normalizeChatPrompts(prompts: string[] | undefined, count = 4): string[] {
  if (prompts && prompts.length >= count) {
    return prompts.slice(0, count);
  }
  return [];
}

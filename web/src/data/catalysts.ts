export type RippleVerdict = "CONFIRMED" | "FORMING" | "FAILED" | "WATCHING";

export interface RippleStock {
  ticker: string;
  description: string;
}

export interface MarketEvent {
  date: string;
  label: string;
  color: string;
}

export interface Catalyst {
  ticker: string;
  name: string;
  eventName: string;
  eventDate: string;
  ripples: RippleStock[];
  events: MarketEvent[];
}

/** Offline fallback — runtime values come from useCatalog() / API. */
export const bundledWatchlistTickers = [
  "RKLB", "TSLA", "NVDA", "ASTS", "LUNR", "HWM", "RDW", "AMD", "AVGO",
];

export const bundledCatalysts: Catalyst[] = [
  {
    ticker: "NVDA",
    name: "NVIDIA",
    eventName: "Q1 FY2026 Earnings Beat",
    eventDate: "2026-05-28",
    ripples: [
      { ticker: "AMD", description: "Chip sector peer" },
      { ticker: "AVGO", description: "AI networking" },
    ],
    events: [{ date: "2026-05-28", label: "NVDA Earnings", color: "#22c55e" }],
  },
  {
    ticker: "RKLB",
    name: "Rocket Lab",
    eventName: "Q1 Earnings + Neutron Update",
    eventDate: "2026-05-14",
    ripples: [
      { ticker: "ASTS", description: "Satellite connectivity play" },
      { ticker: "LUNR", description: "Lunar infrastructure" },
      { ticker: "HWM", description: "Aerospace components" },
      { ticker: "RDW", description: "Spacecraft components" },
    ],
    events: [
      { date: "2026-05-28", label: "NVDA Earnings", color: "#22c55e" },
      { date: "2026-05-14", label: "RKLB Earnings", color: "#f59e0b" },
    ],
  },
];

/** @deprecated Use useCatalog().catalysts */
export const catalysts = bundledCatalysts;

/** @deprecated Use useCatalog().watchlistTickers */
export const watchlistTickers = bundledWatchlistTickers;

export function allTrackedTickersFrom(
  catalystList: Catalyst[],
  extra: string[] = bundledWatchlistTickers,
): string[] {
  const set = new Set<string>([
    ...extra,
    ...catalystList.flatMap((c) => [c.ticker, ...c.ripples.map((r) => r.ticker)]),
    "SPY",
    "QQQ",
  ]);
  return [...set].sort();
}

export function keyEventsFrom(catalystList: Catalyst[]): MarketEvent[] {
  const seen = new Set<string>();
  const events: MarketEvent[] = [];
  for (const c of catalystList) {
    for (const e of c.events) {
      const key = `${e.date}-${e.label}`;
      if (!seen.has(key)) {
        seen.add(key);
        events.push(e);
      }
    }
  }
  return events.sort((a, b) => a.date.localeCompare(b.date));
}

export function allTrackedTickers(): string[] {
  return allTrackedTickersFrom(bundledCatalysts);
}

export function keyEvents(): MarketEvent[] {
  return keyEventsFrom(bundledCatalysts);
}

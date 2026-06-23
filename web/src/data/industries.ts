import type { Catalyst } from "./catalysts";

export interface MarketIndex {
  id: string;
  ticker: string;
  name: string;
  subtitle: string;
}

export interface Industry {
  id: string;
  name: string;
  description: string;
  tickers: string[];
}

export const indexTickers = ["SPY", "QQQ"];

export const companyNames: Record<string, string> = {
  SPY: "SPDR S&P 500 ETF",
  QQQ: "Invesco QQQ Trust",
  NVDA: "NVIDIA",
  AMD: "AMD",
  AVGO: "Broadcom",
  RKLB: "Rocket Lab",
  ASTS: "AST SpaceMobile",
  LUNR: "Intuitive Machines",
  RDW: "Redwire",
  HWM: "Howmet Aerospace",
  TSLA: "Tesla",
};

export const indexBlurbs: Record<string, string> = {
  spy: "Tracks the S&P 500 — 500 large-cap US companies across every major sector.",
  qqq: "Tracks the Nasdaq-100 — mega-cap tech and growth names that drive risk appetite.",
};

export const bundledIndustryAccentHex: Record<string, string> = {
  semiconductors: "#a78bfa",
  space: "#60a5fa",
  ev: "#f59e0b",
};

/** @deprecated Use useCatalog().industryAccentHex */
export const industryAccentHex = bundledIndustryAccentHex;

export const indexAccentHex: Record<string, string> = {
  spy: "#34d399",
  qqq: "#60a5fa",
};

export const indices: MarketIndex[] = [
  { id: "spy", ticker: "SPY", name: "S&P 500", subtitle: "SPY ETF proxy" },
  { id: "qqq", ticker: "QQQ", name: "Nasdaq", subtitle: "QQQ ETF proxy" },
];

export const bundledIndustries: Industry[] = [
  {
    id: "semiconductors",
    name: "Semiconductors",
    description: "AI chips, networking, and compute",
    tickers: ["NVDA", "AMD", "AVGO"],
  },
  {
    id: "space",
    name: "Space & Aerospace",
    description: "Launch, satellites, and defense components",
    tickers: ["RKLB", "ASTS", "LUNR", "RDW", "HWM"],
  },
  {
    id: "ev",
    name: "EV & Auto",
    description: "Electric vehicles and mobility",
    tickers: ["TSLA"],
  },
];

/** @deprecated Use useCatalog().industries */
export const industries = bundledIndustries;

export function displayName(ticker: string): string {
  return companyNames[ticker.toUpperCase()] ?? ticker.toUpperCase();
}

export function industryFor(ticker: string, industryList: Industry[] = bundledIndustries): Industry | undefined {
  const sym = ticker.toUpperCase();
  return industryList.find((i) => i.tickers.includes(sym));
}

export function catalystLinks(
  ticker: string,
  catalystList: Catalyst[],
): { catalystTicker: string; role: string }[] {
  const sym = ticker.toUpperCase();
  const links: { catalystTicker: string; role: string }[] = [];
  for (const catalyst of catalystList) {
    if (catalyst.ticker === sym) {
      links.push({ catalystTicker: catalyst.ticker, role: "Catalyst" });
    }
    const rip = catalyst.ripples.find((r) => r.ticker === sym);
    if (rip) {
      links.push({ catalystTicker: catalyst.ticker, role: rip.description });
    }
  }
  return links;
}

export function accentForIndustry(
  industryId: string,
  accentMap: Record<string, string> = bundledIndustryAccentHex,
): string {
  return accentMap[industryId] ?? "#34d399";
}

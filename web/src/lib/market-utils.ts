import { useMemo } from "react";
import { barCloses } from "@/lib/api";
import type { APIDashboard, APISnapshot } from "@/lib/api";
import type { Industry } from "@/data/industries";
import { bundledIndustries } from "@/data/industries";

export interface TickerPerf {
  ticker: string;
  price: number;
  change1D: number;
  change30D: number;
  closes: number[];
}

export interface IndustrySnapshot {
  industry: Industry;
  constituents: TickerPerf[];
  avgChange1D: number;
  avgChange30D: number;
  breadthUp: number;
  breadthTotal: number;
  leader: TickerPerf | null;
  laggard: TickerPerf | null;
}

function perfForTicker(
  ticker: string,
  dashboard: APIDashboard,
  snapshots: Map<string, APISnapshot>,
): TickerPerf {
  const snap = snapshots.get(ticker);
  const bars = dashboard.histories[ticker] ?? dashboard.histories_extended[ticker] ?? [];
  const closes = barCloses(bars);
  return {
    ticker,
    price: snap?.price ?? closes[closes.length - 1] ?? 0,
    change1D: snap?.change_1d_pct ?? 0,
    change30D: snap?.change_30d_pct ?? 0,
    closes,
  };
}

export function industrySnapshotFor(
  ticker: string,
  dashboard: APIDashboard,
  snapshots: Map<string, APISnapshot>,
  industryList: Industry[] = bundledIndustries,
): IndustrySnapshot | null {
  const industry = industryList.find((i) => i.tickers.includes(ticker.toUpperCase()));
  if (!industry) return null;

  const constituents = industry.tickers.map((t) => perfForTicker(t, dashboard, snapshots));
  const avgChange1D =
    constituents.reduce((s, c) => s + c.change1D, 0) / (constituents.length || 1);
  const avgChange30D =
    constituents.reduce((s, c) => s + c.change30D, 0) / (constituents.length || 1);
  const breadthUp = constituents.filter((c) => c.change1D > 0).length;

  const sorted = [...constituents].sort((a, b) => b.change30D - a.change30D);

  return {
    industry,
    constituents,
    avgChange1D,
    avgChange30D,
    breadthUp,
    breadthTotal: constituents.length,
    leader: sorted[0] ?? null,
    laggard: sorted[sorted.length - 1] ?? null,
  };
}

export function rippleBadgesFor(
  ticker: string,
  dashboard: APIDashboard,
): { catalystTicker: string; verdict: string }[] {
  const sym = ticker.toUpperCase();
  const badges: { catalystTicker: string; verdict: string }[] = [];
  for (const [cat, results] of Object.entries(dashboard.ripple_results)) {
    const match = results.find((r) => r.ripple_ticker === sym);
    if (match) badges.push({ catalystTicker: cat, verdict: match.verdict });
  }
  return badges;
}

export function useExtendedHistory(
  ticker: string,
  dashboard: APIDashboard | null,
  days: 30 | 90,
) {
  return useMemo(() => {
    if (!dashboard) return [];
    const sym = ticker.toUpperCase();
    const bars =
      days === 90
        ? (dashboard.histories_extended[sym] ?? dashboard.histories[sym] ?? [])
        : (dashboard.histories[sym] ?? []);
    return bars;
  }, [ticker, dashboard, days]);
}

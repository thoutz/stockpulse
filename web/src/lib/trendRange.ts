import type { Catalyst } from "@/data/catalysts";
import type { APIBar } from "@/lib/api";

export type TrendRange = "1D" | "1W" | "30D" | "1Y";

export const TREND_RANGES: TrendRange[] = ["1D", "1W", "30D", "1Y"];

export const TREND_RANGE_LABELS: Record<TrendRange, string> = {
  "1D": "1D",
  "1W": "1W",
  "30D": "30D",
  "1Y": "1Y",
};

export function trendTickersFrom(catalystList: Catalyst[] | undefined): string[] {
  return [
    ...new Set(
      (catalystList ?? []).flatMap((c) => [c.ticker, ...c.ripples.map((r) => r.ticker)]),
    ),
  ];
}

const ET = "America/New_York";
const RTH_OPEN = 9 * 60 + 30;
const RTH_CLOSE = 16 * 60;

export function trendRangeNeedsFetch(range: TrendRange): boolean {
  return range === "1D" || range === "1Y";
}

export function trendRangeIsIntraday(range: TrendRange): boolean {
  return range === "1D";
}

export function trendRangeDayCount(range: TrendRange): number {
  switch (range) {
    case "1W":
      return 7;
    case "30D":
      return 30;
    case "1Y":
      return 365;
    default:
      return 30;
  }
}

function sortedBars(bars: APIBar[]): APIBar[] {
  return [...bars].sort((a, b) => a.date.localeCompare(b.date));
}

function etSessionDate(iso: string): string {
  return new Date(iso).toLocaleDateString("en-CA", { timeZone: ET });
}

function etMinutesSinceMidnight(iso: string): number {
  const d = new Date(iso);
  const h = Number(
    d.toLocaleString("en-US", { timeZone: ET, hour: "numeric", hour12: false }),
  );
  const m = Number(d.toLocaleString("en-US", { timeZone: ET, minute: "numeric" }));
  return h * 60 + m;
}

/** Last N trading-day bars (best for 1W). */
export function sliceDailyBars(bars: APIBar[], days: number): APIBar[] {
  const sorted = sortedBars(bars);
  if (sorted.length === 0) return [];

  if (days <= 7) {
    return sorted.slice(-Math.max(days, 2));
  }

  const cutoff = etCalendarCutoff(days);
  const filtered = sorted.filter((b) => new Date(b.date).getTime() >= cutoff.getTime());
  if (filtered.length >= 2) return filtered;
  return sorted.slice(-Math.min(days + 5, sorted.length));
}

function etCalendarCutoff(days: number): Date {
  const now = new Date();
  const parts = new Intl.DateTimeFormat("en-US", {
    timeZone: ET,
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).formatToParts(now);
  const y = Number(parts.find((p) => p.type === "year")?.value ?? "1970");
  const m = Number(parts.find((p) => p.type === "month")?.value ?? "1");
  const d = Number(parts.find((p) => p.type === "day")?.value ?? "1");
  const utcMidnight = Date.UTC(y, m - 1, d);
  return new Date(utcMidnight - days * 86_400_000);
}

/** Latest regular-hours minute bars for the most recent session. */
export function sliceMinuteSession(bars: APIBar[]): APIBar[] {
  const sorted = sortedBars(bars);
  if (sorted.length === 0) return [];

  const lastSession = etSessionDate(sorted[sorted.length - 1].date);
  const session = sorted.filter((b) => etSessionDate(b.date) === lastSession);
  const rth = session.filter((b) => {
    const mins = etMinutesSinceMidnight(b.date);
    return mins >= RTH_OPEN && mins <= RTH_CLOSE;
  });
  if (rth.length >= 2) return rth;
  if (session.length >= 2) return session;

  const lastTs = new Date(sorted[sorted.length - 1].date).getTime();
  const recent = sorted.filter((b) => new Date(b.date).getTime() >= lastTs - 6.5 * 3600 * 1000);
  if (recent.length >= 2) return recent;
  return sorted.slice(-Math.min(120, sorted.length));
}

/** Trim all tickers to the same trailing window so lines share an x-axis. */
export function alignTrendBars(
  tickers: string[],
  barsByTicker: Record<string, APIBar[]>,
): { aligned: Record<string, APIBar[]>; dates: string[] } {
  const sortedMap: Record<string, APIBar[]> = {};
  for (const t of tickers) {
    sortedMap[t] = sortedBars(barsByTicker[t] ?? []);
  }

  const lengths = tickers
    .map((t) => sortedMap[t]?.length ?? 0)
    .filter((n) => n >= 2);
  if (lengths.length === 0) {
    return { aligned: sortedMap, dates: sortedMap[tickers[0]]?.map((b) => b.date) ?? [] };
  }

  const n = Math.min(...lengths);
  const aligned: Record<string, APIBar[]> = {};
  for (const t of tickers) {
    aligned[t] = sortedMap[t].slice(-n);
  }

  return { aligned, dates: aligned[tickers[0]]?.map((b) => b.date) ?? [] };
}

export function barsForTrendRange(
  range: TrendRange,
  ticker: string,
  dashboardBars: APIBar[],
  fetchedBars: Record<string, APIBar[]>,
): APIBar[] {
  if (range === "1Y") {
    const extended = fetchedBars[ticker];
    if (extended && extended.length >= 2) {
      return sliceDailyBars(sortedBars(extended), trendRangeDayCount(range));
    }
    return sliceDailyBars(dashboardBars, trendRangeDayCount(range));
  }

  if (range === "1D") {
    const minute = fetchedBars[ticker];
    if (minute && minute.length > 0) {
      const session = sliceMinuteSession(minute);
      if (session.length >= 2) return session;
    }
    return sliceDailyBars(dashboardBars, 2);
  }

  return sliceDailyBars(dashboardBars, trendRangeDayCount(range));
}

/** Monitor price chart — slice from full daily cache + optional minute bars. */
export function monitorBarsForRange(
  range: TrendRange,
  dailyBars: APIBar[],
  minuteBars: APIBar[] | undefined,
): APIBar[] {
  if (range === "1D") {
    if (minuteBars && minuteBars.length > 0) {
      const session = sliceMinuteSession(minuteBars);
      if (session.length >= 2) return session;
    }
    return sliceDailyBars(dailyBars, 2);
  }
  if (range === "1W") return sliceDailyBars(dailyBars, 7);
  if (range === "30D") return sliceDailyBars(dailyBars, 30);
  return sliceDailyBars(dailyBars, 365);
}

export function formatMonitorAxisDate(iso: string, range: TrendRange): string {
  if (trendRangeIsIntraday(range)) {
    return formatTrendAxisDate(iso, true);
  }
  if (range === "1Y") {
    return new Date(iso).toLocaleDateString("en-US", {
      timeZone: ET,
      month: "short",
      day: "numeric",
    });
  }
  return iso.slice(5, 10);
}

export function formatTrendAxisDate(iso: string, intraday: boolean): string {
  if (intraday) {
    return new Date(iso).toLocaleTimeString("en-US", {
      timeZone: ET,
      hour: "2-digit",
      minute: "2-digit",
      hour12: false,
    });
  }
  return iso.slice(5, 10);
}

import { useCallback, useEffect, useRef, useState } from "react";
import { api, type APIDashboard, type APIBar } from "@/lib/api";
import type { Catalyst } from "@/data/catalysts";
import {
  trendRangeNeedsFetch,
  trendTickersFrom,
  type TrendRange,
} from "@/lib/trendRange";

export function useTrendRangeData(
  dashboard: APIDashboard | null,
  catalysts: Catalyst[],
) {
  const trendTickers = trendTickersFrom(catalysts);
  const [range, setRange] = useState<TrendRange>("30D");
  const [fetchedBars, setFetchedBars] = useState<Record<string, APIBar[]>>({});
  const [loading, setLoading] = useState(false);
  const [fetchError, setFetchError] = useState<string | null>(null);
  const cacheRef = useRef<Map<TrendRange, Record<string, APIBar[]>>>(new Map());

  useEffect(() => {
    if (!dashboard || !trendRangeNeedsFetch(range) || trendTickers.length === 0) {
      setFetchedBars({});
      setFetchError(null);
      return;
    }

    const cached = cacheRef.current.get(range);
    if (cached) {
      setFetchedBars(cached);
      setFetchError(null);
      return;
    }

    let cancelled = false;
    setLoading(true);
    setFetchError(null);

    void (async () => {
      try {
        let bars: Record<string, APIBar[]>;
        if (range === "1D") {
          const pairs = await Promise.all(
            trendTickers.map(async (ticker) => {
              const minute = await api.minute(ticker, 500);
              return [ticker, minute] as const;
            }),
          );
          bars = Object.fromEntries(pairs);
        } else {
          const resp = await api.histories(trendTickers, 365);
          bars = resp.histories;
        }
        if (cancelled) return;
        cacheRef.current.set(range, bars);
        setFetchedBars(bars);
      } catch (e) {
        if (!cancelled) {
          setFetchError(e instanceof Error ? e.message : "Could not load chart range");
          setFetchedBars({});
        }
      } finally {
        if (!cancelled) setLoading(false);
      }
    })();

    return () => {
      cancelled = true;
    };
  }, [range, dashboard, trendTickers]);

  const dashboardBarsFor = useCallback(
    (ticker: string): APIBar[] =>
      dashboard?.histories[ticker] ?? dashboard?.histories_extended[ticker] ?? [],
    [dashboard],
  );

  return {
    range,
    setRange,
    fetchedBars,
    loading,
    fetchError,
    dashboardBarsFor,
  };
}

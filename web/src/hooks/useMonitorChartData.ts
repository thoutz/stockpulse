import { useEffect, useMemo, useRef, useState } from "react";
import { api, type APIDashboard, type APIBar } from "@/lib/api";
import { monitorBarsForRange, type TrendRange } from "@/lib/trendRange";

function cacheKey(symbol: string, kind: "daily" | "minute"): string {
  return `${symbol.toUpperCase()}-${kind}`;
}

export function useMonitorChartData(
  symbol: string | null,
  dashboard: APIDashboard | null,
) {
  const [range, setRange] = useState<TrendRange>("1D");
  const [dailyBars, setDailyBars] = useState<APIBar[]>([]);
  const [minuteBars, setMinuteBars] = useState<APIBar[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const cacheRef = useRef<Map<string, APIBar[]>>(new Map());

  const dashboardBars = useMemo((): APIBar[] => {
    if (!symbol || !dashboard) return [];
    const sym = symbol.toUpperCase();
    return dashboard.histories[sym] ?? dashboard.histories_extended[sym] ?? [];
  }, [symbol, dashboard]);

  // Load full daily history once per symbol (used for 1W / 30D / 1Y slicing).
  useEffect(() => {
    if (!symbol) {
      setDailyBars([]);
      setError(null);
      return;
    }

    const sym = symbol.toUpperCase();
    const key = cacheKey(sym, "daily");
    const cached = cacheRef.current.get(key);
    if (cached) {
      setDailyBars(cached);
      return;
    }

    let cancelled = false;
    setLoading(true);
    setError(null);

    void (async () => {
      try {
        const resp = await api.histories([sym], 365);
        const bars = resp.histories[sym] ?? dashboardBars;
        if (cancelled) return;
        cacheRef.current.set(key, bars);
        setDailyBars(bars);
      } catch (e) {
        if (!cancelled) {
          if (dashboardBars.length >= 2) {
            setDailyBars(dashboardBars);
          } else {
            setError(e instanceof Error ? e.message : "Could not load chart data");
            setDailyBars([]);
          }
        }
      } finally {
        if (!cancelled) setLoading(false);
      }
    })();

    return () => {
      cancelled = true;
    };
  }, [symbol, dashboardBars]);

  // Load minute bars when 1D is selected.
  useEffect(() => {
    if (!symbol || range !== "1D") {
      setMinuteBars([]);
      return;
    }

    const sym = symbol.toUpperCase();
    const key = cacheKey(sym, "minute");
    const cached = cacheRef.current.get(key);
    if (cached) {
      setMinuteBars(cached);
      return;
    }

    let cancelled = false;
    setLoading(true);
    setError(null);

    void (async () => {
      try {
        const bars = await api.minute(sym, 500);
        if (cancelled) return;
        cacheRef.current.set(key, bars);
        setMinuteBars(bars);
      } catch (e) {
        if (!cancelled) {
          setError(e instanceof Error ? e.message : "Could not load intraday chart");
          setMinuteBars([]);
        }
      } finally {
        if (!cancelled) setLoading(false);
      }
    })();

    return () => {
      cancelled = true;
    };
  }, [symbol, range]);

  const bars = useMemo((): APIBar[] => {
    if (!symbol) return [];
    const source = dailyBars.length >= 2 ? dailyBars : dashboardBars;
    return monitorBarsForRange(range, source, range === "1D" ? minuteBars : undefined);
  }, [symbol, range, dailyBars, dashboardBars, minuteBars]);

  const periodChangePct = useMemo((): number | null => {
    if (bars.length < 2) return null;
    const first = bars[0].close;
    const last = bars[bars.length - 1].close;
    if (first <= 0) return null;
    return ((last - first) / first) * 100;
  }, [bars]);

  return {
    range,
    setRange,
    bars,
    loading,
    error,
    periodChangePct,
  };
}

export function monitorChangePct(bars: APIBar[], index: number): number | null {
  if (bars.length < 2 || index < 0 || index >= bars.length) return null;
  const first = bars[0].close;
  const selected = bars[index].close;
  if (first <= 0) return null;
  return ((selected - first) / first) * 100;
}

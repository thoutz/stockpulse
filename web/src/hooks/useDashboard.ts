import { useCallback, useEffect, useMemo, useState } from "react";
import {
  api,
  type APIDashboard,
  type APIFavorite,
  type APISnapshot,
  barCloses,
  snapshotMap,
} from "@/lib/api";
import { bundledWatchlistTickers } from "@/data/catalysts";
import { displayName } from "@/data/industries";
import { parseVerdict } from "@/lib/design-system";
import type { RippleVerdict } from "@/data/catalysts";

const CACHE_KEY = "stockpulse_dashboard";

export interface WatchItem {
  ticker: string;
  name: string;
  price: number;
  change1D: number;
  change30D: number;
  closes: number[];
  rippleBadges: { catalyst: string; verdict: RippleVerdict }[];
}

export function useDashboard(watchlistTickers: string[] = bundledWatchlistTickers) {
  const [dashboard, setDashboard] = useState<APIDashboard | null>(() => {
    try {
      const raw = sessionStorage.getItem(CACHE_KEY);
      if (raw) return JSON.parse(raw) as APIDashboard;
    } catch {
      /* ignore */
    }
    return null;
  });
  const [sessionFavorites, setSessionFavorites] = useState<APIFavorite[]>([]);
  const [loading, setLoading] = useState(!dashboard);
  const [refreshing, setRefreshing] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const snapshots = useMemo(
    () => (dashboard ? snapshotMap(dashboard) : new Map<string, APISnapshot>()),
    [dashboard],
  );

  const favoriteSymbols = useMemo(
    () => sessionFavorites.map((f) => f.symbol.toUpperCase()),
    [sessionFavorites],
  );

  const watchItems = useMemo((): WatchItem[] => {
    if (!dashboard) return [];
    const tickers = [
      ...new Set([
        ...watchlistTickers,
        ...favoriteSymbols,
        ...dashboard.favorites.map((f) => f.toUpperCase()),
      ]),
    ].sort();

    return tickers.map((ticker) => {
      const snap = snapshots.get(ticker);
      const bars = dashboard.histories[ticker] ?? dashboard.histories_extended[ticker] ?? [];
      const closes = barCloses(bars);

      const rippleBadges: WatchItem["rippleBadges"] = [];
      for (const [cat, results] of Object.entries(dashboard.ripple_results)) {
        const match = results.find((r) => r.ripple_ticker === ticker);
        if (match) {
          rippleBadges.push({
            catalyst: cat,
            verdict: parseVerdict(match.verdict),
          });
        }
      }

      return {
        ticker,
        name: displayName(ticker),
        price: snap?.price ?? closes[closes.length - 1] ?? 0,
        change1D: snap?.change_1d_pct ?? 0,
        change30D: snap?.change_30d_pct ?? 0,
        closes,
        rippleBadges,
      };
    });
  }, [dashboard, snapshots, favoriteSymbols, watchlistTickers]);

  const loadSessionFavorites = useCallback(async () => {
    try {
      const favs = await api.sessionFavorites();
      setSessionFavorites(favs);
    } catch {
      /* session endpoint may not exist yet during dev */
    }
  }, []);

  const refresh = useCallback(async (light = false) => {
    if (light) setRefreshing(true);
    else setLoading(true);
    setError(null);
    try {
      const data = await api.dashboard();
      setDashboard(data);
      sessionStorage.setItem(CACHE_KEY, JSON.stringify(data));
    } catch (e) {
      setError(e instanceof Error ? e.message : "Failed to load dashboard");
    } finally {
      setLoading(false);
      setRefreshing(false);
    }
  }, []);

  const isFavorite = useCallback(
    (symbol: string) => favoriteSymbols.includes(symbol.toUpperCase()),
    [favoriteSymbols],
  );

  const addFavorite = useCallback(async (symbol: string, name?: string) => {
    const sym = symbol.toUpperCase();
    try {
      const fav = await api.addSessionFavorite(sym, name ?? displayName(sym));
      setSessionFavorites((prev) => {
        if (prev.some((f) => f.symbol === sym)) return prev;
        return [...prev, fav];
      });
    } catch {
      setSessionFavorites((prev) => {
        if (prev.some((f) => f.symbol === sym)) return prev;
        return [...prev, { symbol: sym, name: name ?? displayName(sym) }];
      });
    }
  }, []);

  const removeFavorite = useCallback(async (symbol: string) => {
    const sym = symbol.toUpperCase();
    try {
      await api.removeSessionFavorite(sym);
    } catch {
      /* fallback local remove */
    }
    setSessionFavorites((prev) => prev.filter((f) => f.symbol !== sym));
  }, []);

  useEffect(() => {
    void refresh();
    void loadSessionFavorites();
  }, [refresh, loadSessionFavorites]);

  useEffect(() => {
    const id = setInterval(() => void refresh(true), 60_000);
    return () => clearInterval(id);
  }, [refresh]);

  const usesLiveData = !!dashboard && !dashboard.stale;
  const dataThroughLabel = dashboard?.data_as_of
    ? `Live · ${new Date(dashboard.data_as_of).toLocaleTimeString("en-US", { hour: "numeric", minute: "2-digit" })}`
    : "Live";

  return {
    dashboard,
    snapshots,
    watchItems,
    favoriteSymbols,
    loading,
    refreshing,
    error,
    refresh,
    isFavorite,
    addFavorite,
    removeFavorite,
    usesLiveData,
    dataThroughLabel,
  };
}

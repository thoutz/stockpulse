import { useCallback, useEffect, useMemo, useState } from "react";
import { api, type APIMonitorPayload, type APIMonitorSymbol } from "@/lib/api";

const POLL_MS = 30_000;

export function useMonitor(active: boolean) {
  const [payload, setPayload] = useState<APIMonitorPayload | null>(null);
  const [loading, setLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [focusPending, setFocusPending] = useState(false);

  const sync = useCallback(async (light = false) => {
    if (light) setRefreshing(true);
    else setLoading(true);
    setError(null);
    try {
      const data = await api.monitor();
      setPayload(data);
    } catch (e) {
      setError(e instanceof Error ? e.message : "Monitor sync failed");
    } finally {
      setLoading(false);
      setRefreshing(false);
    }
  }, []);

  const setFocusSector = useCallback(async (sectorId: string | null) => {
    setFocusPending(true);
    setError(null);
    try {
      const data = await api.setMonitorFocus(sectorId);
      setPayload(data);
    } catch (e) {
      setError(e instanceof Error ? e.message : "Failed to update focus sector");
    } finally {
      setFocusPending(false);
    }
  }, []);

  const addFavorite = useCallback(
    async (symbol: string, name?: string) => {
      await api.addServerFavorite(symbol, name ?? null);
      await sync(true);
    },
    [sync],
  );

  const removeFavorite = useCallback(
    async (symbol: string) => {
      await api.removeServerFavorite(symbol);
      await sync(true);
    },
    [sync],
  );

  useEffect(() => {
    void sync();
  }, [sync]);

  useEffect(() => {
    if (!active) return;
    const id = setInterval(() => void sync(true), POLL_MS);
    return () => clearInterval(id);
  }, [active, sync]);

  const topMovers = useMemo((): APIMonitorSymbol[] => {
    if (!payload) return [];
    const rows = [...payload.hot, ...payload.warm].filter(
      (r) => r.change_5m_pct != null && r.price > 0,
    );
    return rows
      .sort((a, b) => Math.abs(b.change_5m_pct ?? 0) - Math.abs(a.change_5m_pct ?? 0))
      .slice(0, 5);
  }, [payload]);

  const isAtFavoriteLimit = (payload?.favorite_count ?? 0) >= (payload?.favorite_limit ?? 20);

  const liveLabel = useMemo(() => {
    const stamps = [...(payload?.hot ?? []), ...(payload?.warm ?? [])]
      .map((r) => r.captured_at)
      .filter(Boolean) as string[];
    if (stamps.length === 0) return "Monitor";
    const latest = stamps.reduce((a, b) => (a > b ? a : b));
    const t = new Date(latest).toLocaleTimeString("en-US", {
      hour: "numeric",
      minute: "2-digit",
    });
    return `Live · ${t}`;
  }, [payload]);

  return {
    payload,
    hot: payload?.hot ?? [],
    warm: payload?.warm ?? [],
    cold: payload?.cold ?? [],
    focusSectorId: payload?.focus_sector_id ?? null,
    favoriteCount: payload?.favorite_count ?? 0,
    favoriteLimit: payload?.favorite_limit ?? 20,
    isAtFavoriteLimit,
    topMovers,
    loading,
    refreshing,
    error,
    focusPending,
    liveLabel,
    sync,
    setFocusSector,
    addFavorite,
    removeFavorite,
  };
}

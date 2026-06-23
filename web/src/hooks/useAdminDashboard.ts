import { useCallback, useEffect, useState } from "react";
import { APIError, api, type APIAdminDashboard } from "@/lib/api";

const ADMIN_PASSWORD_KEY = "sp_admin_password";
const POLL_MS = 30_000;

export function getStoredAdminPassword(): string | null {
  try {
    return sessionStorage.getItem(ADMIN_PASSWORD_KEY);
  } catch {
    return null;
  }
}

export function storeAdminPassword(password: string): void {
  sessionStorage.setItem(ADMIN_PASSWORD_KEY, password);
}

export function clearAdminPassword(): void {
  sessionStorage.removeItem(ADMIN_PASSWORD_KEY);
}

export function useAdminDashboard(password: string | null) {
  const [dashboard, setDashboard] = useState<APIAdminDashboard | null>(null);
  const [loading, setLoading] = useState(false);
  const [refreshing, setRefreshing] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const fetchDashboard = useCallback(
    async (isRefresh = false) => {
      if (!password) return;
      if (isRefresh) setRefreshing(true);
      else setLoading(true);
      setError(null);
      try {
        const data = await api.adminDashboard(password);
        setDashboard(data);
      } catch (err) {
        if (err instanceof APIError && err.status === 403) {
          clearAdminPassword();
          setError("Session expired — please sign in again.");
        } else {
          setError(err instanceof Error ? err.message : "Failed to load dashboard");
        }
        setDashboard(null);
      } finally {
        setLoading(false);
        setRefreshing(false);
      }
    },
    [password],
  );

  useEffect(() => {
    if (!password) {
      setDashboard(null);
      return;
    }
    void fetchDashboard();
    const id = window.setInterval(() => void fetchDashboard(true), POLL_MS);
    return () => window.clearInterval(id);
  }, [password, fetchDashboard]);

  return {
    dashboard,
    loading,
    refreshing,
    error,
    refresh: () => fetchDashboard(true),
  };
}

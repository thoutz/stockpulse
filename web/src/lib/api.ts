export type AppTab = "pulse" | "watchlist" | "analyst" | "ai";

export interface APIBar {
  date: string;
  open: number;
  high: number;
  low: number;
  close: number;
  volume: number;
}

export interface APISnapshot {
  symbol: string;
  price: number;
  change_1d_pct: number;
  change_30d_pct: number;
  change_5m_pct?: number | null;
  change_15m_pct?: number | null;
  rsi?: number | null;
  sma_20?: number | null;
  quote_source?: string | null;
  captured_at: string;
}

export interface APIRippleResult {
  catalyst_ticker: string;
  ripple_ticker: string;
  description: string;
  verdict: string;
  pre_event_pct: number;
  post_event_pct: number;
}

export interface APIDashboard {
  snapshots: APISnapshot[];
  histories: Record<string, APIBar[]>;
  histories_extended: Record<string, APIBar[]>;
  ripple_results: Record<string, APIRippleResult[]>;
  data_as_of?: string | null;
  stale: boolean;
  stale_tickers: string[];
  favorites: string[];
}

export interface APITickerSearchResult {
  symbol: string;
  name: string;
}

export interface APIFavorite {
  symbol: string;
  name?: string | null;
}

export interface APIReport {
  id: number;
  report_type: string;
  title: string;
  body: string;
  created_at: string;
}

export interface APISuggestion {
  id: number;
  symbol: string;
  bias: string;
  summary: string;
  created_at: string;
}

export interface APIAlert {
  id: number;
  symbol: string;
  alert_type: string;
  message: string;
  change_pct: number;
  created_at: string;
  delivered_push: boolean;
}

export interface APIDigestDay {
  date: string;
  reports: APIReport[];
  alerts: APIAlert[];
  suggestions: APISuggestion[];
}

export interface APIDigest {
  days: APIDigestDay[];
}

export interface APIChatResponse {
  response: string;
  questions_remaining?: number | null;
}

export interface APINewsItem {
  symbol: string;
  headline: string;
  summary?: string | null;
  source?: string | null;
  url: string;
  published_at: string;
  sentiment_score?: number | null;
}

export interface APICatalogSector {
  id: string;
  name: string;
  description: string;
  tickers: string[];
  accent_hex: string;
}

export interface APICatalogRipple {
  ticker: string;
  description: string;
}

export interface APICatalogCatalyst {
  id?: number | null;
  ticker: string;
  name: string;
  event_name: string;
  event_date: string;
  active: boolean;
  confidence_score?: number | null;
  source?: string | null;
  ripples: APICatalogRipple[];
}

export interface APICatalogSectorsResponse {
  count: number;
  sectors: APICatalogSector[];
}

export interface APICatalogCatalystsResponse {
  count: number;
  catalysts: APICatalogCatalyst[];
}

export type MonitorTier = "hot" | "warm" | "cold";

export interface APIMonitorSymbol {
  symbol: string;
  name?: string | null;
  tier: MonitorTier;
  sector_id?: string | null;
  price: number;
  change_1d_pct: number;
  change_5m_pct?: number | null;
  change_15m_pct?: number | null;
  change_30d_pct: number;
  rsi?: number | null;
  sma_20?: number | null;
  quote_source?: string | null;
  captured_at?: string | null;
  lag_seconds?: number | null;
  is_favorite: boolean;
}

export interface APIMonitorSector {
  id: string;
  name: string;
  description: string;
  tickers: string[];
  accent_hex: string;
}

export interface APIMonitorPayload {
  focus_sector_id: string | null;
  favorite_count: number;
  favorite_limit: number;
  sectors: APIMonitorSector[];
  hot: APIMonitorSymbol[];
  warm: APIMonitorSymbol[];
  cold: APIMonitorSymbol[];
}

export interface APIFavoriteList {
  favorites: APIFavorite[];
  count: number;
  limit: number;
}

export interface APIIndicator {
  type: string;
  ts: string;
  value: number;
}

export interface APIAdminRequestMetrics {
  started_at: string;
  total_requests: number;
  requests_last_hour: number;
  by_method: Record<string, number>;
  top_paths_all_time: { path: string; count: number }[];
  top_paths_last_hour: { path: string; count: number }[];
}

export interface APIAdminProviderHealth {
  status: string;
  checked_at: string;
  finnhub_configured: boolean;
  massive_configured: boolean;
  tiers: { hot: number; warm: number; cold: number };
  estimated_finnhub_calls_per_min: number;
  massive_calls_per_min_limit: number;
  quote_ticks_last_hour: number;
  quote_sources: Record<string, number>;
  stale_quotes: { hot: string[]; warm: string[]; cold: string[] };
  stale_daily_bars: string[];
}

export interface APIAdminDbTable {
  table: string;
  rows: number;
  size_bytes: number;
  size_human: string;
}

export interface APIAdminDatabase {
  healthy: boolean;
  latency_ms: number | null;
  error: string | null;
  database_size_bytes: number;
  database_size_human: string;
  tables: APIAdminDbTable[];
}

export interface APIAdminSymbolStats {
  config_tickers: string[];
  config_ticker_count: number;
  tracked_count: number;
  tracked_symbols: string[];
  db_ticker_count: number;
  active_ticker_count: number;
  inactive_ticker_count: number;
  favorites_count: number;
  session_favorites_count: number;
  symbols_with_daily_bars: number;
  total_daily_bars: number;
  total_minute_bars: number;
  total_snapshots: number;
  total_quote_ticks: number;
}

export interface APIAdminSymbolDataRow {
  symbol: string;
  bar_count: number;
  last_bar_date: string | null;
  has_hot_data: boolean;
}

export interface APIAdminSymbolData {
  tickers: APIAdminSymbolDataRow[];
  hot_days: number;
  full_days: number;
}

export interface APIAdminGroqUsage {
  day: string;
  tokens_used: number;
  tokens_budget: number;
  tokens_remaining: number;
  chat_used: number;
  chat_limit: number;
  chat_remaining: number;
}

export interface APIAdminSchedulerJob {
  id: string;
  name: string | null;
  next_run: string | null;
  trigger: string;
}

export interface APIAdminScheduler {
  running: boolean;
  job_count: number;
  jobs: APIAdminSchedulerJob[];
  ingest_warm_complete: boolean;
}

export interface APIAdminDashboard {
  generated_at: string;
  api: APIAdminRequestMetrics;
  providers: APIAdminProviderHealth;
  database: APIAdminDatabase;
  symbols: APIAdminSymbolStats;
  symbol_data: APIAdminSymbolData;
  groq: APIAdminGroqUsage;
  scheduler: APIAdminScheduler;
}

export class APIError extends Error {
  constructor(
    message: string,
    public status: number,
  ) {
    super(message);
    this.name = "APIError";
  }
}

const API_BASE =
  import.meta.env.VITE_API_BASE_URL ??
  (import.meta.env.DEV ? "" : "https://api.tryan.app");

async function parseError(res: Response): Promise<string> {
  try {
    const body = (await res.json()) as { detail?: string };
    if (body.detail) return body.detail;
  } catch {
    /* ignore */
  }
  return `Server error (HTTP ${res.status})`;
}

async function request<T>(
  path: string,
  init: RequestInit = {},
  credentials = false,
  extraHeaders: Record<string, string> = {},
): Promise<T> {
  const res = await fetch(`${API_BASE}${path}`, {
    ...init,
    credentials: credentials ? "include" : "same-origin",
    headers: {
      ...(init.headers ?? {}),
      ...extraHeaders,
    },
  });
  if (!res.ok) throw new APIError(await parseError(res), res.status);
  if (res.status === 204) return undefined as T;
  return res.json() as Promise<T>;
}

async function get<T>(
  path: string,
  credentials = false,
  extraHeaders: Record<string, string> = {},
): Promise<T> {
  return request<T>(path, {}, credentials, extraHeaders);
}

async function post<T>(path: string, body: unknown, credentials = false): Promise<T> {
  return request<T>(
    path,
    {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(body),
    },
    credentials,
  );
}

async function put<T>(path: string, body: unknown, credentials = false): Promise<T> {
  return request<T>(
    path,
    {
      method: "PUT",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(body),
    },
    credentials,
  );
}

async function del(path: string, credentials = false): Promise<void> {
  await request<void>(path, { method: "DELETE" }, credentials);
}

export const api = {
  health: () => get<{ status: string; service: string }>("/api/health"),

  catalogSectors: () => get<APICatalogSectorsResponse>("/api/catalog/sectors"),

  catalogCatalysts: () => get<APICatalogCatalystsResponse>("/api/catalog/catalysts"),

  monitor: () => get<APIMonitorPayload>("/api/monitor"),

  setMonitorFocus: (focusSectorId: string | null) =>
    put<APIMonitorPayload>("/api/monitor/focus", { focus_sector_id: focusSectorId }),

  serverFavorites: () => get<APIFavoriteList>("/api/favorites"),

  addServerFavorite: (symbol: string, name?: string | null) =>
    post<APIFavorite>("/api/favorites", { symbol, name }),

  removeServerFavorite: (symbol: string) =>
    del(`/api/favorites/${encodeURIComponent(symbol.toUpperCase())}`),

  dashboard: () => get<APIDashboard>("/api/dashboard"),

  histories: (tickers: string[], days = 365) => {
    const joined = tickers.map((t) => t.toUpperCase()).join(",");
    const encoded = encodeURIComponent(joined);
    return get<{ histories: Record<string, APIBar[]> }>(
      `/api/histories?tickers=${encoded}&days=${days}`,
    );
  },

  minute: (symbol: string, limit = 500) => {
    const sym = encodeURIComponent(symbol.toUpperCase());
    return get<APIBar[]>(`/api/minute/${sym}?limit=${limit}`);
  },

  search: (q: string) => {
    const encoded = encodeURIComponent(q.trim());
    return get<APITickerSearchResult[]>(`/api/search?q=${encoded}`);
  },

  sessionFavorites: () => get<APIFavorite[]>("/api/session/favorites", true),

  addSessionFavorite: (symbol: string, name?: string | null) =>
    post<APIFavorite>("/api/session/favorites", { symbol, name }, true),

  removeSessionFavorite: (symbol: string) =>
    del(`/api/session/favorites/${encodeURIComponent(symbol)}`, true),

  digest: (days = 7) => get<APIDigest>(`/api/ai/digest?days=${Math.min(Math.max(days, 1), 7)}`),

  reports: (limit = 20) => get<APIReport[]>(`/api/ai/reports?limit=${limit}`),

  suggestions: (limit = 30) => get<APISuggestion[]>(`/api/ai/suggestions?limit=${limit}`),

  alerts: (limit = 50) => get<APIAlert[]>(`/api/ai/alerts?limit=${Math.min(limit, 50)}`),

  chatPrompts: () => get<string[]>("/api/ai/chat-prompts"),

  chat: (prompt: string, selectedCatalystIndex = 0) =>
    post<APIChatResponse>("/api/ai/chat", {
      prompt,
      selected_catalyst_index: selectedCatalystIndex,
    }),

  news: (symbolOrSymbols: string | string[], limit = 6) => {
    if (Array.isArray(symbolOrSymbols)) {
      const joined = symbolOrSymbols.map((s) => s.toUpperCase()).join(",");
      return get<APINewsItem[]>(
        `/api/news?symbols=${encodeURIComponent(joined)}&limit=${limit}`,
      );
    }
    return get<APINewsItem[]>(
      `/api/news?symbol=${encodeURIComponent(symbolOrSymbols.toUpperCase())}&limit=${limit}`,
    );
  },

  indicators: (symbol: string) =>
    get<APIIndicator[]>(`/api/indicators/${encodeURIComponent(symbol.toUpperCase())}`),

  adminLogin: (password: string) =>
    post<{ ok: boolean }>("/api/admin/login", { password }),

  adminDashboard: (password: string) =>
    get<APIAdminDashboard>("/api/admin/dashboard", false, { "X-Admin-Password": password }),
};

export function barCloses(bars: APIBar[]): number[] {
  return bars.map((b) => b.close);
}

export function barDates(bars: APIBar[]): string[] {
  return bars.map((b) => b.date);
}

export function snapshotMap(dashboard: APIDashboard): Map<string, APISnapshot> {
  return new Map(dashboard.snapshots.map((s) => [s.symbol.toUpperCase(), s]));
}

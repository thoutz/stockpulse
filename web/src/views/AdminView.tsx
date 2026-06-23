import { FormEvent, useState } from "react";
import { APIError, api } from "@/lib/api";
import {
  clearAdminPassword,
  getStoredAdminPassword,
  storeAdminPassword,
  useAdminDashboard,
} from "@/hooks/useAdminDashboard";
import "./AdminView.css";

function statusBadge(status: string) {
  if (status === "ok") return "admin-badge admin-badge-ok";
  if (status === "degraded") return "admin-badge admin-badge-warn";
  return "admin-badge admin-badge-error";
}

function AdminLogin({ onSuccess }: { onSuccess: (password: string) => void }) {
  const [password, setPassword] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [submitting, setSubmitting] = useState(false);

  async function handleSubmit(e: FormEvent) {
    e.preventDefault();
    setSubmitting(true);
    setError(null);
    try {
      await api.adminLogin(password);
      storeAdminPassword(password);
      onSuccess(password);
    } catch (err) {
      setError(err instanceof APIError ? err.message : "Login failed");
    } finally {
      setSubmitting(false);
    }
  }

  return (
    <div className="admin-login">
      <div className="admin-login-card">
        <h1>StockPulse Admin</h1>
        <p>Enter the admin password to view system monitoring.</p>
        {error && <div className="admin-login-error">{error}</div>}
        <form onSubmit={(e) => void handleSubmit(e)}>
          <label htmlFor="admin-password">Password</label>
          <input
            id="admin-password"
            type="password"
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            autoComplete="current-password"
            autoFocus
          />
          <button type="submit" className="admin-btn admin-btn-primary" disabled={submitting || !password}>
            {submitting ? "Signing in…" : "Sign in"}
          </button>
        </form>
      </div>
    </div>
  );
}

function StatCard({ label, value }: { label: string; value: string | number }) {
  return (
    <div className="admin-panel admin-stat">
      <span className="admin-stat-value">{value}</span>
      <span className="admin-stat-label">{label}</span>
    </div>
  );
}

function AdminDashboard({ password }: { password: string }) {
  const { dashboard, loading, refreshing, error, refresh } = useAdminDashboard(password);

  function signOut() {
    clearAdminPassword();
    window.location.reload();
  }

  if (loading && !dashboard) {
    return <div className="admin-loading">Loading dashboard…</div>;
  }

  if (!dashboard) {
    return (
      <div className="admin-main">
        {error && <div className="admin-error-banner">{error}</div>}
      </div>
    );
  }

  const { api: apiStats, providers, database, symbols, symbol_data, groq, scheduler } = dashboard;
  const generated = new Date(dashboard.generated_at).toLocaleString();

  return (
    <div className="admin-shell">
      <header className="admin-header">
        <div>
          <h1>Admin Dashboard</h1>
          <p className="admin-header-meta">Updated {generated}</p>
        </div>
        <div className="admin-header-actions">
          <button type="button" className="admin-btn" onClick={() => void refresh()} disabled={refreshing}>
            {refreshing ? "Refreshing…" : "Refresh"}
          </button>
          <button type="button" className="admin-btn" onClick={signOut}>
            Sign out
          </button>
        </div>
      </header>

      <main className="admin-main">
        {error && <div className="admin-error-banner">{error}</div>}

        <section className="admin-grid admin-grid-4">
          <StatCard label="API requests (total)" value={apiStats.total_requests.toLocaleString()} />
          <StatCard label="API requests (last hour)" value={apiStats.requests_last_hour.toLocaleString()} />
          <StatCard label="DB size" value={database.database_size_human} />
          <StatCard label="Tracked symbols" value={symbols.tracked_count} />
        </section>

        <section className="admin-grid admin-grid-2">
          <div className="admin-panel">
            <h2>
              Provider health{" "}
              <span className={statusBadge(providers.status)}>{providers.status}</span>
            </h2>
            <ul className="admin-list">
              <li>
                <span>Finnhub configured</span>
                <span>{providers.finnhub_configured ? "Yes" : "No"}</span>
              </li>
              <li>
                <span>Massive configured</span>
                <span>{providers.massive_configured ? "Yes" : "No"}</span>
              </li>
              <li>
                <span>Est. Finnhub calls/min</span>
                <span>{providers.estimated_finnhub_calls_per_min}</span>
              </li>
              <li>
                <span>Massive rate limit/min</span>
                <span>{providers.massive_calls_per_min_limit}</span>
              </li>
              <li>
                <span>Quote ticks (last hour)</span>
                <span>{providers.quote_ticks_last_hour.toLocaleString()}</span>
              </li>
              <li>
                <span>Monitor tiers (hot / warm / cold)</span>
                <span>
                  {providers.tiers.hot} / {providers.tiers.warm} / {providers.tiers.cold}
                </span>
              </li>
            </ul>
            {(providers.stale_quotes.hot.length > 0 ||
              providers.stale_quotes.warm.length > 0 ||
              providers.stale_daily_bars.length > 0) && (
              <div style={{ marginTop: 16, fontSize: "0.8125rem", color: "var(--orange)" }}>
                {providers.stale_quotes.hot.length > 0 && (
                  <p>Stale hot quotes: {providers.stale_quotes.hot.join(", ")}</p>
                )}
                {providers.stale_quotes.warm.length > 0 && (
                  <p>Stale warm quotes: {providers.stale_quotes.warm.join(", ")}</p>
                )}
                {providers.stale_daily_bars.length > 0 && (
                  <p>Stale daily bars: {providers.stale_daily_bars.join(", ")}</p>
                )}
              </div>
            )}
          </div>

          <div className="admin-panel">
            <h2>
              Database{" "}
              <span className={database.healthy ? "admin-badge admin-badge-ok" : "admin-badge admin-badge-error"}>
                {database.healthy ? "healthy" : "error"}
              </span>
            </h2>
            <ul className="admin-list">
              <li>
                <span>Query latency</span>
                <span>{database.latency_ms != null ? `${database.latency_ms} ms` : "—"}</span>
              </li>
              <li>
                <span>Database size</span>
                <span>{database.database_size_human}</span>
              </li>
              <li>
                <span>Tables</span>
                <span>{database.tables.length}</span>
              </li>
            </ul>
            <div className="admin-table-wrap" style={{ marginTop: 16 }}>
              <table className="admin-table">
                <thead>
                  <tr>
                    <th>Table</th>
                    <th>Rows (est.)</th>
                    <th>Size</th>
                  </tr>
                </thead>
                <tbody>
                  {database.tables.map((t) => (
                    <tr key={t.table}>
                      <td>{t.table}</td>
                      <td className="mono">{t.rows.toLocaleString()}</td>
                      <td className="mono">{t.size_human}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </div>
        </section>

        <section className="admin-grid admin-grid-2">
          <div className="admin-panel">
            <h2>Symbol inventory</h2>
            <ul className="admin-list">
              <li>
                <span>Config tickers</span>
                <span>{symbols.config_ticker_count}</span>
              </li>
              <li>
                <span>Tracked (config + favorites)</span>
                <span>{symbols.tracked_count}</span>
              </li>
              <li>
                <span>DB tickers (active / inactive)</span>
                <span>
                  {symbols.active_ticker_count} / {symbols.inactive_ticker_count}
                </span>
              </li>
              <li>
                <span>Server favorites</span>
                <span>{symbols.favorites_count}</span>
              </li>
              <li>
                <span>Session favorites</span>
                <span>{symbols.session_favorites_count}</span>
              </li>
              <li>
                <span>Symbols with daily bars</span>
                <span>{symbols.symbols_with_daily_bars}</span>
              </li>
              <li>
                <span>Total daily bars</span>
                <span>{symbols.total_daily_bars.toLocaleString()}</span>
              </li>
              <li>
                <span>Total minute bars</span>
                <span>{symbols.total_minute_bars.toLocaleString()}</span>
              </li>
              <li>
                <span>Total snapshots</span>
                <span>{symbols.total_snapshots.toLocaleString()}</span>
              </li>
              <li>
                <span>Total quote ticks</span>
                <span>{symbols.total_quote_ticks.toLocaleString()}</span>
              </li>
            </ul>
          </div>

          <div className="admin-panel">
            <h2>Groq usage ({groq.day})</h2>
            <ul className="admin-list">
              <li>
                <span>Tokens used / budget</span>
                <span>
                  {groq.tokens_used.toLocaleString()} / {groq.tokens_budget.toLocaleString()}
                </span>
              </li>
              <li>
                <span>Tokens remaining</span>
                <span>{groq.tokens_remaining.toLocaleString()}</span>
              </li>
              <li>
                <span>Chat used / limit</span>
                <span>
                  {groq.chat_used} / {groq.chat_limit}
                </span>
              </li>
              <li>
                <span>Chat remaining</span>
                <span>{groq.chat_remaining}</span>
              </li>
            </ul>
            <h2 style={{ marginTop: 24 }}>Scheduler</h2>
            <ul className="admin-list">
              <li>
                <span>Running</span>
                <span>{scheduler.running ? "Yes" : "No"}</span>
              </li>
              <li>
                <span>Ingest warm-up complete</span>
                <span>{scheduler.ingest_warm_complete ? "Yes" : "No"}</span>
              </li>
              <li>
                <span>Scheduled jobs</span>
                <span>{scheduler.job_count}</span>
              </li>
            </ul>
          </div>
        </section>

        <section className="admin-grid admin-grid-2">
          <div className="admin-panel admin-span-2">
            <h2>API traffic — top paths (last hour)</h2>
            {apiStats.top_paths_last_hour.length === 0 ? (
              <p className="admin-empty">No API requests in the last hour.</p>
            ) : (
              <div className="admin-table-wrap">
                <table className="admin-table">
                  <thead>
                    <tr>
                      <th>Path</th>
                      <th>Requests</th>
                    </tr>
                  </thead>
                  <tbody>
                    {apiStats.top_paths_last_hour.map((row) => (
                      <tr key={row.path}>
                        <td className="mono">{row.path}</td>
                        <td className="mono">{row.count.toLocaleString()}</td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            )}
          </div>
        </section>

        <section className="admin-panel">
          <h2>Per-symbol data status</h2>
          <div className="admin-table-wrap">
            <table className="admin-table">
              <thead>
                <tr>
                  <th>Symbol</th>
                  <th>Daily bars</th>
                  <th>Last bar</th>
                  <th>Hot data</th>
                </tr>
              </thead>
              <tbody>
                {symbol_data.tickers.map((row) => (
                  <tr key={row.symbol}>
                    <td className="mono">{row.symbol}</td>
                    <td className="mono">{row.bar_count.toLocaleString()}</td>
                    <td className="mono">{row.last_bar_date ?? "—"}</td>
                    <td>{row.has_hot_data ? "Yes" : "No"}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </section>
      </main>
    </div>
  );
}

export function AdminView() {
  const [password, setPassword] = useState<string | null>(() => getStoredAdminPassword());

  if (!password) {
    return <AdminLogin onSuccess={setPassword} />;
  }

  return <AdminDashboard password={password} />;
}

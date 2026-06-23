import { useCallback, useEffect, useState } from "react";
import { ScrubbablePriceChart, type MonitorScrubDisplay } from "@/components/ScrubbablePriceChart";
import { ViewHeader } from "@/components/ViewHeader";
import type { Industry } from "@/data/industries";
import { displayName } from "@/data/industries";
import { useMonitorChartData } from "@/hooks/useMonitorChartData";
import { useMonitor } from "@/hooks/useMonitor";
import { api, type APIDashboard, type APIMonitorSymbol, type APITickerSearchResult, type MonitorTier } from "@/lib/api";
import { formatPct, formatPrice } from "@/lib/design-system";
import "./WatchlistView.css";

const TIER_META: Record<
  MonitorTier,
  { label: string; icon: string }
> = {
  hot: { label: "Hot · Live (~30s)", icon: "🔥" },
  warm: { label: "Warm · ~2 min", icon: "⏱" },
  cold: { label: "Background · ~5 min", icon: "🌙" },
};

interface WatchlistViewProps {
  active: boolean;
  industries: Industry[];
  dashboard: APIDashboard | null;
}

function symbolName(row: APIMonitorSymbol): string {
  return row.name?.trim() || displayName(row.symbol);
}

function MonitorRow({
  row,
  expanded,
  scrubDisplay,
  periodChangePct,
  onSelect,
}: {
  row: APIMonitorSymbol;
  expanded: boolean;
  scrubDisplay?: MonitorScrubDisplay | null;
  periodChangePct?: number | null;
  onSelect: () => void;
}) {
  const live = row.lag_seconds != null && row.lag_seconds < 90;
  const headerPrice = scrubDisplay ? formatPrice(scrubDisplay.price) : formatPrice(row.price);
  const headerSubLabel = scrubDisplay
    ? scrubDisplay.dateLabel
    : `Live · ${TIER_META[row.tier].label}`;
  const headerChange = scrubDisplay?.changePct ?? (expanded ? periodChangePct : row.change_1d_pct);

  return (
    <button
      type="button"
      className={`monitor-row ${expanded ? "selected expanded" : ""}`}
      onClick={onSelect}
    >
      <div className="monitor-row-symbol">
        <div className="monitor-row-ticker">
          {row.is_favorite && <span className="fav-star">★</span>}
          <span className="mono">{row.symbol}</span>
        </div>
        {symbolName(row) !== row.symbol && (
          <div className="monitor-row-name">{symbolName(row)}</div>
        )}
        {expanded && !scrubDisplay && (
          <div className="mono monitor-detail-sublabel">{headerSubLabel}</div>
        )}
      </div>
      {expanded ? (
        <div className="monitor-row-expanded-price mono">
          <div className="monitor-detail-price-large">{headerPrice}</div>
          {headerChange != null && (
            <div className={`monitor-detail-change ${headerChange >= 0 ? "positive" : "negative"}`}>
              {formatPct(headerChange, 2)}
            </div>
          )}
          {scrubDisplay && (
            <div className="monitor-detail-sublabel">{headerSubLabel}</div>
          )}
        </div>
      ) : (
        <>
          <div className="monitor-row-price mono">
            <div>{formatPrice(row.price)}</div>
            <div className={row.change_1d_pct >= 0 ? "positive" : "negative"}>
              {formatPct(row.change_1d_pct)}
            </div>
          </div>
          {row.change_5m_pct != null ? (
            <div className="monitor-row-5m mono">
              <span className="monitor-5m-label">5m</span>
              <span className={row.change_5m_pct >= 0 ? "positive" : "negative"}>
                {formatPct(row.change_5m_pct, 1)}
              </span>
            </div>
          ) : (
            <div className="monitor-row-5m monitor-row-5m-empty" />
          )}
        </>
      )}
      <span className={`monitor-live-dot ${live ? "live" : ""}`} title={live ? "Fresh quote" : "Stale"}>
        ●
      </span>
      <span className="monitor-row-chevron" aria-hidden>
        {expanded ? "▴" : "▾"}
      </span>
    </button>
  );
}

function MonitorDetail({
  row,
  chartRange,
  onChartRangeChange,
  bars,
  chartLoading,
  chartError,
  onScrub,
  onRemove,
}: {
  row: APIMonitorSymbol;
  chartRange: ReturnType<typeof useMonitorChartData>["range"];
  onChartRangeChange: ReturnType<typeof useMonitorChartData>["setRange"];
  bars: ReturnType<typeof useMonitorChartData>["bars"];
  chartLoading: boolean;
  chartError: string | null;
  onScrub: (display: MonitorScrubDisplay | null) => void;
  onRemove?: () => void;
}) {
  return (
    <div className="monitor-detail monitor-detail-inline">
      <ScrubbablePriceChart
        bars={bars}
        range={chartRange}
        onRangeChange={onChartRangeChange}
        loading={chartLoading}
        error={chartError}
        onScrub={onScrub}
      />

      <div className="monitor-detail-stats">
        <div className="stat-box">
          <span className="stat-label">1D</span>
          <span className={`mono ${row.change_1d_pct >= 0 ? "positive" : "negative"}`}>
            {formatPct(row.change_1d_pct)}
          </span>
        </div>
        {row.change_5m_pct != null && (
          <div className="stat-box">
            <span className="stat-label">5M</span>
            <span className={`mono ${row.change_5m_pct >= 0 ? "positive" : "negative"}`}>
              {formatPct(row.change_5m_pct, 1)}
            </span>
          </div>
        )}
        {row.change_15m_pct != null && (
          <div className="stat-box">
            <span className="stat-label">15M</span>
            <span className={`mono ${row.change_15m_pct >= 0 ? "positive" : "negative"}`}>
              {formatPct(row.change_15m_pct, 1)}
            </span>
          </div>
        )}
        <div className="stat-box">
          <span className="stat-label">30D</span>
          <span className={`mono ${row.change_30d_pct >= 0 ? "positive" : "negative"}`}>
            {formatPct(row.change_30d_pct, 1)}
          </span>
        </div>
      </div>

      <div className="monitor-detail-meta mono">
        {TIER_META[row.tier].icon} {TIER_META[row.tier].label}
        {row.quote_source ? ` · ${row.quote_source}` : ""}
      </div>
      {onRemove && (
        <button type="button" className="remove-fav-btn" onClick={onRemove}>
          Remove from favorites
        </button>
      )}
    </div>
  );
}

export function WatchlistView({ active, industries, dashboard }: WatchlistViewProps) {
  const {
    hot,
    warm,
    cold,
    focusSectorId,
    favoriteCount,
    favoriteLimit,
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
  } = useMonitor(active);

  const [query, setQuery] = useState("");
  const [results, setResults] = useState<APITickerSearchResult[]>([]);
  const [searching, setSearching] = useState(false);
  const [selected, setSelected] = useState<string | null>(null);
  const [focusOpen, setFocusOpen] = useState(false);
  const [scrubDisplay, setScrubDisplay] = useState<MonitorScrubDisplay | null>(null);

  const {
    range: chartRange,
    setRange: setChartRange,
    bars: chartBars,
    loading: chartLoading,
    error: chartError,
    periodChangePct,
  } = useMonitorChartData(selected, dashboard);

  const allRows = [...hot, ...warm, ...cold];
  const selectedRow = allRows.find((r) => r.symbol === selected) ?? null;

  useEffect(() => {
    setScrubDisplay(null);
  }, [selected, chartRange]);

  const focusLabel =
    focusSectorId != null
      ? industries.find((i) => i.id === focusSectorId)?.name ?? "Focus sector"
      : "Set focus sector";

  const search = useCallback(async (q: string) => {
    if (q.trim().length < 1) {
      setResults([]);
      return;
    }
    setSearching(true);
    try {
      const r = await api.search(q);
      setResults(r.slice(0, 8));
    } catch {
      setResults([]);
    } finally {
      setSearching(false);
    }
  }, []);

  useEffect(() => {
    const t = setTimeout(() => void search(query), 300);
    return () => clearTimeout(t);
  }, [query, search]);

  const isSearching = query.trim().length > 0;
  const isFavorite = (sym: string) =>
    allRows.some((r) => r.symbol === sym.toUpperCase() && r.is_favorite);

  const toggleSelection = (symbol: string) => {
    setSelected((current) => (current === symbol ? null : symbol));
    setScrubDisplay(null);
  };

  const renderTier = (tier: MonitorTier, rows: APIMonitorSymbol[]) => {
    if (rows.length === 0) return null;
    const meta = TIER_META[tier];
    const isExpandedRow = (sym: string) => selected === sym;
    return (
      <section key={tier} className="monitor-tier" data-tier={tier}>
        <h3 className="monitor-tier-label">
          <span>{meta.icon}</span> {meta.label}
        </h3>
        {rows.map((row) => (
          <div
            key={row.symbol}
            id={`monitor-row-${row.symbol}`}
            className={`monitor-accordion-item ${isExpandedRow(row.symbol) ? "expanded" : ""}`}
          >
            <MonitorRow
              row={row}
              expanded={isExpandedRow(row.symbol)}
              scrubDisplay={isExpandedRow(row.symbol) ? scrubDisplay : null}
              periodChangePct={isExpandedRow(row.symbol) ? periodChangePct : null}
              onSelect={() => toggleSelection(row.symbol)}
            />
            {isExpandedRow(row.symbol) && selectedRow?.symbol === row.symbol && (
              <MonitorDetail
                row={row}
                chartRange={chartRange}
                onChartRangeChange={setChartRange}
                bars={chartBars}
                chartLoading={chartLoading}
                chartError={chartError}
                onScrub={setScrubDisplay}
                onRemove={
                  row.is_favorite
                    ? () =>
                        void removeFavorite(row.symbol).then(() => {
                          setSelected(null);
                          setScrubDisplay(null);
                        })
                    : undefined
                }
              />
            )}
          </div>
        ))}
      </section>
    );
  };

  return (
    <div className="watchlist-view monitor-view">
      <ViewHeader
        title="Monitor"
        live
        liveLabel={liveLabel}
        onRefresh={() => void sync(true)}
        refreshing={refreshing}
      />

      <div className="monitor-toolbar">
        <span className="mono monitor-fav-count">
          Favorites {favoriteCount}/{favoriteLimit}
        </span>
        <div className="monitor-focus-wrap">
          <button
            type="button"
            className="monitor-focus-btn mono"
            onClick={() => setFocusOpen((o) => !o)}
            disabled={focusPending}
          >
            ◎ {focusLabel} ▾
          </button>
          {focusOpen && (
            <div className="monitor-focus-menu">
              <button
                type="button"
                onClick={() => {
                  void setFocusSector(null);
                  setFocusOpen(false);
                }}
              >
                No sector focus
              </button>
              {industries.map((ind) => (
                <button
                  key={ind.id}
                  type="button"
                  className={focusSectorId === ind.id ? "active" : ""}
                  onClick={() => {
                    void setFocusSector(ind.id);
                    setFocusOpen(false);
                  }}
                >
                  {ind.name}
                </button>
              ))}
            </div>
          )}
        </div>
      </div>

      {error && <div className="monitor-error mono">{error}</div>}
      {isAtFavoriteLimit && (
        <div className="monitor-limit-banner mono">
          Favorite limit reached. Remove one to add another.
        </div>
      )}

      <div className="view-section">
        <div className="search-box">
          <input
            type="search"
            placeholder="Search tickers to add…"
            value={query}
            onChange={(e) => setQuery(e.target.value)}
            className="search-input"
          />
          {searching && <span className="search-status mono">Searching…</span>}
        </div>

        {isSearching && results.length > 0 && (
          <div className="search-results">
            {results.map((r) => (
              <div key={r.symbol} className="search-result-row">
                <div>
                  <span className="mono search-symbol">{r.symbol}</span>
                  <span className="search-name">{r.name}</span>
                </div>
                <button
                  type="button"
                  className={`fav-btn ${isFavorite(r.symbol) ? "added" : ""}`}
                  onClick={() => void addFavorite(r.symbol, r.name)}
                  disabled={isFavorite(r.symbol) || isAtFavoriteLimit}
                >
                  {isFavorite(r.symbol) ? "✓" : "+"}
                </button>
              </div>
            ))}
          </div>
        )}

        {!isSearching && topMovers.length > 0 && (
          <section className="monitor-movers">
            <h3 className="monitor-tier-label">Top 5m movers (Hot + Warm)</h3>
            <div className="monitor-movers-list">
              {topMovers.map((row) => (
                <button
                  key={row.symbol}
                  type="button"
                  className="monitor-mover-chip mono"
                  onClick={() => {
                    setSelected(row.symbol);
                    setScrubDisplay(null);
                    document.getElementById(`monitor-row-${row.symbol}`)?.scrollIntoView({ behavior: "smooth", block: "start" });
                  }}
                >
                  <span>{row.symbol}</span>
                  <span className={row.change_5m_pct! >= 0 ? "positive" : "negative"}>
                    {formatPct(row.change_5m_pct!, 1)}
                  </span>
                </button>
              ))}
            </div>
          </section>
        )}

        {!isSearching && (
          <div className="monitor-tiers">
            {loading && allRows.length === 0 ? (
              <div className="empty-hint">Loading monitor…</div>
            ) : (
              <>
                {renderTier("hot", hot)}
                {renderTier("warm", warm)}
                {renderTier("cold", cold)}
                {allRows.length === 0 && !loading && (
                  <div className="empty-hint">No symbols in monitor. Check API connection.</div>
                )}
              </>
            )}
          </div>
        )}
      </div>
    </div>
  );
}

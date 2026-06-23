import { MarketChartSections } from "@/components/MarketChartSections";
import { SPCard } from "@/components/SPCard";
import { SectionLabel } from "@/components/SectionLabel";
import { TrendChart } from "@/components/TrendChart";
import { ViewHeader } from "@/components/ViewHeader";
import type { Catalyst } from "@/data/catalysts";
import type { Industry } from "@/data/industries";
import { useTrendRangeData } from "@/hooks/useTrendRangeData";
import type { APIDashboard, APISnapshot } from "@/lib/api";
import { barCloses } from "@/lib/api";
import {
  alignTrendBars,
  barsForTrendRange,
  TREND_RANGE_LABELS,
  TREND_RANGES,
  trendRangeIsIntraday,
} from "@/lib/trendRange";
import { chartColors, findEventDayIndex, formatPct } from "@/lib/design-system";
import "./TrendsView.css";

interface TrendsViewProps {
  dashboard: APIDashboard | null;
  snapshots: Map<string, APISnapshot>;
  industries: Industry[];
  industryAccentHex: Record<string, string>;
  catalysts: Catalyst[];
  usesLiveData: boolean;
  dataThroughLabel: string;
  refreshing: boolean;
  onRefresh: () => void;
}

export function TrendsView({
  dashboard,
  snapshots,
  industries,
  industryAccentHex,
  catalysts,
  usesLiveData,
  dataThroughLabel,
  refreshing,
  onRefresh,
}: TrendsViewProps) {
  const { range, setRange, fetchedBars, loading, fetchError, dashboardBarsFor } =
    useTrendRangeData(dashboard, catalysts);
  const rangeLabel = TREND_RANGE_LABELS[range];
  const intraday = trendRangeIsIntraday(range);

  return (
    <div className="trends-view">
      <ViewHeader
        title="Trends"
        live={usesLiveData}
        liveLabel={usesLiveData ? dataThroughLabel : undefined}
        onRefresh={onRefresh}
        refreshing={refreshing}
      />

      <MarketChartSections
        dashboard={dashboard}
        snapshots={snapshots}
        industries={industries}
        industryAccentHex={industryAccentHex}
        catalysts={catalysts}
      />

      <SectionLabel text="Compare Trends" />

      <div className="trends-range-row">
        {TREND_RANGES.map((r) => (
          <button
            key={r}
            type="button"
            className={`trends-range-btn mono ${range === r ? "active" : ""}`}
            onClick={() => setRange(r)}
          >
            {TREND_RANGE_LABELS[r]}
          </button>
        ))}
        {loading && <span className="trends-range-loading mono">Loading…</span>}
      </div>

      {fetchError && range !== "1D" && (
        <div className="trends-range-error mono">{fetchError}</div>
      )}

      <div className="view-section">
        {catalysts.map((c) => {
          const tickers = [c.ticker, ...c.ripples.map((r) => r.ticker)];
          const barsByTicker: Record<string, ReturnType<typeof dashboardBarsFor>> = {};

          for (const t of tickers) {
            barsByTicker[t] = barsForTrendRange(
              range,
              t,
              dashboardBarsFor(t),
              fetchedBars,
            );
          }

          const { aligned, dates } = alignTrendBars(tickers, barsByTicker);
          const series: Record<string, number[]> = {};
          for (const t of tickers) {
            series[t] = barCloses(aligned[t] ?? []);
          }

          const eventDay = findEventDayIndex(dates, c.eventDate);

          return (
            <SPCard key={c.ticker} className="trends-card">
              <div className="trends-card-header">
                <div className="mono trends-title">
                  {c.ticker} Ripple Network — {c.eventName}
                </div>
                <div className="trends-subtitle">
                  All lines = % change from start of {rangeLabel} range. See Ripple tab for
                  individual analysis.
                </div>
              </div>
              <div className="trends-chart-wrap">
                <TrendChart
                  tickers={tickers}
                  series={series}
                  dates={dates}
                  colors={chartColors}
                  eventDay={eventDay}
                  rangeLabel={rangeLabel}
                  intraday={intraday}
                  height={220}
                />
              </div>
              <div className="trends-summary">
                {tickers.map((t, i) => {
                  const h = series[t];
                  if (!h || h.length < 2) return null;
                  const chgAll = ((h[h.length - 1] - h[0]) / h[0]) * 100;
                  const evIdx = eventDay ?? 0;
                  const chgPost =
                    evIdx < h.length ? ((h[h.length - 1] - h[evIdx]) / h[evIdx]) * 100 : 0;
                  const col = chartColors[i % chartColors.length];
                  return (
                    <div key={t} className="trends-summary-item" style={{ borderTopColor: col }}>
                      <div className="mono trends-summary-ticker" style={{ color: col }}>
                        {t}
                      </div>
                      <div className="trends-summary-pct">
                        {rangeLabel}:{" "}
                        <span className={chgAll >= 0 ? "positive" : "negative"}>
                          {formatPct(chgAll)}
                        </span>
                      </div>
                      <div className="trends-summary-pct">
                        post-event:{" "}
                        <span className={chgPost >= 0 ? "positive" : "negative"}>
                          {formatPct(chgPost)}
                        </span>
                      </div>
                    </div>
                  );
                })}
              </div>
            </SPCard>
          );
        })}
      </div>
    </div>
  );
}

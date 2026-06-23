import { useState } from "react";
import { MarketChartSections } from "@/components/MarketChartSections";
import { SPCard } from "@/components/SPCard";
import { SectionLabel } from "@/components/SectionLabel";
import { TrendChart } from "@/components/TrendChart";
import { ViewHeader } from "@/components/ViewHeader";
import type { Catalyst, MarketEvent } from "@/data/catalysts";
import type { Industry } from "@/data/industries";
import { useTrendRangeData } from "@/hooks/useTrendRangeData";
import type { APIDashboard, APISnapshot } from "@/lib/api";
import { barCloses, barDates } from "@/lib/api";
import {
  alignTrendBars,
  barsForTrendRange,
  TREND_RANGE_LABELS,
  TREND_RANGES,
  trendRangeIsIntraday,
} from "@/lib/trendRange";
import { chartColors, findEventDayIndex, formatDateShort, formatPct, parseVerdict } from "@/lib/design-system";
import { Sparkline } from "@/components/Sparkline";
import { VerdictBadge } from "@/components/VerdictBadge";
import "./RippleView.css";
import "./TrendsView.css";

interface PulseViewProps {
  dashboard: APIDashboard | null;
  snapshots: Map<string, APISnapshot>;
  industries: Industry[];
  industryAccentHex: Record<string, string>;
  catalysts: Catalyst[];
  keyEvents: MarketEvent[];
  usesLiveData: boolean;
  dataThroughLabel: string;
  refreshing: boolean;
  onRefresh: () => void;
}

export function PulseView({
  dashboard,
  snapshots,
  industries,
  industryAccentHex,
  catalysts,
  keyEvents,
  usesLiveData,
  dataThroughLabel,
  refreshing,
  onRefresh,
}: PulseViewProps) {
  const [selectedCatalyst, setSelectedCatalyst] = useState(0);
  const [compareAllExpanded, setCompareAllExpanded] = useState(false);
  const { range, setRange, fetchedBars, loading, fetchError, dashboardBarsFor } =
    useTrendRangeData(dashboard, catalysts);
  const rangeLabel = TREND_RANGE_LABELS[range];
  const intraday = trendRangeIsIntraday(range);

  const safeIndex = catalysts.length > 0 ? Math.min(selectedCatalyst, catalysts.length - 1) : 0;
  const catalyst = catalysts[safeIndex];

  if (!catalyst) {
    return (
      <div className="view-root">
        <ViewHeader title="Pulse" live={usesLiveData} liveLabel={dataThroughLabel} />
        <div className="empty-hint">No catalysts loaded.</div>
      </div>
    );
  }

  const rippleResults = dashboard?.ripple_results[catalyst.ticker] ?? [];
  const catBars = dashboard?.histories[catalyst.ticker] ?? dashboard?.histories_extended[catalyst.ticker] ?? [];
  const catCloses = barCloses(catBars);
  const catDates = barDates(catBars);
  const eventDayIdx = findEventDayIndex(catDates, catalyst.eventDate);
  const postEventPct =
    eventDayIdx != null && catCloses.length > 0
      ? ((catCloses[catCloses.length - 1] - catCloses[eventDayIdx]) / catCloses[eventDayIdx]) * 100
      : null;

  return (
    <div className="ripple-view pulse-view">
      <ViewHeader
        title="Pulse"
        subtitle="Market context · catalyst networks · verification"
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

      <SectionLabel text="Chart Range" />

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
        <SPCard className="key-events-bar">
          <SectionLabel text="Key Events" />
          <div className="key-events-list">
            {keyEvents.map((ev) => (
              <div key={`${ev.date}-${ev.label}`} className="key-event">
                <span className="key-event-dot" style={{ background: ev.color }} />
                <span className="key-event-date mono" style={{ color: ev.color }}>
                  {formatDateShort(ev.date)}
                </span>
                <span className="key-event-label">{ev.label}</span>
              </div>
            ))}
          </div>
        </SPCard>

        <div className="catalyst-selector">
          {catalysts.map((c, i) => {
            const bars = dashboard?.histories[c.ticker] ?? dashboard?.histories_extended[c.ticker] ?? [];
            const closes = barCloses(bars);
            const dates = barDates(bars);
            const evIdx = findEventDayIndex(dates, c.eventDate);
            const chg =
              evIdx != null && closes.length > 0
                ? ((closes[closes.length - 1] - closes[evIdx]) / closes[evIdx]) * 100
                : null;

            return (
              <SPCard
                key={c.ticker}
                className={`catalyst-card ${selectedCatalyst === i ? "selected" : ""}`}
                onClick={() => setSelectedCatalyst(i)}
              >
                <div className="catalyst-card-header">
                  <span className="catalyst-ticker mono">{c.ticker}</span>
                  {chg != null && (
                    <span className="catalyst-chg mono positive">+{chg.toFixed(1)}% post-event</span>
                  )}
                </div>
                <div className="catalyst-event">{c.eventName}</div>
                <div className="catalyst-meta">{c.ripples.length} tracked ripple stocks</div>
              </SPCard>
            );
          })}
        </div>

        <SPCard className="ripple-panel">
          <div className="ripple-panel-header">
            <div>
              <div className="ripple-catalyst-title mono">
                {catalyst.ticker} — {catalyst.eventName}
              </div>
              {postEventPct != null && (
                <div className="ripple-post-event mono positive">
                  Catalyst +{postEventPct.toFixed(1)}% since event
                </div>
              )}
            </div>
            {catCloses.length > 1 && (
              <Sparkline
                data={catCloses}
                color="#f59e0b"
                width={140}
                height={40}
                eventDay={eventDayIdx}
                showArea
              />
            )}
          </div>

          <SectionLabel text="Ripple Verification" />

          <div className="ripple-grid-header">
            <span>Ripple</span>
            <span>Verdict</span>
            <span>Pre</span>
            <span>Post</span>
            <span>Trend</span>
          </div>

          {catalyst.ripples.map((rip, i) => {
            const result = rippleResults.find((r) => r.ripple_ticker === rip.ticker);
            const bars = dashboard?.histories[rip.ticker] ?? dashboard?.histories_extended[rip.ticker] ?? [];
            const closes = barCloses(bars);
            const dates = barDates(bars);
            const evIdx = findEventDayIndex(dates, catalyst.eventDate);
            const color = chartColors[(i + 1) % chartColors.length];

            return (
              <div key={rip.ticker} className="ripple-row">
                <div>
                  <div className="ripple-ticker mono">{rip.ticker}</div>
                  <div className="ripple-desc">{rip.description}</div>
                </div>
                <div>
                  {result ? (
                    <VerdictBadge verdict={parseVerdict(result.verdict)} />
                  ) : (
                    <VerdictBadge verdict="WATCHING" />
                  )}
                </div>
                <div className="mono ripple-pct">
                  {result ? formatPct(result.pre_event_pct) : "—"}
                </div>
                <div className={`mono ripple-pct ${result && result.post_event_pct >= 0 ? "positive" : "negative"}`}>
                  {result ? formatPct(result.post_event_pct) : "—"}
                </div>
                <div>
                  {closes.length > 1 && (
                    <Sparkline data={closes} color={color} width={100} height={32} eventDay={evIdx} />
                  )}
                </div>
              </div>
            );
          })}
        </SPCard>

        <button
          type="button"
          className="pulse-compare-toggle"
          onClick={() => setCompareAllExpanded((v) => !v)}
        >
          <SectionLabel text="Compare All Networks" />
          <span className="pulse-compare-chevron">{compareAllExpanded ? "▲" : "▼"}</span>
        </button>

        {compareAllExpanded &&
          catalysts.map((c) => {
            const tickers = [c.ticker, ...c.ripples.map((r) => r.ticker)];
            const barsByTicker: Record<string, ReturnType<typeof dashboardBarsFor>> = {};

            for (const t of tickers) {
              barsByTicker[t] = barsForTrendRange(range, t, dashboardBarsFor(t), fetchedBars);
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
                    All lines = % change from start of {rangeLabel} range.
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

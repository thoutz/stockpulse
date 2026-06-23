import { useState } from "react";
import { SPCard } from "@/components/SPCard";
import { SectionLabel } from "@/components/SectionLabel";
import { Sparkline } from "@/components/Sparkline";
import { VerdictBadge } from "@/components/VerdictBadge";
import { ViewHeader } from "@/components/ViewHeader";
import type { Catalyst, MarketEvent } from "@/data/catalysts";
import type { APIDashboard } from "@/lib/api";
import { barCloses, barDates } from "@/lib/api";
import { formatDateShort, formatPct, findEventDayIndex, parseVerdict } from "@/lib/design-system";
import { chartColors } from "@/lib/design-system";
import "./RippleView.css";

interface RippleViewProps {
  dashboard: APIDashboard | null;
  catalysts: Catalyst[];
  keyEvents: MarketEvent[];
  usesLiveData: boolean;
  dataThroughLabel: string;
  refreshing: boolean;
  onRefresh: () => void;
}

export function RippleView({
  dashboard,
  catalysts,
  keyEvents,
  usesLiveData,
  dataThroughLabel,
  refreshing,
  onRefresh,
}: RippleViewProps) {
  const [selectedCatalyst, setSelectedCatalyst] = useState(0);
  const safeIndex = catalysts.length > 0 ? Math.min(selectedCatalyst, catalysts.length - 1) : 0;
  const catalyst = catalysts[safeIndex];
  const events = keyEvents;

  if (!catalyst) {
    return (
      <div className="view-root">
        <ViewHeader title="Ripple" live={usesLiveData} liveLabel={dataThroughLabel} />
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
    <div className="ripple-view">
      <ViewHeader
        title="Ripple Tracker"
        live={usesLiveData}
        liveLabel={usesLiveData ? dataThroughLabel : undefined}
        onRefresh={onRefresh}
        refreshing={refreshing}
      />

      <div className="view-section">
        <SPCard className="key-events-bar">
          <SectionLabel text="Key Events" />
          <div className="key-events-list">
            {events.map((ev) => (
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
      </div>
    </div>
  );
}

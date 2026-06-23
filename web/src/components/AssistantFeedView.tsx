import { useEffect, useMemo, useState } from "react";
import { StructuredReportBody } from "@/components/HighlightedReportText";
import type { APIAlert, APIReport } from "@/lib/api";
import {
  type AnalysisSection,
  type DigestDay,
  type DigestRange,
  DIGEST_RANGE_LABELS,
  alertDaysInRange,
  daySectionLabel,
  digestDaysInRange,
  reportDaysInRange,
  reportEmptyMessage,
  sessionGroupsForDay,
  timeOnly,
  aiStamp,
} from "@/lib/digest";
import "./AssistantFeedView.css";

interface AssistantFeedViewProps {
  digestDays: DigestDay[];
  digestRange: DigestRange;
  onDigestRangeChange: (range: DigestRange) => void;
  analysisSection: AnalysisSection;
  onAnalysisSectionChange: (section: AnalysisSection) => void;
  isSyncing: boolean;
  error: string | null;
}

export function AssistantFeedView({
  digestDays,
  digestRange,
  onDigestRangeChange,
  analysisSection,
  onAnalysisSectionChange,
  isSyncing,
  error,
}: AssistantFeedViewProps) {
  const [rangeOpen, setRangeOpen] = useState(false);
  const [expandedAlertDays, setExpandedAlertDays] = useState<Set<string>>(new Set());
  const [expandedReportDays, setExpandedReportDays] = useState<Set<string>>(new Set());
  const [collapsedReportSlots, setCollapsedReportSlots] = useState<Set<string>>(new Set());

  const daysInRange = useMemo(
    () => digestDaysInRange(digestDays, digestRange),
    [digestDays, digestRange],
  );

  const alertDays = useMemo(() => alertDaysInRange(daysInRange), [daysInRange]);
  const reportDays = useMemo(
    () => reportDaysInRange(daysInRange, digestRange),
    [daysInRange, digestRange],
  );

  useEffect(() => {
    const firstAlert = alertDays[0]?.date;
    const firstReport = reportDays[0]?.date;
    if (firstAlert) setExpandedAlertDays(new Set([firstAlert]));
    if (firstReport) setExpandedReportDays(new Set([firstReport]));
  }, [digestRange, alertDays, reportDays]);

  const rangeLabel = DIGEST_RANGE_LABELS[digestRange];

  return (
    <div className="assistant-feed-view">
      <div className="feed-controls">
        <div className="range-dropdown">
          <button
            type="button"
            className="range-menu-btn"
            onClick={() => setRangeOpen((o) => !o)}
            aria-expanded={rangeOpen}
          >
            <span className="mono">{rangeLabel}</span>
            <span className="range-chevron">▾</span>
          </button>
          {rangeOpen && (
            <div className="range-menu">
              {([1, 3, 7] as DigestRange[]).map((r) => (
                <button
                  key={r}
                  type="button"
                  className={`range-menu-item ${digestRange === r ? "active" : ""}`}
                  onClick={() => {
                    onDigestRangeChange(r);
                    setRangeOpen(false);
                  }}
                >
                  {DIGEST_RANGE_LABELS[r]}
                </button>
              ))}
            </div>
          )}
        </div>
        {isSyncing && <span className="feed-sync-spinner" aria-label="Syncing" />}
      </div>

      <div className="section-tabs">
        {(["reports", "alerts"] as AnalysisSection[]).map((section) => (
          <button
            key={section}
            type="button"
            className={`section-tab ${analysisSection === section ? "active" : ""}`}
            onClick={() => onAnalysisSectionChange(section)}
          >
            {section === "reports" ? "Reports" : "Alerts"}
          </button>
        ))}
      </div>

      {error && <div className="feed-error">{error}</div>}

      {analysisSection === "alerts" ? (
        alertDays.length === 0 && !isSyncing ? (
          <div className="feed-empty">No alerts in the last {rangeLabel}.</div>
        ) : (
          <div className="day-sections">
            {alertDays.map((day) => (
              <DayDisclosure
                key={day.date}
                label={daySectionLabel(day.date)}
                count={day.alerts.length}
                countClass="alert-count"
                tint="orange"
                expanded={expandedAlertDays.has(day.date)}
                onToggle={(open) => {
                  setExpandedAlertDays((prev) => {
                    const next = new Set(prev);
                    if (open) next.add(day.date);
                    else next.delete(day.date);
                    return next;
                  });
                }}
              >
                {day.alerts.map((alert) => (
                  <AlertRow key={alert.id} alert={alert} />
                ))}
              </DayDisclosure>
            ))}
          </div>
        )
      ) : reportDays.every((d) =>
          sessionGroupsForDay(d).every((g) => g.reports.length === 0),
        ) && !isSyncing ? (
        <div className="feed-empty">{reportEmptyMessage(reportDays, rangeLabel)}</div>
      ) : (
        <div className="day-sections">
          {reportDays.map((day) => {
            const slots = sessionGroupsForDay(day);
            const filledCount = slots.filter((s) => s.reports.length > 0).length;
            return (
              <DayDisclosure
                key={day.date}
                label={daySectionLabel(day.date)}
                countLabel={`${filledCount}/3`}
                countClass="report-count"
                tint="blue"
                expanded={expandedReportDays.has(day.date)}
                onToggle={(open) => {
                  setExpandedReportDays((prev) => {
                    const next = new Set(prev);
                    if (open) next.add(day.date);
                    else next.delete(day.date);
                    return next;
                  });
                }}
              >
                {slots.map((group) => (
                  <SlotDisclosure
                    key={group.id}
                    group={group}
                    expanded={!collapsedReportSlots.has(group.id)}
                    onToggle={(open) => {
                      setCollapsedReportSlots((prev) => {
                        const next = new Set(prev);
                        if (open) next.delete(group.id);
                        else next.add(group.id);
                        return next;
                      });
                    }}
                  />
                ))}
              </DayDisclosure>
            );
          })}
        </div>
      )}
    </div>
  );
}

function DayDisclosure({
  label,
  count,
  countLabel,
  countClass,
  tint,
  expanded,
  onToggle,
  children,
}: {
  label: string;
  count?: number;
  countLabel?: string;
  countClass: string;
  tint: "orange" | "blue";
  expanded: boolean;
  onToggle: (open: boolean) => void;
  children: React.ReactNode;
}) {
  return (
    <details
      className={`day-disclosure tint-${tint}`}
      open={expanded}
      onToggle={(e) => onToggle((e.target as HTMLDetailsElement).open)}
    >
      <summary className="day-disclosure-summary">
        <span className="day-label">{label}</span>
        <span className={`day-count ${countClass}`}>{countLabel ?? count}</span>
      </summary>
      <div className="day-disclosure-body">{children}</div>
    </details>
  );
}

function SlotDisclosure({
  group,
  expanded,
  onToggle,
}: {
  group: ReturnType<typeof sessionGroupsForDay>[number];
  expanded: boolean;
  onToggle: (open: boolean) => void;
}) {
  const latest = group.reports[0];
  return (
    <details
      className="slot-disclosure"
      open={expanded}
      onToggle={(e) => onToggle((e.target as HTMLDetailsElement).open)}
    >
      <summary className="slot-summary">
        <div>
          <div className="slot-label">{group.slot.label}</div>
          <div className="slot-subtitle mono">{group.slot.subtitle}</div>
        </div>
        {latest && <span className="slot-time mono">{timeOnly(latest.created_at)}</span>}
      </summary>
      <div className="slot-body">
        {group.reports.length === 0 ? (
          <div className="slot-pending">Scheduled · not generated yet</div>
        ) : (
          group.reports.map((report) => <ReportRow key={report.id} report={report} />)
        )}
      </div>
    </details>
  );
}

function AlertRow({ alert }: { alert: APIAlert }) {
  const positive = alert.change_pct >= 0;
  return (
    <div className="alert-row">
      <span className={`alert-bell ${positive ? "positive" : "negative"}`}>🔔</span>
      <div className="alert-content">
        <div className="alert-header">
          <span className="mono alert-symbol">
            {alert.symbol} {positive ? "+" : ""}
            {alert.change_pct.toFixed(1)}%
          </span>
          <span className="mono alert-time">{timeOnly(alert.created_at)}</span>
        </div>
        <div className="alert-message">{alert.message}</div>
      </div>
    </div>
  );
}

function ReportRow({ report }: { report: APIReport }) {
  return (
    <div className="report-row">
      <div className="report-row-header">
        <span className="report-title">{report.title}</span>
        <span className="mono report-stamp">{aiStamp(report.created_at)}</span>
      </div>
      <StructuredReportBody bodyText={report.body} />
    </div>
  );
}

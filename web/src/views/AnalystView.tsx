import { useCallback, useEffect, useState } from "react";
import { AssistantFeedView } from "@/components/AssistantFeedView";
import { MarketTabReportBody } from "@/components/HighlightedReportText";
import { SectionLabel } from "@/components/SectionLabel";
import { ViewHeader } from "@/components/ViewHeader";
import { reportBodyText, useMarketBriefs } from "@/hooks/useMarketBriefs";
import { api, type APIDigestDay } from "@/lib/api";
import {
  type AnalysisSection,
  type DigestDay,
  type DigestRange,
  lastNDayKeys,
} from "@/lib/digest";
import "./MarketView.css";

interface AnalystViewProps {
  active: boolean;
  usesLiveData: boolean;
  dataThroughLabel: string;
  refreshing: boolean;
  onRefresh: () => void;
}

function formatStamp(iso: string): string {
  try {
    return new Date(iso).toLocaleString(undefined, {
      month: "short",
      day: "numeric",
      hour: "numeric",
      minute: "2-digit",
    });
  } catch {
    return iso;
  }
}

function toDigestDays(days: APIDigestDay[]): DigestDay[] {
  return days.map((d) => ({
    date: d.date,
    reports: d.reports ?? [],
    alerts: d.alerts ?? [],
    suggestions: d.suggestions ?? [],
  }));
}

function buildDigestFromParts(
  reports: Awaited<ReturnType<typeof api.reports>>,
  alerts: Awaited<ReturnType<typeof api.alerts>>,
  suggestions: Awaited<ReturnType<typeof api.suggestions>>,
): DigestDay[] {
  const keys = lastNDayKeys(7);
  const byDay: Record<string, DigestDay> = {};
  for (const key of keys) {
    byDay[key] = { date: key, reports: [], alerts: [], suggestions: [] };
  }

  const dayKey = (iso: string) => {
    const d = new Date(iso);
    return d.toLocaleDateString("en-CA", { timeZone: "America/New_York" });
  };

  for (const r of reports) {
    const k = dayKey(r.created_at);
    if (byDay[k]) byDay[k].reports.push(r);
  }
  for (const a of alerts) {
    const k = dayKey(a.created_at);
    if (byDay[k]) byDay[k].alerts.push(a);
  }
  for (const s of suggestions) {
    const k = dayKey(s.created_at);
    if (byDay[k]) byDay[k].suggestions.push(s);
  }

  return keys.map((k) => ({
    ...byDay[k],
    reports: byDay[k].reports.sort(
      (a, b) => new Date(b.created_at).getTime() - new Date(a.created_at).getTime(),
    ),
    alerts: byDay[k].alerts.sort(
      (a, b) => new Date(b.created_at).getTime() - new Date(a.created_at).getTime(),
    ),
    suggestions: byDay[k].suggestions.sort(
      (a, b) => new Date(b.created_at).getTime() - new Date(a.created_at).getTime(),
    ),
  }));
}

export function AnalystView({
  active,
  usesLiveData,
  dataThroughLabel,
  refreshing,
  onRefresh,
}: AnalystViewProps) {
  const { whatsNewReport, researchReport, loading, error, reload } = useMarketBriefs(active);
  const [digestDays, setDigestDays] = useState<DigestDay[]>([]);
  const [digestRange, setDigestRange] = useState<DigestRange>(1);
  const [analysisSection, setAnalysisSection] = useState<AnalysisSection>("reports");
  const [isSyncing, setIsSyncing] = useState(true);
  const [assistantError, setAssistantError] = useState<string | null>(null);

  const syncFeed = useCallback(async () => {
    setIsSyncing(true);
    setAssistantError(null);
    try {
      const digest = await api.digest(7);
      setDigestDays(toDigestDays(digest.days ?? []));
    } catch {
      try {
        const [reports, alerts, suggestions] = await Promise.all([
          api.reports(50),
          api.alerts(50),
          api.suggestions(50),
        ]);
        setDigestDays(buildDigestFromParts(reports, alerts, suggestions));
      } catch (e) {
        setAssistantError(e instanceof Error ? e.message : "Could not load assistant feed.");
      }
    } finally {
      setIsSyncing(false);
    }
  }, []);

  useEffect(() => {
    if (active) void syncFeed();
  }, [active, syncFeed]);

  const handleRefresh = () => {
    onRefresh();
    void reload();
    void syncFeed();
  };

  return (
    <div className="market-view">
      <ViewHeader
        title="Analyst"
        live={usesLiveData}
        liveLabel={usesLiveData ? dataThroughLabel : undefined}
        onRefresh={handleRefresh}
        refreshing={refreshing || loading}
      />

      {error && <div className="error-banner">{error}</div>}

      <div className="view-section">
        <SectionLabel text="Market Brief" />
        {whatsNewReport ? (
          <div className="market-brief-card market-brief-purple">
            <MarketTabReportBody
              bodyText={reportBodyText(whatsNewReport)}
              mode="whatsNewOnly"
            />
            <div className="market-brief-stamp mono">{formatStamp(whatsNewReport.created_at)}</div>
          </div>
        ) : loading ? (
          <p className="empty-hint">Loading market brief…</p>
        ) : (
          <p className="empty-hint">
            Market brief will appear after the 10:00 AM ET pulse report on trading days.
          </p>
        )}
      </div>

      <div className="view-section">
        <SectionLabel text="Research Watchlist" />
        {researchReport ? (
          <div className="market-brief-card market-brief-orange">
            <MarketTabReportBody bodyText={researchReport.body} mode="researchOnly" />
            <div className="market-brief-stamp mono">{formatStamp(researchReport.created_at)}</div>
          </div>
        ) : loading ? (
          <p className="empty-hint">Loading research watchlist…</p>
        ) : (
          <p className="empty-hint">
            Research watchlist appears after the first pulse report of the day.
          </p>
        )}
      </div>

      <div className="view-section">
        <AssistantFeedView
          digestDays={digestDays}
          digestRange={digestRange}
          onDigestRangeChange={setDigestRange}
          analysisSection={analysisSection}
          onAnalysisSectionChange={setAnalysisSection}
          isSyncing={isSyncing}
          error={assistantError}
        />
      </div>
    </div>
  );
}

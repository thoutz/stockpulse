import { ViewHeader } from "@/components/ViewHeader";
import { MarketTabReportBody } from "@/components/HighlightedReportText";
import { SectionLabel } from "@/components/SectionLabel";
import { reportBodyText, useMarketBriefs } from "@/hooks/useMarketBriefs";
import "./MarketView.css";

interface MarketViewProps {
  active: boolean;
  usesLiveData: boolean;
  dataThroughLabel: string;
  refreshing: boolean;
  onRefresh: () => void;
  /** Embedded in Research split — compact chrome, no page title */
  pane?: boolean;
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

export function MarketView({
  active,
  usesLiveData,
  dataThroughLabel,
  refreshing,
  onRefresh,
  pane = false,
}: MarketViewProps) {
  const { whatsNewReport, researchReport, loading, error, reload } = useMarketBriefs(active);

  const handleRefresh = () => {
    onRefresh();
    void reload();
  };

  return (
    <div className={`market-view ${pane ? "market-pane" : ""}`}>
      {pane ? (
        <div className="pane-header">
          <h2 className="pane-title">Market</h2>
          <div className="pane-header-actions">
            <button
              type="button"
              className="refresh-btn"
              onClick={handleRefresh}
              disabled={refreshing || loading}
            >
              {refreshing || loading ? "…" : "↻"}
            </button>
          </div>
        </div>
      ) : (
        <ViewHeader
          title="Market"
          live={usesLiveData}
          liveLabel={usesLiveData ? dataThroughLabel : undefined}
          onRefresh={handleRefresh}
          refreshing={refreshing || loading}
        />
      )}

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
    </div>
  );
}

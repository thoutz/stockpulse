import { useState } from "react";
import { TabBar } from "@/components/TabBar";
import { useCatalog } from "@/hooks/useCatalog";
import { useDashboard } from "@/hooks/useDashboard";
import type { AppTab } from "@/lib/api";
import { AIAnalystView } from "@/views/AIAnalystView";
import { AnalystView } from "@/views/AnalystView";
import { PulseView } from "@/views/PulseView";
import { WatchlistView } from "@/views/WatchlistView";

export default function App() {
  const [tab, setTab] = useState<AppTab>("pulse");
  const catalog = useCatalog();
  const {
    dashboard,
    snapshots,
    loading,
    refreshing,
    error,
    refresh,
    usesLiveData,
    dataThroughLabel,
  } = useDashboard(catalog.watchlistTickers);

  return (
    <div className="app-shell">
      <TabBar selected={tab} onSelect={setTab} />
      <main className="app-main">
        {error && <div className="error-banner">{error}</div>}
        {loading && !dashboard ? (
          <div className="empty-hint" style={{ padding: 24 }}>
            Loading StockPulse…
          </div>
        ) : (
          <>
            {tab === "pulse" && (
              <PulseView
                dashboard={dashboard}
                catalysts={catalog.catalysts}
                keyEvents={catalog.keyEvents}
                snapshots={snapshots}
                industries={catalog.industries}
                industryAccentHex={catalog.industryAccentHex}
                usesLiveData={usesLiveData}
                dataThroughLabel={dataThroughLabel}
                refreshing={refreshing}
                onRefresh={() => void refresh()}
              />
            )}
            {tab === "watchlist" && (
              <WatchlistView
                active={tab === "watchlist"}
                industries={catalog.industries}
                dashboard={dashboard}
              />
            )}
            {tab === "analyst" && (
              <AnalystView
                active={tab === "analyst"}
                usesLiveData={usesLiveData}
                dataThroughLabel={dataThroughLabel}
                refreshing={refreshing}
                onRefresh={() => void refresh()}
              />
            )}
            {tab === "ai" && <AIAnalystView usesLiveData={usesLiveData} />}
          </>
        )}
      </main>
    </div>
  );
}

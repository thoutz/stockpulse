import { LiveIndicator } from "@/components/LiveIndicator";

interface ViewHeaderProps {
  title: string;
  subtitle?: string;
  live: boolean;
  liveLabel?: string;
  onRefresh?: () => void;
  refreshing?: boolean;
}

export function ViewHeader({ title, subtitle, live, liveLabel, onRefresh, refreshing }: ViewHeaderProps) {
  return (
    <div className="view-header">
      <div>
        <h1>{title}</h1>
        {subtitle && <p className="view-header-subtitle">{subtitle}</p>}
      </div>
      <div style={{ display: "flex", alignItems: "center", gap: 12 }}>
        {onRefresh && (
          <button type="button" className="refresh-btn" onClick={onRefresh} disabled={refreshing}>
            {refreshing ? "…" : "↻"}
          </button>
        )}
        <LiveIndicator live={live} label={liveLabel} />
      </div>
    </div>
  );
}

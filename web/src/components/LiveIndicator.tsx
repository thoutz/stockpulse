interface LiveIndicatorProps {
  live: boolean;
  label?: string;
}

export function LiveIndicator({ live, label }: LiveIndicatorProps) {
  return (
    <div className="live-indicator" style={{ color: live ? "var(--green)" : "var(--text-dim)" }}>
      <span className={`live-dot ${live ? "on" : "off"}`} />
      {label ?? (live ? "Live" : "Waiting for data")}
    </div>
  );
}

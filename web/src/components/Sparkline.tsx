interface SparklineProps {
  data: number[];
  color?: string;
  height?: number;
  width?: number;
  eventDay?: number | null;
  showArea?: boolean;
  positive?: boolean;
}

export function Sparkline({
  data,
  color,
  height = 36,
  width = 120,
  eventDay = null,
  showArea = false,
  positive,
}: SparklineProps) {
  if (!data || data.length < 2) return null;

  const strokeColor =
    color ?? (positive === undefined ? "var(--blue)" : positive ? "var(--green)" : "var(--red)");

  const min = Math.min(...data);
  const max = Math.max(...data);
  const range = max - min || 1;

  const pts = data.map((v, i) => {
    const x = (i / (data.length - 1)) * width;
    const y = height - ((v - min) / range) * (height - 4) - 2;
    return `${x},${y}`;
  });

  const linePath = "M" + pts.join(" L");
  const areaPath = linePath + ` L${width},${height} L0,${height} Z`;
  const eventX =
    eventDay != null && eventDay >= 0 ? (eventDay / (data.length - 1)) * width : null;

  return (
    <svg width={width} height={height} style={{ overflow: "visible", display: "block" }}>
      {showArea && <path d={areaPath} fill={strokeColor} fillOpacity={0.08} />}
      <path d={linePath} fill="none" stroke={strokeColor} strokeWidth={1.5} />
      {eventX != null && (
        <line
          x1={eventX}
          y1={0}
          x2={eventX}
          y2={height}
          stroke="var(--orange)"
          strokeWidth={1}
          strokeDasharray="2,2"
        />
      )}
    </svg>
  );
}

import { chartColors, formatPct } from "@/lib/design-system";
import { formatTrendAxisDate } from "@/lib/trendRange";
import "./TrendChart.css";

interface TrendChartProps {
  tickers: string[];
  series: Record<string, number[]>;
  dates?: string[];
  colors?: string[];
  title?: string;
  eventDay?: number | null;
  height?: number;
  showLegend?: boolean;
  rangeLabel?: string;
  intraday?: boolean;
}

export function TrendChart({
  tickers,
  series,
  dates,
  colors = chartColors,
  title,
  eventDay = null,
  height = 200,
  showLegend = true,
  rangeLabel = "30D",
  intraday = false,
}: TrendChartProps) {
  const normalized = tickers
    .map((t) => {
      const h = series[t];
      if (!h || h.length < 2) return null;
      const base = h[0];
      return h.map((v) => (base === 0 ? 0 : ((v - base) / base) * 100));
    })
    .filter(Boolean) as number[][];

  if (normalized.length === 0) return null;

  const width = 560;
  const padL = 48;
  const padR = 16;
  const padT = 16;
  const padB = 32;
  const cw = width - padL - padR;
  const ch = height - padT - padB;

  const allVals = normalized.flat();
  const min = Math.min(...allVals);
  const max = Math.max(...allVals);
  const range = max - min || 1;
  const n = normalized[0].length;
  if (n < 2) return null;

  const yTicks = [min, min + range * 0.5, max];
  const midDateIdx = Math.floor((n - 1) / 2);

  return (
    <div className="trend-chart">
      {title && <div className="trend-chart-title">{title}</div>}
      <svg viewBox={`0 0 ${width} ${height}`} className="trend-chart-svg">
        {yTicks.map((v) => {
          const y = padT + ch - ((v - min) / range) * ch;
          return (
            <g key={v}>
              <line x1={padL} y1={y} x2={width - padR} y2={y} stroke="var(--border2)" strokeWidth={0.5} />
              <text x={padL - 6} y={y + 3} textAnchor="end" className="trend-axis-label">
                {formatPct(v, 0)}
              </text>
            </g>
          );
        })}

        {eventDay != null && eventDay >= 0 && (
          <line
            x1={padL + (eventDay / (n - 1)) * cw}
            y1={padT}
            x2={padL + (eventDay / (n - 1)) * cw}
            y2={padT + ch}
            stroke="var(--orange)"
            strokeWidth={1}
            strokeDasharray="3,3"
          />
        )}

        {normalized.map((data, ti) => {
          const col = colors[ti % colors.length];
          const ticker = tickers[ti];
          const pts = data.map((v, i) => {
            const x = padL + (i / (n - 1)) * cw;
            const y = padT + ch - ((v - min) / range) * ch;
            return `${x},${y}`;
          });
          return (
            <path
              key={ticker}
              d={"M" + pts.join(" L")}
              fill="none"
              stroke={col}
              strokeWidth={2}
            />
          );
        })}

        {dates && dates.length > 0 && (
          <>
            <text x={padL} y={height - 8} className="trend-axis-label">
              {formatTrendAxisDate(dates[0] ?? "", intraday)}
            </text>
            {n > 2 && dates[midDateIdx] && (
              <text
                x={padL + (midDateIdx / (n - 1)) * cw}
                y={height - 8}
                textAnchor="middle"
                className="trend-axis-label"
              >
                {formatTrendAxisDate(dates[midDateIdx], intraday)}
              </text>
            )}
            <text x={width - padR} y={height - 8} textAnchor="end" className="trend-axis-label">
              {formatTrendAxisDate(dates[dates.length - 1] ?? "", intraday)}
            </text>
          </>
        )}
      </svg>

      {showLegend && (
        <div className="trend-legend">
          {tickers.map((t, i) => {
            const h = series[t];
            if (!h) return null;
            const chgAll = h.length > 1 ? ((h[h.length - 1] - h[0]) / h[0]) * 100 : 0;
            const col = colors[i % colors.length];
            return (
              <div key={t} className="trend-legend-item" style={{ borderTopColor: col }}>
                <div className="trend-legend-ticker" style={{ color: col }}>
                  {t}
                </div>
                <div className="trend-legend-pct">
                  {rangeLabel}:{" "}
                  <span className={chgAll >= 0 ? "positive" : "negative"}>
                    {formatPct(chgAll)}
                  </span>
                </div>
              </div>
            );
          })}
        </div>
      )}
    </div>
  );
}

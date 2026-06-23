import { useMemo, useState } from "react";
import type { APIBar } from "@/lib/api";
import { barCloses, barDates } from "@/lib/api";
import { formatPct, normalizeSeries } from "@/lib/design-system";
import "./PriceChart.css";

export type ChartMode = "price" | "percent";

interface PriceChartProps {
  bars: APIBar[];
  color?: string;
  height?: number;
  sma20?: number | null;
  positive?: boolean;
  showSma?: boolean;
}

export function PriceChart({
  bars,
  color,
  height = 160,
  sma20,
  positive,
  showSma = true,
}: PriceChartProps) {
  const [mode, setMode] = useState<ChartMode>("price");

  const chart = useMemo(() => {
    if (bars.length < 2) return null;

    const closes = barCloses(bars);
    const dates = barDates(bars);
    const series = mode === "percent" ? normalizeSeries(closes) : closes;

    const width = 560;
    const padL = 52;
    const padR = 12;
    const padT = 12;
    const padB = 28;
    const cw = width - padL - padR;
    const ch = height - padT - padB;

    const min = Math.min(...series);
    const max = Math.max(...series);
    const range = max - min || 1;

    const pts = series.map((v, i) => {
      const x = padL + (i / (series.length - 1)) * cw;
      const y = padT + ch - ((v - min) / range) * ch;
      return { x, y, v };
    });

    const linePath = pts.map((p, i) => `${i === 0 ? "M" : "L"}${p.x},${p.y}`).join(" ");
    const areaPath = `${linePath} L${padL + cw},${padT + ch} L${padL},${padT + ch} Z`;

    const yTicks = [min, min + range * 0.5, max];
    const gridYs = yTicks.map((v) => padT + ch - ((v - min) / range) * ch);

    let smaY: number | null = null;
    if (showSma && sma20 != null && mode === "price") {
      smaY = padT + ch - ((sma20 - min) / range) * ch;
      if (smaY < padT || smaY > padT + ch) smaY = null;
    }

    const strokeColor =
      color ?? (positive === undefined ? "var(--blue)" : positive ? "var(--green)" : "var(--red)");

    const formatY = (v: number) =>
      mode === "percent" ? formatPct(v, 0) : `$${v.toFixed(v >= 100 ? 0 : 2)}`;

    return {
      width,
      height,
      padL,
      padT,
      ch,
      cw,
      linePath,
      areaPath,
      gridYs,
      yTicks,
      formatY,
      strokeColor,
      smaY,
      startDate: dates[0]?.slice(5, 10) ?? "",
      endDate: dates[dates.length - 1]?.slice(5, 10) ?? "",
    };
  }, [bars, mode, height, sma20, showSma, color, positive]);

  if (!chart) return null;

  return (
    <div className="price-chart">
      <div className="price-chart-toolbar">
        <div className="chart-mode-toggle">
          <button
            type="button"
            className={mode === "price" ? "active" : ""}
            onClick={() => setMode("price")}
          >
            Price
          </button>
          <button
            type="button"
            className={mode === "percent" ? "active" : ""}
            onClick={() => setMode("percent")}
          >
            % Change
          </button>
        </div>
        {showSma && sma20 != null && mode === "price" && (
          <span className="sma-legend mono">SMA 20 · ${sma20.toFixed(2)}</span>
        )}
      </div>
      <svg viewBox={`0 0 ${chart.width} ${chart.height}`} className="price-chart-svg">
        <defs>
          <linearGradient id="priceAreaGrad" x1="0" y1="0" x2="0" y2="1">
            <stop offset="0%" stopColor={chart.strokeColor} stopOpacity={0.2} />
            <stop offset="100%" stopColor={chart.strokeColor} stopOpacity={0.02} />
          </linearGradient>
        </defs>

        {chart.gridYs.map((y, i) => (
          <g key={i}>
            <line
              x1={chart.padL}
              y1={y}
              x2={chart.padL + chart.cw}
              y2={y}
              stroke="var(--border2)"
              strokeWidth={0.5}
            />
            <text x={chart.padL - 6} y={y + 3} textAnchor="end" className="chart-axis-label">
              {chart.formatY(chart.yTicks[i])}
            </text>
          </g>
        ))}

        {chart.smaY != null && (
          <>
            <line
              x1={chart.padL}
              y1={chart.smaY}
              x2={chart.padL + chart.cw}
              y2={chart.smaY}
              stroke="var(--purple)"
              strokeWidth={1}
              strokeDasharray="4,3"
              opacity={0.8}
            />
          </>
        )}

        <path d={chart.areaPath} fill="url(#priceAreaGrad)" />
        <path
          d={chart.linePath}
          fill="none"
          stroke={chart.strokeColor}
          strokeWidth={2}
          strokeLinejoin="round"
        />

        <text x={chart.padL} y={chart.height - 8} className="chart-axis-label">
          {chart.startDate}
        </text>
        <text x={chart.padL + chart.cw} y={chart.height - 8} textAnchor="end" className="chart-axis-label">
          {chart.endDate}
        </text>
      </svg>
    </div>
  );
}

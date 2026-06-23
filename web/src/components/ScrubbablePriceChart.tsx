import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import type { APIBar } from "@/lib/api";
import { barCloses } from "@/lib/api";
import {
  TREND_RANGES,
  TREND_RANGE_LABELS,
  formatMonitorAxisDate,
  type TrendRange,
} from "@/lib/trendRange";
import "./ScrubbablePriceChart.css";

export interface MonitorScrubDisplay {
  price: number;
  dateLabel: string;
  changePct: number;
}

interface ScrubbablePriceChartProps {
  bars: APIBar[];
  range: TrendRange;
  onRangeChange: (range: TrendRange) => void;
  loading?: boolean;
  error?: string | null;
  onScrub: (display: MonitorScrubDisplay | null) => void;
  height?: number;
}

export function ScrubbablePriceChart({
  bars,
  range,
  onRangeChange,
  loading = false,
  error = null,
  onScrub,
  height = 180,
}: ScrubbablePriceChartProps) {
  const [scrubIndex, setScrubIndex] = useState<number | null>(null);
  const plotRef = useRef<SVGRectElement>(null);

  useEffect(() => {
    setScrubIndex(null);
    onScrub(null);
    // eslint-disable-next-line react-hooks/exhaustive-deps -- reset scrub when range or data changes
  }, [range, bars.length]);

  const periodChange = useMemo(() => {
    if (bars.length < 2) return null;
    const first = bars[0].close;
    const last = bars[bars.length - 1].close;
    if (first <= 0) return null;
    return ((last - first) / first) * 100;
  }, [bars]);

  const strokeColor =
    periodChange == null
      ? "var(--blue)"
      : periodChange >= 0
        ? "var(--green)"
        : "var(--red)";

  const emitScrub = useCallback(
    (index: number | null) => {
      setScrubIndex(index);
      if (index == null || index < 0 || index >= bars.length) {
        onScrub(null);
        return;
      }
      const bar = bars[index];
      const first = bars[0]?.close ?? 0;
      const changePct = first > 0 ? ((bar.close - first) / first) * 100 : 0;
      onScrub({
        price: bar.close,
        dateLabel: formatMonitorAxisDate(bar.date, range),
        changePct,
      });
    },
    [bars, onScrub, range],
  );

  const chart = useMemo(() => {
    if (bars.length < 2) return null;

    const closes = barCloses(bars);
    const width = 560;
    const padL = 52;
    const padR = 12;
    const padT = 12;
    const padB = 28;
    const cw = width - padL - padR;
    const ch = height - padT - padB;

    const min = Math.min(...closes);
    const max = Math.max(...closes);
    const pad = Math.max((max - min) * 0.08, 0.01);
    const yMin = min - pad;
    const yMax = max + pad;
    const rangeY = yMax - yMin || 1;

    const pts = closes.map((v, i) => {
      const x = padL + (i / (closes.length - 1)) * cw;
      const y = padT + ch - ((v - yMin) / rangeY) * ch;
      return { x, y, v, i };
    });

    const linePath = pts.map((p, i) => `${i === 0 ? "M" : "L"}${p.x},${p.y}`).join(" ");
    const areaPath = `${linePath} L${padL + cw},${padT + ch} L${padL},${padT + ch} Z`;

    const yTicks = [yMin, yMin + rangeY * 0.5, yMax];
    const gridYs = yTicks.map((v) => padT + ch - ((v - yMin) / rangeY) * ch);

    const formatY = (v: number) =>
      v >= 1000 ? `$${v.toFixed(0)}` : v >= 100 ? `$${v.toFixed(1)}` : `$${v.toFixed(2)}`;

    const scrubPt = scrubIndex != null ? pts[scrubIndex] : null;

    const tickCount = range === "1W" ? 5 : range === "30D" ? 5 : 6;
    const xTickIndices =
      bars.length >= 2
        ? Array.from({ length: tickCount }, (_, i) =>
            Math.round((i / Math.max(tickCount - 1, 1)) * (bars.length - 1)),
          )
        : [0];

    return {
      width,
      height,
      padL,
      padT,
      padB,
      ch,
      cw,
      linePath,
      areaPath,
      gridYs,
      yTicks,
      formatY,
      scrubPt,
      xTickIndices,
      startDate: formatMonitorAxisDate(bars[0].date, range),
      endDate: formatMonitorAxisDate(bars[bars.length - 1].date, range),
    };
  }, [bars, height, scrubIndex, range]);

  const handlePointer = useCallback(
    (clientX: number) => {
      if (!chart || !plotRef.current) return;
      const rect = plotRef.current.getBoundingClientRect();
      const relX = clientX - rect.left;
      const ratio = Math.max(0, Math.min(1, relX / rect.width));
      const index = Math.round(ratio * (bars.length - 1));
      emitScrub(index);
    },
    [bars.length, chart, emitScrub],
  );

  return (
    <div className="scrub-price-chart">
      <div className="scrub-price-range-row">
        {TREND_RANGES.map((item) => (
          <button
            key={item}
            type="button"
            className={`scrub-price-range-btn mono ${range === item ? "active" : ""}`}
            onClick={() => {
              onRangeChange(item);
              emitScrub(null);
            }}
          >
            {TREND_RANGE_LABELS[item]}
          </button>
        ))}
        {loading && <span className="scrub-price-loading mono">Loading…</span>}
      </div>

      {error && <div className="scrub-price-error mono">{error}</div>}

      {!chart && !loading && (
        <div className="scrub-price-empty mono">Not enough chart data</div>
      )}

      {chart && (
        <svg viewBox={`0 0 ${chart.width} ${chart.height}`} className="scrub-price-svg">
          <defs>
            <linearGradient id="scrubPriceAreaGrad" x1="0" y1="0" x2="0" y2="1">
              <stop offset="0%" stopColor={strokeColor} stopOpacity={0.2} />
              <stop offset="100%" stopColor={strokeColor} stopOpacity={0.02} />
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

          <path d={chart.areaPath} fill="url(#scrubPriceAreaGrad)" />
          <path
            d={chart.linePath}
            fill="none"
            stroke={strokeColor}
            strokeWidth={2}
            strokeLinejoin="round"
          />

          {chart.scrubPt && (
            <>
              <line
                x1={chart.scrubPt.x}
                y1={chart.padT}
                x2={chart.scrubPt.x}
                y2={chart.padT + chart.ch}
                stroke="var(--text-muted)"
                strokeWidth={1}
                strokeDasharray="4,3"
                opacity={0.7}
              />
              <circle
                cx={chart.scrubPt.x}
                cy={chart.scrubPt.y}
                r={5}
                fill={strokeColor}
                stroke="var(--surface)"
                strokeWidth={2}
              />
            </>
          )}

          <rect
            ref={plotRef}
            x={chart.padL}
            y={chart.padT}
            width={chart.cw}
            height={chart.ch}
            fill="transparent"
            className="scrub-price-plot"
            onPointerDown={(e) => {
              e.currentTarget.setPointerCapture(e.pointerId);
              handlePointer(e.clientX);
            }}
            onPointerMove={(e) => {
              if (e.currentTarget.hasPointerCapture(e.pointerId)) {
                handlePointer(e.clientX);
              }
            }}
            onPointerUp={(e) => {
              e.currentTarget.releasePointerCapture(e.pointerId);
            }}
            onPointerLeave={() => {
              /* keep selection after release, Robinhood-style */
            }}
            onDoubleClick={() => emitScrub(null)}
          />

          <text x={chart.padL} y={chart.height - 8} className="chart-axis-label">
            {chart.startDate}
          </text>
          {chart.xTickIndices.slice(1, -1).map((idx) => (
            <text
              key={idx}
              x={chart.padL + (idx / Math.max(bars.length - 1, 1)) * chart.cw}
              y={chart.height - 8}
              textAnchor="middle"
              className="chart-axis-label"
            >
              {formatMonitorAxisDate(bars[idx].date, range)}
            </text>
          ))}
          <text
            x={chart.padL + chart.cw}
            y={chart.height - 8}
            textAnchor="end"
            className="chart-axis-label"
          >
            {chart.endDate}
          </text>
        </svg>
      )}
    </div>
  );
}

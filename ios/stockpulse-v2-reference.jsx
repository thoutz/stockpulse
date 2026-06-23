import { useState, useEffect, useRef, useMemo } from "react";

// ── HISTORICAL DATA (30 days: May 4 – Jun 2, 2026) ──────────────────────────
const DATES = ["05/04","05/05","05/06","05/07","05/08","05/09","05/10","05/11","05/12","05/13","05/14","05/15","05/16","05/17","05/18","05/19","05/20","05/21","05/22","05/23","05/24","05/25","05/26","05/27","05/28","05/29","05/30","05/31","06/01","06/02"];

const HISTORY = {
  SPCX: [280.69,280.29,279.85,278.89,284.71,287.22,290.44,288.91,292.3,295.1,298.8,296.2,299.5,302.1,298.9,296.4,300.2,304.5,308.1,312.9, 320.4,325.1,322.8,318.9,316.2,314.8,318.3,321.7,319.2,324.52],
  RKLB: [21.69,21.4,21.82,21.55,22.1,22.44,22.9,22.6,23.1,23.8,24.2,23.7,24.0,24.4,23.9,23.5,24.1,24.7,25.1,25.6, 26.2,26.8,26.4,26.0,25.7,25.4,25.9,26.3,26.1,26.99],
  TSLA: [257.59,256.8,258.2,255.9,257.1,259.4,261.2,259.8,260.5,258.9,262.1,264.3,261.8,259.2,261.5,263.8,260.4,258.7,261.9,264.5, 262.1,260.8,263.4,265.7,263.2,261.9,264.8,266.1,264.5,264.27],
  NVDA: [127.78,128.4,129.1,128.5,129.8,131.2,133.5,132.1,133.8,135.2,143.8,141.5,142.9,144.3,142.8,141.2,143.5,145.1,143.7,144.9, 146.2,145.8,144.6,146.1,147.3,145.9,147.2,148.5,146.9,139.16],
  ASTS: [17.53,17.2,17.8,17.4,18.1,18.5,19.0,18.6,19.2,19.8,20.2,19.7,20.1,20.6,20.1,19.7,20.3,20.9,21.4,22.0, 22.8,23.4,23.0,22.6,22.3,22.0,22.5,23.0,22.8,23.34],
  LUNR: [9.63,9.5,9.7,9.55,9.8,9.95,10.1,9.9,10.15,10.3,10.5,10.3,10.45,10.6,10.4,10.2,10.45,10.65,10.5,10.7, 10.9,11.1,10.95,10.8,10.65,10.5,10.7,10.85,10.7,10.64],
  HWM:  [125.49,125.8,126.2,125.6,126.5,127.1,127.8,127.3,128.0,128.7,129.4,129.0,129.6,130.2,129.7,129.2,130.0,130.8,130.3,131.1, 131.8,132.5,132.1,132.9,133.6,133.1,134.0,134.8,134.3,136.94],
  RDW:  [7.01,6.9,7.1,6.95,7.15,7.25,7.4,7.2,7.35,7.5,7.65,7.5,7.6,7.75,7.6,7.45,7.6,7.8,7.65,7.85, 8.0,8.2,8.05,7.9,7.75,7.6,7.75,7.9,7.75,7.34],
  AMD:  [157.35,158.1,159.0,158.2,159.5,160.8,162.4,161.2,162.9,164.3,168.8,167.2,168.5,169.8,168.3,167.0,168.8,170.2,168.9,170.3, 171.5,170.8,169.6,171.1,172.3,170.9,172.2,173.5,171.9,170.6],
  AVGO: [210.01,211.2,212.5,211.3,213.0,214.8,216.5,215.1,217.2,218.8,222.4,220.9,222.1,223.8,222.1,220.7,222.5,224.3,222.8,224.5, 226.1,225.4,224.2,226.0,227.5,225.9,227.4,228.9,227.2,229.35],
};

const CURRENT = Object.fromEntries(
  Object.entries(HISTORY).map(([t, h]) => [t, h[h.length - 1]])
);

// ── RIPPLE RELATIONSHIPS ─────────────────────────────────────────────────────
const CATALYSTS = [
  {
    ticker: "SPCX", name: "SpaceX", event: "IPO Filing + Roadshow",
    eventDay: 20, // index in DATES array
    ripples: [
      { ticker: "RKLB", label: "Primary proxy — launch competitor" },
      { ticker: "ASTS", label: "Satellite connectivity play" },
      { ticker: "LUNR", label: "Lunar infrastructure" },
      { ticker: "HWM",  label: "Aerospace components" },
      { ticker: "RDW",  label: "Spacecraft components" },
    ],
  },
  {
    ticker: "NVDA", name: "NVIDIA", event: "Q1 Earnings Beat",
    eventDay: 10,
    ripples: [
      { ticker: "AMD",  label: "Chip sector peer" },
      { ticker: "AVGO", label: "AI networking" },
    ],
  },
];

// ── KEY EVENTS ───────────────────────────────────────────────────────────────
const EVENTS = [
  { day: 10, label: "NVDA Earnings", color: "#22c55e" },
  { day: 20, label: "SPCX IPO Filing", color: "#f59e0b" },
  { day: 25, label: "SPCX Roadshow", color: "#f97316" },
];

// ── HELPERS ──────────────────────────────────────────────────────────────────
function pct(arr, from, to) {
  return ((arr[to] - arr[from]) / arr[from]) * 100;
}

function rippleVerdict(catalystTicker, rippleTicker, eventDay) {
  const cat = HISTORY[catalystTicker];
  const rip = HISTORY[rippleTicker];
  if (!cat || !rip) return null;
  const catMove = pct(cat, eventDay, cat.length - 1);
  const ripMove = pct(rip, eventDay, rip.length - 1);
  const preRipMove = pct(rip, 0, eventDay);
  if (catMove > 3 && ripMove > 2) return "CONFIRMED";
  if (catMove > 3 && ripMove > 0) return "FORMING";
  if (catMove > 3 && ripMove <= 0) return "FAILED";
  return "WATCHING";
}

const VERDICT_STYLE = {
  CONFIRMED: { color: "#22c55e", bg: "#22c55e18", icon: "✓" },
  FORMING:   { color: "#f59e0b", bg: "#f59e0b18", icon: "◐" },
  FAILED:    { color: "#ef4444", bg: "#ef444418", icon: "✗" },
  WATCHING:  { color: "#60a5fa", bg: "#60a5fa18", icon: "◎" },
};

// ── MINI SPARKLINE ───────────────────────────────────────────────────────────
function Sparkline({ data, color = "#60a5fa", height = 36, width = 120, eventDay = null, showArea = false }) {
  if (!data || data.length < 2) return null;
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
  const eventX = eventDay != null ? (eventDay / (data.length - 1)) * width : null;

  return (
    <svg width={width} height={height} style={{ overflow: "visible" }}>
      {showArea && <path d={areaPath} fill={color} fillOpacity={0.08} />}
      <path d={linePath} fill="none" stroke={color} strokeWidth={1.5} />
      {eventX != null && (
        <line x1={eventX} y1={0} x2={eventX} y2={height} stroke="#f59e0b" strokeWidth={1} strokeDasharray="2,2" />
      )}
    </svg>
  );
}

// ── FULL TREND CHART ─────────────────────────────────────────────────────────
function TrendChart({ tickers, colors, title, eventDay, height = 200, showLegend = true }) {
  const allData = tickers.map(t => HISTORY[t]).filter(Boolean);
  if (allData.length === 0) return null;

  const width = 560;
  const padL = 48, padR = 16, padT = 16, padB = 32;
  const cw = width - padL - padR;
  const ch = height - padT - padB;

  // Normalize to % change from day 0
  const normalized = tickers.map((t, ti) => {
    const h = HISTORY[t];
    if (!h) return null;
    return h.map(v => ((v - h[0]) / h[0]) * 100);
  }).filter(Boolean);

  const allVals = normalized.flat();
  const minV = Math.min(...allVals) - 1;
  const maxV = Math.max(...allVals) + 1;
  const range = maxV - minV;

  function toX(i) { return padL + (i / (DATES.length - 1)) * cw; }
  function toY(v) { return padT + ch - ((v - minV) / range) * ch; }

  const yTicks = [-5, 0, 5, 10, 15, 20, 25].filter(v => v >= minV - 2 && v <= maxV + 2);

  return (
    <div style={{ overflowX: "auto" }}>
      <svg width={width} height={height} style={{ display: "block", minWidth: width }}>
        {/* Grid */}
        {yTicks.map(v => (
          <g key={v}>
            <line x1={padL} y1={toY(v)} x2={width - padR} y2={toY(v)} stroke="#1e2535" strokeWidth={1} />
            <text x={padL - 4} y={toY(v) + 4} textAnchor="end" fill="#4b5563" fontSize={9} fontFamily="'IBM Plex Mono', monospace">{v > 0 ? "+" : ""}{v}%</text>
          </g>
        ))}

        {/* Zero line */}
        <line x1={padL} y1={toY(0)} x2={width - padR} y2={toY(0)} stroke="#374151" strokeWidth={1} strokeDasharray="4,4" />

        {/* Event markers */}
        {EVENTS.map(ev => (
          <g key={ev.day}>
            <line x1={toX(ev.day)} y1={padT} x2={toX(ev.day)} y2={height - padB} stroke={ev.color} strokeWidth={1} strokeDasharray="3,3" strokeOpacity={0.7} />
            <text x={toX(ev.day) + 3} y={padT + 9} fill={ev.color} fontSize={8} fontFamily="'IBM Plex Mono', monospace" opacity={0.9}>{ev.label}</text>
          </g>
        ))}

        {/* Lines */}
        {normalized.map((norm, ti) => {
          const color = colors[ti] || "#60a5fa";
          const pts = norm.map((v, i) => `${toX(i)},${toY(v)}`);
          return (
            <g key={tickers[ti]}>
              <path d={"M" + pts.join(" L")} fill="none" stroke={color} strokeWidth={2} />
              {/* Endpoint dot */}
              <circle cx={toX(norm.length - 1)} cy={toY(norm[norm.length - 1])} r={3} fill={color} />
              <text x={toX(norm.length - 1) + 5} y={toY(norm[norm.length - 1]) + 4} fill={color} fontSize={9} fontFamily="'IBM Plex Mono', monospace" fontWeight="700">{tickers[ti]}</text>
            </g>
          );
        })}

        {/* X axis labels */}
        {[0, 5, 10, 15, 20, 25, 29].map(i => (
          <text key={i} x={toX(i)} y={height - 4} textAnchor="middle" fill="#4b5563" fontSize={8} fontFamily="'IBM Plex Mono', monospace">{DATES[i]}</text>
        ))}
      </svg>
    </div>
  );
}

// ── RIPPLE CORRELATION PANEL ─────────────────────────────────────────────────
function RipplePanel({ catalyst }) {
  const [selected, setSelected] = useState(null);
  const catHistory = HISTORY[catalyst.ticker];

  return (
    <div>
      {/* Catalyst overview */}
      <div style={{ marginBottom: 20 }}>
        <div style={{ fontSize: 11, color: "#4b5563", textTransform: "uppercase", letterSpacing: "0.1em", marginBottom: 8, fontFamily: "'IBM Plex Mono', monospace" }}>
          Catalyst: {catalyst.ticker} — {catalyst.event}
        </div>
        <TrendChart
          tickers={[catalyst.ticker, ...catalyst.ripples.map(r => r.ticker)]}
          colors={["#f59e0b", "#22c55e", "#60a5fa", "#a78bfa", "#fb923c", "#34d399"]}
          eventDay={catalyst.eventDay}
          height={200}
        />
        <div style={{ fontSize: 11, color: "#4b5563", marginTop: 6, fontFamily: "'IBM Plex Mono', monospace" }}>
          All lines normalized to % change from May 4. Dashed lines = key events.
        </div>
      </div>

      {/* Ripple verdicts */}
      <div style={{ display: "grid", gridTemplateColumns: "repeat(auto-fill, minmax(220px, 1fr))", gap: 10 }}>
        {catalyst.ripples.map(r => {
          const verdict = rippleVerdict(catalyst.ticker, r.ticker, catalyst.eventDay);
          const vs = VERDICT_STYLE[verdict];
          const rHistory = HISTORY[r.ticker];
          const preMove = rHistory ? pct(rHistory, 0, catalyst.eventDay).toFixed(1) : "—";
          const postMove = rHistory ? pct(rHistory, catalyst.eventDay, rHistory.length - 1).toFixed(1) : "—";
          const isSelected = selected === r.ticker;

          return (
            <div
              key={r.ticker}
              onClick={() => setSelected(isSelected ? null : r.ticker)}
              style={{
                background: isSelected ? "#111827" : "#0d1117",
                border: `1px solid ${isSelected ? vs.color : "#1e2535"}`,
                borderRadius: 8,
                padding: 12,
                cursor: "pointer",
                transition: "all 0.2s",
              }}
            >
              <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: 8 }}>
                <span style={{ fontFamily: "'IBM Plex Mono', monospace", fontSize: 14, fontWeight: 700, color: "#e2e8f0" }}>{r.ticker}</span>
                <span style={{ fontSize: 11, fontWeight: 700, color: vs.color, background: vs.bg, padding: "2px 8px", borderRadius: 4 }}>
                  {vs.icon} {verdict}
                </span>
              </div>
              <div style={{ fontSize: 11, color: "#6b7280", marginBottom: 8 }}>{r.label}</div>
              <div style={{ display: "flex", gap: 12, marginBottom: 8 }}>
                <div>
                  <div style={{ fontSize: 9, color: "#4b5563", textTransform: "uppercase", letterSpacing: "0.08em" }}>Pre-event</div>
                  <div style={{ fontFamily: "'IBM Plex Mono', monospace", fontSize: 12, color: parseFloat(preMove) >= 0 ? "#22c55e" : "#ef4444" }}>
                    {parseFloat(preMove) >= 0 ? "+" : ""}{preMove}%
                  </div>
                </div>
                <div>
                  <div style={{ fontSize: 9, color: "#4b5563", textTransform: "uppercase", letterSpacing: "0.08em" }}>Post-event</div>
                  <div style={{ fontFamily: "'IBM Plex Mono', monospace", fontSize: 12, color: parseFloat(postMove) >= 0 ? "#22c55e" : "#ef4444" }}>
                    {parseFloat(postMove) >= 0 ? "+" : ""}{postMove}%
                  </div>
                </div>
                <div style={{ marginLeft: "auto" }}>
                  <Sparkline data={rHistory} color={vs.color} width={80} height={32} eventDay={catalyst.eventDay} showArea />
                </div>
              </div>

              {/* Expanded: show both lines overlaid */}
              {isSelected && rHistory && catHistory && (
                <div style={{ marginTop: 12, borderTop: "1px solid #1e2535", paddingTop: 12 }}>
                  <div style={{ fontSize: 10, color: "#4b5563", marginBottom: 8, textTransform: "uppercase", letterSpacing: "0.08em" }}>
                    {catalyst.ticker} vs {r.ticker} — normalized performance
                  </div>
                  <TrendChart
                    tickers={[catalyst.ticker, r.ticker]}
                    colors={["#f59e0b", vs.color]}
                    eventDay={catalyst.eventDay}
                    height={140}
                    showLegend={false}
                  />
                  <div style={{ marginTop: 8, background: vs.bg, borderRadius: 6, padding: "8px 12px", borderLeft: `3px solid ${vs.color}` }}>
                    <div style={{ fontSize: 11, color: vs.color, fontWeight: 700, marginBottom: 2 }}>{vs.icon} {verdict}</div>
                    <div style={{ fontSize: 11, color: "#9ca3af" }}>
                      {verdict === "CONFIRMED" && `${r.ticker} rose ${postMove}% after the ${catalyst.event}. Ripple effect validated.`}
                      {verdict === "FORMING" && `${r.ticker} showing positive drift (+${postMove}%) but not yet decisive. Watch for acceleration.`}
                      {verdict === "FAILED" && `${r.ticker} failed to follow ${catalyst.ticker} despite the catalyst. Sector correlation broke down.`}
                      {verdict === "WATCHING" && `Catalyst still early. Pre-event movement (+${preMove}%) suggests anticipation. Monitor post-event response.`}
                    </div>
                  </div>
                </div>
              )}
            </div>
          );
        })}
      </div>
    </div>
  );
}

// ── WATCHLIST ROW ─────────────────────────────────────────────────────────────
function WatchRow({ ticker, onSelect, selected }) {
  const h = HISTORY[ticker];
  if (!h) return null;
  const price = h[h.length - 1];
  const prev = h[h.length - 2];
  const chg = ((price - prev) / prev) * 100;
  const chg30 = ((price - h[0]) / h[0]) * 100;
  const lineColor = chg30 >= 0 ? "#22c55e" : "#ef4444";

  return (
    <div
      onClick={() => onSelect(ticker)}
      style={{
        display: "grid",
        gridTemplateColumns: "70px 90px 70px 70px 100px 1fr",
        alignItems: "center",
        gap: 10,
        padding: "10px 16px",
        borderBottom: "1px solid #1e2535",
        cursor: "pointer",
        background: selected ? "#111827" : "transparent",
        transition: "background 0.15s",
      }}
    >
      <span style={{ fontFamily: "'IBM Plex Mono', monospace", color: "#e2e8f0", fontWeight: 700, fontSize: 13 }}>{ticker}</span>
      <span style={{ fontFamily: "'IBM Plex Mono', monospace", color: "#e2e8f0", fontSize: 13 }}>${price.toFixed(2)}</span>
      <span style={{ fontFamily: "'IBM Plex Mono', monospace", fontSize: 12, color: chg >= 0 ? "#22c55e" : "#ef4444" }}>
        {chg >= 0 ? "+" : ""}{chg.toFixed(2)}%
      </span>
      <span style={{ fontFamily: "'IBM Plex Mono', monospace", fontSize: 12, color: chg30 >= 0 ? "#22c55e" : "#ef4444" }}>
        {chg30 >= 0 ? "+" : ""}{chg30.toFixed(1)}%
      </span>
      <Sparkline data={h} color={lineColor} width={90} height={32} showArea />
      <div style={{ display: "flex", gap: 4, flexWrap: "wrap" }}>
        {CATALYSTS
          .filter(c => c.ripples.some(r => r.ticker === ticker))
          .map(c => {
            const v = rippleVerdict(c.ticker, ticker, c.eventDay);
            const vs = VERDICT_STYLE[v];
            return (
              <span key={c.ticker} style={{ fontSize: 10, color: vs.color, background: vs.bg, padding: "1px 6px", borderRadius: 3, fontWeight: 600 }}>
                ↑{c.ticker} {vs.icon}
              </span>
            );
          })}
      </div>
    </div>
  );
}

// ── STOCK DETAIL PANEL ───────────────────────────────────────────────────────
function StockDetail({ ticker, onClose }) {
  const h = HISTORY[ticker];
  if (!h) return null;
  const price = h[h.length - 1];
  const chg1 = ((price - h[h.length - 2]) / h[h.length - 2]) * 100;
  const chg30 = ((price - h[0]) / h[0]) * 100;
  const high = Math.max(...h);
  const low = Math.min(...h);

  // Is this ticker a ripple of anything?
  const asRipple = CATALYSTS.filter(c => c.ripples.some(r => r.ticker === ticker));
  // Is this ticker a catalyst?
  const asCatalyst = CATALYSTS.find(c => c.ticker === ticker);

  return (
    <div style={{ background: "#0d1117", border: "1px solid #3b82f6", borderRadius: 10, padding: 20, marginBottom: 20 }}>
      <div style={{ display: "flex", justifyContent: "space-between", marginBottom: 16 }}>
        <div>
          <span style={{ fontFamily: "'IBM Plex Mono', monospace", fontSize: 24, fontWeight: 700, color: "#e2e8f0" }}>{ticker}</span>
          <span style={{ fontFamily: "'IBM Plex Mono', monospace", fontSize: 20, color: "#9ca3af", marginLeft: 12 }}>${price.toFixed(2)}</span>
        </div>
        <button onClick={onClose} style={{ background: "none", border: "none", color: "#6b7280", cursor: "pointer", fontSize: 20 }}>✕</button>
      </div>

      {/* Stat row */}
      <div style={{ display: "grid", gridTemplateColumns: "repeat(4, 1fr)", gap: 10, marginBottom: 16 }}>
        {[
          { label: "1D Change", val: `${chg1 >= 0 ? "+" : ""}${chg1.toFixed(2)}%`, color: chg1 >= 0 ? "#22c55e" : "#ef4444" },
          { label: "30D Change", val: `${chg30 >= 0 ? "+" : ""}${chg30.toFixed(1)}%`, color: chg30 >= 0 ? "#22c55e" : "#ef4444" },
          { label: "30D High", val: `$${high.toFixed(2)}`, color: "#e2e8f0" },
          { label: "30D Low",  val: `$${low.toFixed(2)}`,  color: "#e2e8f0" },
        ].map(m => (
          <div key={m.label} style={{ background: "#111827", borderRadius: 8, padding: 10 }}>
            <div style={{ fontSize: 9, color: "#4b5563", textTransform: "uppercase", letterSpacing: "0.08em", marginBottom: 4 }}>{m.label}</div>
            <div style={{ fontFamily: "'IBM Plex Mono', monospace", fontSize: 14, fontWeight: 700, color: m.color }}>{m.val}</div>
          </div>
        ))}
      </div>

      {/* 30-day chart */}
      <TrendChart tickers={[ticker]} colors={[chg30 >= 0 ? "#22c55e" : "#ef4444"]} height={160} showLegend={false} />

      {/* Ripple membership badges */}
      {asRipple.length > 0 && (
        <div style={{ marginTop: 14 }}>
          <div style={{ fontSize: 10, color: "#4b5563", textTransform: "uppercase", letterSpacing: "0.08em", marginBottom: 8 }}>Ripple of →</div>
          {asRipple.map(c => {
            const v = rippleVerdict(c.ticker, ticker, c.eventDay);
            const vs = VERDICT_STYLE[v];
            return (
              <div key={c.ticker} style={{ display: "inline-flex", alignItems: "center", gap: 8, background: vs.bg, border: `1px solid ${vs.color}40`, borderRadius: 6, padding: "6px 12px", marginRight: 8 }}>
                <span style={{ fontFamily: "'IBM Plex Mono', monospace", fontSize: 12, color: "#f59e0b", fontWeight: 700 }}>{c.ticker}</span>
                <span style={{ fontSize: 11, color: "#6b7280" }}>{c.event}</span>
                <span style={{ fontSize: 11, color: vs.color, fontWeight: 700 }}>{vs.icon} {v}</span>
              </div>
            );
          })}
        </div>
      )}
    </div>
  );
}

// ── TICKER TAPE ───────────────────────────────────────────────────────────────
function TickerTape() {
  const [x, setX] = useState(0);
  const items = Object.entries(HISTORY);
  const W = 130;
  useEffect(() => {
    const id = setInterval(() => setX(v => v + 0.5), 20);
    return () => clearInterval(id);
  }, []);
  const total = items.length * W;
  const offset = x % total;

  return (
    <div style={{ overflow: "hidden", background: "#060a0f", borderBottom: "1px solid #1e2535", padding: "5px 0" }}>
      <div style={{ display: "flex", transform: `translateX(-${offset}px)`, whiteSpace: "nowrap" }}>
        {[...items, ...items].map(([t, h], i) => {
          const chg = ((h[h.length-1] - h[h.length-2]) / h[h.length-2]) * 100;
          return (
            <span key={i} style={{ display: "inline-block", minWidth: W, fontFamily: "'IBM Plex Mono', monospace", fontSize: 10, color: chg >= 0 ? "#22c55e" : "#ef4444", padding: "0 12px" }}>
              {t} ${h[h.length-1].toFixed(2)} {chg >= 0 ? "▲" : "▼"}{Math.abs(chg).toFixed(2)}%
            </span>
          );
        })}
      </div>
    </div>
  );
}

// ── AI ANALYST ───────────────────────────────────────────────────────────────
function AiAnalyst() {
  const [query, setQuery] = useState("");
  const [response, setResponse] = useState("");
  const [loading, setLoading] = useState(false);

  const context = `You are a stock market analyst. Historical 30-day data (May 4 – Jun 2, 2026):
${Object.entries(HISTORY).map(([t, h]) => {
  const chg30 = ((h[h.length-1] - h[0]) / h[0] * 100).toFixed(1);
  const postSpcx = ((h[h.length-1] - h[20]) / h[20] * 100).toFixed(1);
  return `${t}: $${h[h.length-1].toFixed(2)}, 30d: ${chg30}%, post-SPCX filing: ${postSpcx}%`;
}).join("\n")}

Key events: NVDA earnings beat (May 14), SPCX IPO filing (May 24), SPCX roadshow begins (May 29).
Confirmed ripple effects: NVDA→AMD (+${((HISTORY.AMD[29]-HISTORY.AMD[10])/HISTORY.AMD[10]*100).toFixed(1)}%), NVDA→AVGO (+${((HISTORY.AVGO[29]-HISTORY.AVGO[10])/HISTORY.AVGO[10]*100).toFixed(1)}%), SPCX→RKLB (+${((HISTORY.RKLB[29]-HISTORY.RKLB[20])/HISTORY.RKLB[20]*100).toFixed(1)}%), SPCX→ASTS (+${((HISTORY.ASTS[29]-HISTORY.ASTS[20])/HISTORY.ASTS[20]*100).toFixed(1)}%).

Answer in 3-5 concise sentences. Be direct and actionable.`;

  async function ask() {
    if (!query.trim()) return;
    setLoading(true);
    setResponse("");
    try {
      const res = await fetch("https://api.anthropic.com/v1/messages", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          model: "claude-sonnet-4-20250514",
          max_tokens: 1000,
          system: context,
          messages: [{ role: "user", content: query }],
        }),
      });
      const data = await res.json();
      setResponse(data.content?.find(b => b.type === "text")?.text || "No response.");
    } catch { setResponse("Connection error."); }
    setLoading(false);
  }

  return (
    <div>
      <div style={{ fontSize: 13, color: "#6b7280", marginBottom: 16 }}>
        The AI analyst has full access to 30 days of price history and knows which ripples confirmed vs. failed.
      </div>
      <div style={{ background: "#0d1117", border: "1px solid #1e2535", borderRadius: 10, overflow: "hidden" }}>
        <div style={{ padding: "12px 16px", borderBottom: "1px solid #1e2535", display: "flex", justifyContent: "space-between" }}>
          <span style={{ fontSize: 11, color: "#4b5563", textTransform: "uppercase", letterSpacing: "0.1em", fontFamily: "'IBM Plex Mono', monospace" }}>AI Analyst — Ripple-Aware</span>
          <span style={{ fontSize: 11, color: "#22c55e", fontFamily: "'IBM Plex Mono', monospace" }}>● 30-day context loaded</span>
        </div>
        <div style={{ padding: 16 }}>
          <div style={{ display: "flex", flexWrap: "wrap", gap: 6, marginBottom: 12 }}>
            {[
              "Did SPCX actually lift RKLB?",
              "Which ripple confirmed most strongly?",
              "Which ripple failed to materialize?",
              "Is it too late to buy ASTS?",
              "Compare NVDA and SPCX ripple strength",
            ].map(q => (
              <button key={q} onClick={() => setQuery(q)} style={{ background: "#111827", border: "1px solid #1e2535", borderRadius: 6, padding: "6px 10px", color: "#9ca3af", fontSize: 11, cursor: "pointer" }}>{q}</button>
            ))}
          </div>
          <textarea
            value={query}
            onChange={e => setQuery(e.target.value)}
            onKeyDown={e => e.key === "Enter" && !e.shiftKey && (e.preventDefault(), ask())}
            placeholder="Ask about trend history, ripple confirmations, timing..."
            rows={2}
            style={{ width: "100%", background: "#111827", border: "1px solid #1e2535", borderRadius: 8, padding: "10px 14px", color: "#e2e8f0", fontSize: 13, outline: "none", resize: "none", fontFamily: "'DM Sans', system-ui, sans-serif", boxSizing: "border-box" }}
          />
          <button onClick={ask} disabled={loading} style={{ marginTop: 8, padding: "9px 20px", background: "#1d4ed8", border: "none", borderRadius: 8, color: "#fff", fontSize: 13, fontWeight: 700, cursor: "pointer" }}>
            {loading ? "Analyzing..." : "Ask →"}
          </button>
          {response && (
            <div style={{ marginTop: 14, background: "#111827", borderRadius: 8, padding: 14, borderLeft: "3px solid #60a5fa" }}>
              <div style={{ fontSize: 10, color: "#4b5563", textTransform: "uppercase", letterSpacing: "0.08em", marginBottom: 6, fontFamily: "'IBM Plex Mono', monospace" }}>Analysis</div>
              <div style={{ fontSize: 13, color: "#e2e8f0", lineHeight: 1.7 }}>{response}</div>
            </div>
          )}
        </div>
      </div>
    </div>
  );
}

// ── MAIN APP ─────────────────────────────────────────────────────────────────
export default function StockPulse() {
  const [tab, setTab] = useState("ripple");
  const [selectedCatalyst, setSelectedCatalyst] = useState(0);
  const [selectedStock, setSelectedStock] = useState(null);

  const allTickers = Object.keys(HISTORY);
  const tabs = [
    { id: "ripple",    label: "Ripple Tracker" },
    { id: "watchlist", label: "Watchlist" },
    { id: "trends",    label: "Compare Trends" },
    { id: "ai",        label: "Ask AI" },
  ];

  return (
    <div style={{ background: "#060a0f", minHeight: "100vh", color: "#e2e8f0", fontFamily: "'DM Sans', system-ui, sans-serif" }}>
      <link href="https://fonts.googleapis.com/css2?family=IBM+Plex+Mono:wght@400;700&family=DM+Sans:wght@400;500;600;700&display=swap" rel="stylesheet" />

      {/* Header */}
      <div style={{ background: "#0d1117", borderBottom: "1px solid #1e2535", padding: "14px 24px", display: "flex", justifyContent: "space-between", alignItems: "center" }}>
        <div>
          <div style={{ fontFamily: "'IBM Plex Mono', monospace", fontSize: 17, fontWeight: 700, color: "#60a5fa", letterSpacing: "0.06em" }}>◈ STOCKPULSE</div>
          <div style={{ fontSize: 10, color: "#374151", fontFamily: "'IBM Plex Mono', monospace", marginTop: 1 }}>Ripple Intelligence · 30-Day History · Trend Verification</div>
        </div>
        <div style={{ textAlign: "right" }}>
          <div style={{ fontSize: 10, color: "#374151", fontFamily: "'IBM Plex Mono', monospace" }}>DATA THROUGH</div>
          <div style={{ fontSize: 13, color: "#f59e0b", fontFamily: "'IBM Plex Mono', monospace", fontWeight: 700 }}>Jun 02, 2026</div>
        </div>
      </div>

      <TickerTape />

      {/* Tabs */}
      <div style={{ display: "flex", gap: 0, background: "#0d1117", borderBottom: "1px solid #1e2535", padding: "0 24px" }}>
        {tabs.map(t => (
          <button key={t.id} onClick={() => setTab(t.id)} style={{
            padding: "10px 18px", fontSize: 13, fontWeight: 600, cursor: "pointer",
            border: "none", background: "transparent",
            color: tab === t.id ? "#60a5fa" : "#6b7280",
            borderBottom: tab === t.id ? "2px solid #60a5fa" : "2px solid transparent",
            transition: "all 0.2s",
          }}>{t.label}</button>
        ))}
      </div>

      <div style={{ padding: 24 }}>

        {/* ── RIPPLE TRACKER ── */}
        {tab === "ripple" && (
          <div>
            {/* Event timeline */}
            <div style={{ background: "#0d1117", border: "1px solid #1e2535", borderRadius: 10, padding: "14px 20px", marginBottom: 20, display: "flex", gap: 20, flexWrap: "wrap" }}>
              <div style={{ fontSize: 10, color: "#4b5563", textTransform: "uppercase", letterSpacing: "0.1em", alignSelf: "center", fontFamily: "'IBM Plex Mono', monospace", minWidth: 80 }}>Key Events</div>
              {EVENTS.map(ev => (
                <div key={ev.day} style={{ display: "flex", alignItems: "center", gap: 8 }}>
                  <div style={{ width: 8, height: 8, background: ev.color, borderRadius: "50%" }} />
                  <span style={{ fontSize: 12, color: ev.color, fontFamily: "'IBM Plex Mono', monospace" }}>{DATES[ev.day]}</span>
                  <span style={{ fontSize: 12, color: "#6b7280" }}>{ev.label}</span>
                </div>
              ))}
            </div>

            {/* Catalyst selector */}
            <div style={{ display: "flex", gap: 10, marginBottom: 20 }}>
              {CATALYSTS.map((c, i) => {
                const h = HISTORY[c.ticker];
                const chg = h ? ((h[h.length-1] - h[c.eventDay]) / h[c.eventDay] * 100).toFixed(1) : "—";
                return (
                  <div key={c.ticker} onClick={() => setSelectedCatalyst(i)} style={{
                    flex: 1, background: selectedCatalyst === i ? "#111827" : "#0d1117",
                    border: `1px solid ${selectedCatalyst === i ? "#f59e0b" : "#1e2535"}`,
                    borderRadius: 8, padding: "12px 16px", cursor: "pointer", transition: "all 0.2s",
                  }}>
                    <div style={{ display: "flex", justifyContent: "space-between", marginBottom: 4 }}>
                      <span style={{ fontFamily: "'IBM Plex Mono', monospace", fontSize: 15, fontWeight: 700, color: "#e2e8f0" }}>{c.ticker}</span>
                      <span style={{ fontSize: 12, color: "#22c55e", fontFamily: "'IBM Plex Mono', monospace" }}>+{chg}% post-event</span>
                    </div>
                    <div style={{ fontSize: 12, color: "#6b7280" }}>{c.event}</div>
                    <div style={{ fontSize: 11, color: "#4b5563", marginTop: 4 }}>{c.ripples.length} tracked ripple stocks</div>
                  </div>
                );
              })}
            </div>

            <RipplePanel catalyst={CATALYSTS[selectedCatalyst]} />
          </div>
        )}

        {/* ── WATCHLIST ── */}
        {tab === "watchlist" && (
          <div>
            {selectedStock && (
              <StockDetail ticker={selectedStock} onClose={() => setSelectedStock(null)} />
            )}
            <div style={{ background: "#0d1117", border: "1px solid #1e2535", borderRadius: 10, overflow: "hidden" }}>
              <div style={{ display: "grid", gridTemplateColumns: "70px 90px 70px 70px 100px 1fr", gap: 10, padding: "8px 16px", borderBottom: "1px solid #1e2535" }}>
                {["Ticker","Price","1D%","30D%","Trend","Ripple Status"].map(h => (
                  <span key={h} style={{ fontSize: 10, color: "#4b5563", textTransform: "uppercase", letterSpacing: "0.08em", fontWeight: 600 }}>{h}</span>
                ))}
              </div>
              {allTickers.map(t => (
                <WatchRow key={t} ticker={t} onSelect={setSelectedStock} selected={selectedStock === t} />
              ))}
            </div>
          </div>
        )}

        {/* ── COMPARE TRENDS ── */}
        {tab === "trends" && (
          <div>
            {CATALYSTS.map(c => (
              <div key={c.ticker} style={{ background: "#0d1117", border: "1px solid #1e2535", borderRadius: 10, overflow: "hidden", marginBottom: 20 }}>
                <div style={{ padding: "12px 16px", borderBottom: "1px solid #1e2535" }}>
                  <div style={{ fontFamily: "'IBM Plex Mono', monospace", fontSize: 13, color: "#f59e0b", fontWeight: 700 }}>{c.ticker} Ripple Network — {c.event}</div>
                  <div style={{ fontSize: 11, color: "#4b5563", marginTop: 2 }}>All lines = % change from May 4. Click Ripple Tracker for individual analysis.</div>
                </div>
                <div style={{ padding: 16 }}>
                  <TrendChart
                    tickers={[c.ticker, ...c.ripples.map(r => r.ticker)]}
                    colors={["#f59e0b","#22c55e","#60a5fa","#a78bfa","#fb923c","#34d399"]}
                    eventDay={c.eventDay}
                    height={220}
                  />
                  {/* Summary row */}
                  <div style={{ display: "flex", flexWrap: "wrap", gap: 8, marginTop: 14 }}>
                    {[c.ticker, ...c.ripples.map(r => r.ticker)].map((t, i) => {
                      const h = HISTORY[t];
                      if (!h) return null;
                      const chgAll = ((h[h.length-1] - h[0]) / h[0] * 100);
                      const chgPost = ((h[h.length-1] - h[c.eventDay]) / h[c.eventDay] * 100);
                      const colors = ["#f59e0b","#22c55e","#60a5fa","#a78bfa","#fb923c","#34d399"];
                      const col = colors[i];
                      return (
                        <div key={t} style={{ background: "#111827", borderRadius: 6, padding: "6px 10px", borderTop: `3px solid ${col}` }}>
                          <div style={{ fontFamily: "'IBM Plex Mono', monospace", fontSize: 12, fontWeight: 700, color: col }}>{t}</div>
                          <div style={{ fontSize: 10, color: "#6b7280" }}>30d: <span style={{ color: chgAll >= 0 ? "#22c55e" : "#ef4444" }}>{chgAll >= 0 ? "+" : ""}{chgAll.toFixed(1)}%</span></div>
                          <div style={{ fontSize: 10, color: "#6b7280" }}>post-event: <span style={{ color: chgPost >= 0 ? "#22c55e" : "#ef4444" }}>{chgPost >= 0 ? "+" : ""}{chgPost.toFixed(1)}%</span></div>
                        </div>
                      );
                    })}
                  </div>
                </div>
              </div>
            ))}
          </div>
        )}

        {/* ── ASK AI ── */}
        {tab === "ai" && <AiAnalyst />}

      </div>
    </div>
  );
}

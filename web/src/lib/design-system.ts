import type { RippleVerdict } from "@/data/catalysts";

export const verdictColors: Record<RippleVerdict, string> = {
  CONFIRMED: "#22c55e",
  FORMING: "#f59e0b",
  FAILED: "#ef4444",
  WATCHING: "#60a5fa",
};

export const verdictBg: Record<RippleVerdict, string> = {
  CONFIRMED: "#22c55e18",
  FORMING: "#f59e0b18",
  FAILED: "#ef444418",
  WATCHING: "#60a5fa18",
};

export const verdictIcons: Record<RippleVerdict, string> = {
  CONFIRMED: "✓",
  FORMING: "◐",
  FAILED: "✗",
  WATCHING: "◎",
};

export const chartColors = [
  "#f59e0b",
  "#22c55e",
  "#60a5fa",
  "#a78bfa",
  "#fb923c",
  "#34d399",
];

export function formatPct(value: number, decimals = 1): string {
  const sign = value >= 0 ? "+" : "";
  return `${sign}${value.toFixed(decimals)}%`;
}

export function formatPrice(value: number): string {
  return `$${value.toFixed(2)}`;
}

export function formatDateShort(iso: string): string {
  const d = new Date(iso);
  return d.toLocaleDateString("en-US", { month: "2-digit", day: "2-digit" });
}

export function formatDateTime(iso: string): string {
  const d = new Date(iso);
  return d.toLocaleString("en-US", {
    month: "short",
    day: "numeric",
    hour: "numeric",
    minute: "2-digit",
  });
}

export function pctChange(series: number[], fromIdx: number, toIdx?: number): number {
  const to = toIdx ?? series.length - 1;
  if (fromIdx < 0 || to >= series.length || series[fromIdx] === 0) return 0;
  return ((series[to] - series[fromIdx]) / series[fromIdx]) * 100;
}

export function normalizeSeries(closes: number[]): number[] {
  if (closes.length === 0) return [];
  const base = closes[0];
  if (base === 0) return closes.map(() => 0);
  return closes.map((v) => ((v - base) / base) * 100);
}

export function findEventDayIndex(dates: string[], eventDate: string): number | null {
  const idx = dates.findIndex((d) => d.startsWith(eventDate));
  return idx >= 0 ? idx : null;
}

export function parseVerdict(v: string): RippleVerdict {
  const upper = v.toUpperCase();
  if (upper === "CONFIRMED" || upper === "FORMING" || upper === "FAILED" || upper === "WATCHING") {
    return upper;
  }
  return "WATCHING";
}

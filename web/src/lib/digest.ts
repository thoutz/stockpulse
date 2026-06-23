import type { APIAlert, APIReport, APISuggestion } from "@/lib/api";

const ET = "America/New_York";

const dayKeyParser = new Intl.DateTimeFormat("en-CA", {
  timeZone: ET,
  year: "numeric",
  month: "2-digit",
  day: "2-digit",
});

function toDayKey(date: Date): string {
  const parts = dayKeyParser.formatToParts(date);
  const y = parts.find((p) => p.type === "year")?.value ?? "";
  const m = parts.find((p) => p.type === "month")?.value ?? "";
  const d = parts.find((p) => p.type === "day")?.value ?? "";
  return `${y}-${m}-${d}`;
}

function parseDayKey(key: string): Date {
  const [y, m, d] = key.split("-").map(Number);
  return new Date(y, m - 1, d);
}

export function todayKey(): string {
  return toDayKey(new Date());
}

export function lastNDayKeys(count: number): string[] {
  const n = Math.min(Math.max(count, 1), 7);
  const keys: string[] = [];
  const now = new Date();
  for (let offset = n - 1; offset >= 0; offset--) {
    const d = new Date(now);
    d.setDate(d.getDate() - offset);
    keys.push(toDayKey(d));
  }
  return keys;
}

export function daySectionLabel(dayKey: string): string {
  const date = parseDayKey(dayKey);
  const short = date.toLocaleDateString("en-US", { month: "short", day: "numeric", timeZone: ET });
  const today = todayKey();
  const yesterday = toDayKey(new Date(Date.now() - 86400000));

  if (dayKey === today) return `Today · ${short}`;
  if (dayKey === yesterday) return `Yesterday · ${short}`;
  const weekday = date.toLocaleDateString("en-US", { weekday: "short", timeZone: ET });
  return `${weekday} · ${short}`;
}

export function timeOnly(iso: string): string {
  return new Date(iso).toLocaleTimeString("en-US", {
    hour: "numeric",
    minute: "2-digit",
  });
}

export function aiStamp(iso: string): string {
  const date = new Date(iso);
  const absolute = date.toLocaleString("en-US", {
    month: "short",
    day: "numeric",
    year: "numeric",
    hour: "numeric",
    minute: "2-digit",
  });
  const interval = (Date.now() - date.getTime()) / 1000;
  let relative: string;
  if (interval < 60) relative = "just now";
  else if (interval < 3600) relative = `${Math.floor(interval / 60)}m ago`;
  else if (interval < 86400) relative = `${Math.floor(interval / 3600)}h ago`;
  else if (interval < 604800) relative = `${Math.floor(interval / 86400)}d ago`;
  else relative = absolute;
  return `${absolute} (${relative})`;
}

export function relativePhrase(iso: string): string {
  const interval = (Date.now() - new Date(iso).getTime()) / 1000;
  if (interval < 60) return "just now";
  if (interval < 3600) return `${Math.floor(interval / 60)}m ago`;
  if (interval < 86400) return `${Math.floor(interval / 3600)}h ago`;
  if (interval < 604800) return `${Math.floor(interval / 86400)}d ago`;
  return new Date(iso).toLocaleDateString("en-US", { month: "short", day: "numeric" });
}

export type DigestRange = 1 | 3 | 7;

export const DIGEST_RANGE_LABELS: Record<DigestRange, string> = {
  1: "1 day",
  3: "3 days",
  7: "7 days",
};

export type AnalysisSection = "reports" | "alerts";

export type ReportSessionSlotId = "pulse_open" | "pulse_midday" | "pulse_close";

export interface ReportSessionSlot {
  id: ReportSessionSlotId;
  label: string;
  subtitle: string;
  sortOrder: number;
}

export const REPORT_SESSION_SLOTS: ReportSessionSlot[] = [
  {
    id: "pulse_open",
    label: "Market Open",
    subtitle: "10:00 AM ET · 30 min after open",
    sortOrder: 0,
  },
  {
    id: "pulse_midday",
    label: "Midday",
    subtitle: "1:00 PM ET · midday check-in",
    sortOrder: 1,
  },
  {
    id: "pulse_close",
    label: "Market Close",
    subtitle: "4:00 PM ET · end of day",
    sortOrder: 2,
  },
];

function isDuringMarketSession(iso: string): boolean {
  const date = new Date(iso);
  const parts = new Intl.DateTimeFormat("en-US", {
    timeZone: ET,
    hour: "numeric",
    minute: "numeric",
    hour12: false,
  }).formatToParts(date);
  const hour = Number(parts.find((p) => p.type === "hour")?.value ?? 0);
  const minute = Number(parts.find((p) => p.type === "minute")?.value ?? 0);
  const minutes = hour * 60 + minute;
  return minutes >= 9 * 60 + 30 && minutes <= 16 * 60;
}

export function isDisplayableReport(reportType: string, createdAt: string): boolean {
  if (
    reportType === "pulse_open" ||
    reportType === "pulse_midday" ||
    reportType === "pulse_close"
  ) {
    return true;
  }
  if (reportType === "pulse") {
    return isDuringMarketSession(createdAt);
  }
  return false;
}

function inferLegacySlot(iso: string): ReportSessionSlotId {
  const date = new Date(iso);
  const parts = new Intl.DateTimeFormat("en-US", {
    timeZone: ET,
    hour: "numeric",
    minute: "numeric",
    hour12: false,
  }).formatToParts(date);
  const hour = Number(parts.find((p) => p.type === "hour")?.value ?? 0);
  const minute = Number(parts.find((p) => p.type === "minute")?.value ?? 0);
  const minutes = hour * 60 + minute;
  if (minutes < 11 * 60 + 30) return "pulse_open";
  if (minutes < 14 * 60 + 30) return "pulse_midday";
  return "pulse_close";
}

export function resolveReportSlot(
  reportType: string,
  createdAt: string,
): ReportSessionSlotId | null {
  if (reportType === "pulse_open" || reportType === "pulse_midday" || reportType === "pulse_close") {
    return reportType;
  }
  if (reportType === "pulse" && isDuringMarketSession(createdAt)) {
    return inferLegacySlot(createdAt);
  }
  return null;
}

export interface DigestDay {
  date: string;
  reports: APIReport[];
  alerts: APIAlert[];
  suggestions: APISuggestion[];
}

export interface ReportSessionGroup {
  id: string;
  dayKey: string;
  slot: ReportSessionSlot;
  reports: APIReport[];
}

export function sessionGroupsForDay(day: DigestDay, showPendingForToday = true): ReportSessionGroup[] {
  const bySlot: Partial<Record<ReportSessionSlotId, APIReport[]>> = {};

  for (const report of day.reports) {
    if (!isDisplayableReport(report.report_type, report.created_at)) continue;
    const slot = resolveReportSlot(report.report_type, report.created_at);
    if (!slot) continue;
    if (!bySlot[slot]) bySlot[slot] = [];
    bySlot[slot]!.push(report);
  }

  const includeEmpty = showPendingForToday && day.date === todayKey();

  return REPORT_SESSION_SLOTS.filter((slot) => {
    const reports = bySlot[slot.id] ?? [];
    return reports.length > 0 || includeEmpty;
  }).map((slot) => ({
    id: `${day.date}:${slot.id}`,
    dayKey: day.date,
    slot,
    reports: (bySlot[slot.id] ?? []).sort(
      (a, b) => new Date(b.created_at).getTime() - new Date(a.created_at).getTime(),
    ),
  }));
}

export function digestDaysInRange(allDays: DigestDay[], range: DigestRange): DigestDay[] {
  const keys = lastNDayKeys(range);
  const byDate = new Map(allDays.map((d) => [d.date, d]));
  return keys.map(
    (key) =>
      byDate.get(key) ?? { date: key, reports: [], alerts: [], suggestions: [] },
  );
}

export function reportDaysInRange(days: DigestDay[], range: DigestRange): DigestDay[] {
  if (range === 1) {
    const today = todayKey();
    const day = days.find((d) => d.date === today) ?? {
      date: today,
      reports: [],
      alerts: [],
      suggestions: [],
    };
    return [day];
  }
  return [...days]
    .reverse()
    .filter((day) => day.reports.some((r) => isDisplayableReport(r.report_type, r.created_at)));
}

export function alertDaysInRange(days: DigestDay[]): DigestDay[] {
  return [...days].reverse().filter((d) => d.alerts.length > 0);
}

export function reportEmptyMessage(days: DigestDay[], rangeLabel: string): string {
  if (days[0]?.date === todayKey()) {
    return "No reports yet today. They generate at 10:00 AM, 1:00 PM, and 4:00 PM ET on trading days.";
  }
  return `No reports in the last ${rangeLabel}.`;
}

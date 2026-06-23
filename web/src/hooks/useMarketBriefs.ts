import { useCallback, useEffect, useState } from "react";
import { api, type APIReport } from "@/lib/api";

function latestPulseOpen(reports: APIReport[]): APIReport | null {
  return reports
    .filter((r) => r.report_type === "pulse_open")
    .sort((a, b) => b.created_at.localeCompare(a.created_at))[0] ?? null;
}

function latestPulse(reports: APIReport[]): APIReport | null {
  return reports
    .filter((r) => r.report_type.startsWith("pulse"))
    .sort((a, b) => b.created_at.localeCompare(a.created_at))[0] ?? null;
}

export function useMarketBriefs(active: boolean) {
  const [whatsNewReport, setWhatsNewReport] = useState<APIReport | null>(null);
  const [researchReport, setResearchReport] = useState<APIReport | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const load = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const reports = await api.reports(30);
      setWhatsNewReport(latestPulseOpen(reports));
      setResearchReport(latestPulse(reports));
    } catch (e) {
      setError(e instanceof Error ? e.message : "Failed to load market brief");
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    if (active) void load();
  }, [active, load]);

  return { whatsNewReport, researchReport, loading, error, reload: load };
}

export function reportBodyText(report: APIReport): string {
  return report.title ? `${report.title}\n\n${report.body}` : report.body;
}

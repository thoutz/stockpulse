import { useCallback, useEffect, useMemo, useState } from "react";
import { api, type APICatalogCatalyst, type APICatalogSector } from "@/lib/api";
import {
  bundledCatalysts,
  bundledWatchlistTickers,
  keyEventsFrom,
  type Catalyst,
  type MarketEvent,
} from "@/data/catalysts";
import {
  bundledIndustries,
  bundledIndustryAccentHex,
  type Industry,
} from "@/data/industries";

function mapCatalyst(row: APICatalogCatalyst): Catalyst | null {
  if (!row.active) return null;
  return {
    ticker: row.ticker,
    name: row.name,
    eventName: row.event_name,
    eventDate: row.event_date,
    ripples: row.ripples.map((r) => ({ ticker: r.ticker, description: r.description })),
    events: [
      {
        date: row.event_date,
        label: row.event_name,
        color: row.confidence_score != null && row.confidence_score >= 50 ? "#22c55e" : "#f59e0b",
      },
    ],
  };
}

function mapSector(row: APICatalogSector): Industry {
  return {
    id: row.id,
    name: row.name,
    description: row.description,
    tickers: row.tickers,
  };
}

export function useCatalog() {
  const [catalysts, setCatalysts] = useState<Catalyst[]>(bundledCatalysts);
  const [industries, setIndustries] = useState<Industry[]>(bundledIndustries);
  const [industryAccentHex, setIndustryAccentHex] = useState<Record<string, string>>(
    bundledIndustryAccentHex,
  );
  const [fromServer, setFromServer] = useState(false);

  const sync = useCallback(async () => {
    try {
      const [catRes, sectorRes] = await Promise.all([
        api.catalogCatalysts(),
        api.catalogSectors(),
      ]);
      const mapped = catRes.catalysts.map(mapCatalyst).filter((c): c is Catalyst => c != null);
      if (mapped.length > 0) {
        setCatalysts(mapped);
      }
      if (sectorRes.sectors.length > 0) {
        setIndustries(sectorRes.sectors.map(mapSector));
        setIndustryAccentHex((prev) => {
          const next = { ...prev };
          for (const s of sectorRes.sectors) {
            next[s.id] = s.accent_hex.startsWith("#") ? s.accent_hex : `#${s.accent_hex}`;
          }
          return next;
        });
      }
      setFromServer(true);
    } catch {
      /* keep bundled fallbacks */
    }
  }, []);

  useEffect(() => {
    void sync();
  }, [sync]);

  const watchlistTickers = useMemo(() => {
    const fromCatalysts = catalysts.flatMap((c) => [c.ticker, ...c.ripples.map((r) => r.ticker)]);
    return [...new Set([...bundledWatchlistTickers, ...fromCatalysts])].sort();
  }, [catalysts]);

  const keyEvents = useMemo((): MarketEvent[] => keyEventsFrom(catalysts), [catalysts]);

  return {
    catalysts,
    industries,
    industryAccentHex,
    watchlistTickers,
    keyEvents,
    fromServer,
    sync,
  };
}

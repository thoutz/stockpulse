import { useEffect, useRef, useState } from "react";
import { MarketTickerDetailCard } from "@/components/MarketTickerDetailCard";
import { SPCard } from "@/components/SPCard";
import { SectionLabel } from "@/components/SectionLabel";
import { Sparkline } from "@/components/Sparkline";
import type { Catalyst } from "@/data/catalysts";
import {
  accentForIndustry,
  displayName,
  indexAccentHex,
  indices,
  type Industry,
} from "@/data/industries";
import type { APIDashboard, APISnapshot } from "@/lib/api";
import { barCloses } from "@/lib/api";
import { formatPct, formatPrice, normalizeSeries } from "@/lib/design-system";
import "../views/MarketView.css";

interface MarketChartSectionsProps {
  dashboard: APIDashboard | null;
  snapshots: Map<string, APISnapshot>;
  industries: Industry[];
  industryAccentHex: Record<string, string>;
  catalysts: Catalyst[];
}

export function MarketChartSections({
  dashboard,
  snapshots,
  industries,
  industryAccentHex,
  catalysts,
}: MarketChartSectionsProps) {
  const [selectedTicker, setSelectedTicker] = useState<string | null>(null);
  const detailRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    if (selectedTicker && detailRef.current) {
      detailRef.current.scrollIntoView({ behavior: "smooth", block: "nearest" });
    }
  }, [selectedTicker]);

  const indexSnaps = indices.map((idx) => {
    const snap = snapshots.get(idx.ticker);
    const bars = dashboard?.histories[idx.ticker] ?? dashboard?.histories_extended[idx.ticker] ?? [];
    const closes = barCloses(bars);
    return { index: idx, snap, closes, normalized: normalizeSeries(closes) };
  });

  const selectTicker = (t: string) => {
    setSelectedTicker((prev) => (prev === t ? null : t));
  };

  return (
    <div className="market-charts">
      <SectionLabel text="Broad Market" />
      <div className="indices-row">
        {indexSnaps.map(({ index, snap, normalized }) => (
          <SPCard key={index.id} className="index-card">
            <div className="index-name">{index.name}</div>
            <div className="mono index-sub">{index.subtitle}</div>
            <div className="mono index-price">
              {snap ? formatPrice(snap.price) : "—"}
            </div>
            {snap && (
              <div className="index-changes">
                <span className={`mono ${snap.change_1d_pct >= 0 ? "positive" : "negative"}`}>
                  1D {formatPct(snap.change_1d_pct)}
                </span>
                <span className={`mono ${snap.change_30d_pct >= 0 ? "positive" : "negative"}`}>
                  30D {formatPct(snap.change_30d_pct)}
                </span>
              </div>
            )}
            {normalized.length > 1 && (
              <Sparkline
                data={normalized}
                color={indexAccentHex[index.id] ?? "#34d399"}
                width={160}
                height={36}
                showArea
                positive={(snap?.change_30d_pct ?? 0) >= 0}
              />
            )}
          </SPCard>
        ))}
      </div>

      {industries.map((ind) => (
        <div key={ind.id} className="industry-section">
          <SectionLabel text={ind.name} />
          <p className="industry-desc">{ind.description}</p>
          <div className="industry-tickers">
            {ind.tickers.map((t) => {
              const snap = snapshots.get(t);
              const bars = dashboard?.histories[t] ?? dashboard?.histories_extended[t] ?? [];
              const closes = barCloses(bars);
              const accent = accentForIndustry(ind.id, industryAccentHex);
              return (
                <SPCard
                  key={t}
                  className={`ticker-card ${selectedTicker === t ? "selected" : ""}`}
                  onClick={() => selectTicker(t)}
                >
                  <div className="mono ticker-card-symbol" style={{ color: accent }}>
                    {t}
                  </div>
                  <div className="ticker-card-name">{displayName(t)}</div>
                  <div className="mono ticker-card-price">
                    {snap ? formatPrice(snap.price) : closes.length ? formatPrice(closes[closes.length - 1]) : "—"}
                  </div>
                  {snap && (
                    <div className={`mono ticker-card-chg ${snap.change_1d_pct >= 0 ? "positive" : "negative"}`}>
                      {formatPct(snap.change_1d_pct)}
                    </div>
                  )}
                  {closes.length > 1 && (
                    <Sparkline
                      data={closes}
                      color={accent}
                      width={100}
                      height={28}
                      positive={(snap?.change_30d_pct ?? 0) >= 0}
                    />
                  )}
                </SPCard>
              );
            })}
          </div>
        </div>
      ))}

      {selectedTicker && dashboard && (
        <div ref={detailRef}>
          <MarketTickerDetailCard
            ticker={selectedTicker}
            dashboard={dashboard}
            snapshots={snapshots}
            industries={industries}
            industryAccentHex={industryAccentHex}
            catalysts={catalysts}
            onClose={() => setSelectedTicker(null)}
            onSelectPeer={setSelectedTicker}
          />
        </div>
      )}
    </div>
  );
}

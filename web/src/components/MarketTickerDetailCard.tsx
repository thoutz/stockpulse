import { useEffect, useState } from "react";
import { PriceChart } from "@/components/PriceChart";
import { SectionLabel } from "@/components/SectionLabel";
import { VerdictBadge } from "@/components/VerdictBadge";
import { SPCard } from "@/components/SPCard";
import { companyBlurb } from "@/data/company-blurbs";
import type { Catalyst } from "@/data/catalysts";
import {
  accentForIndustry,
  catalystLinks,
  displayName,
  industryFor,
  type Industry,
} from "@/data/industries";
import { api, type APIDashboard, type APINewsItem, type APISnapshot } from "@/lib/api";
import { relativePhrase } from "@/lib/digest";
import { parseVerdict, formatPct, formatPrice } from "@/lib/design-system";
import {
  industrySnapshotFor,
  rippleBadgesFor,
  useExtendedHistory,
  type IndustrySnapshot,
} from "@/lib/market-utils";
import "./MarketTickerDetailCard.css";

interface MarketTickerDetailCardProps {
  ticker: string;
  dashboard: APIDashboard;
  snapshots: Map<string, APISnapshot>;
  industries: Industry[];
  industryAccentHex: Record<string, string>;
  catalysts: Catalyst[];
  onClose: () => void;
  onSelectPeer: (ticker: string) => void;
}

export function MarketTickerDetailCard({
  ticker,
  dashboard,
  snapshots,
  industries,
  industryAccentHex,
  catalysts,
  onClose,
  onSelectPeer,
}: MarketTickerDetailCardProps) {
  const sym = ticker.toUpperCase();
  const snap = snapshots.get(sym);
  const industry = industryFor(sym, industries);
  const industrySnap = industrySnapshotFor(sym, dashboard, snapshots, industries);
  const accent = accentForIndustry(industry?.id ?? "semiconductors", industryAccentHex);
  const badges = rippleBadgesFor(sym, dashboard);
  const links = catalystLinks(sym, catalysts);
  const blurb = companyBlurb(sym);

  const [chartDays, setChartDays] = useState<30 | 90>(30);
  const bars = useExtendedHistory(sym, dashboard, chartDays);
  const perf = industrySnap?.constituents.find((c) => c.ticker === sym);

  const [news, setNews] = useState<APINewsItem[]>([]);
  const [industryNews, setIndustryNews] = useState<APINewsItem[]>([]);
  const [newsLoading, setNewsLoading] = useState(true);

  useEffect(() => {
    let cancelled = false;
    setNewsLoading(true);
    void (async () => {
      try {
        const items = await api.news(sym, 5);
        if (!cancelled) setNews(items);
        if (industry && industry.tickers.length > 1) {
          const peers = industry.tickers.filter((t) => t !== sym).slice(0, 3);
          const peerNews = await api.news(peers, 4);
          if (!cancelled) setIndustryNews(peerNews);
        } else {
          setIndustryNews([]);
        }
      } catch {
        if (!cancelled) {
          setNews([]);
          setIndustryNews([]);
        }
      } finally {
        if (!cancelled) setNewsLoading(false);
      }
    })();
    return () => {
      cancelled = true;
    };
  }, [sym, industry]);

  const rank =
    industrySnap?.constituents.findIndex((c) => c.ticker === sym) ?? -1;
  const vsGroup =
    perf && industrySnap ? perf.change30D - industrySnap.avgChange30D : null;

  return (
    <div className="ticker-detail-wrap" style={{ ["--detail-accent" as string]: accent }}>
    <SPCard className="ticker-detail-card">
      <div className="ticker-detail-inner">
        <header className="ticker-detail-header">
          <div>
            <div className="mono ticker-detail-symbol">{sym}</div>
            <div className="ticker-detail-name" style={{ color: accent }}>
              {displayName(sym)}
            </div>
          </div>
          <button type="button" className="ticker-detail-close" onClick={onClose} aria-label="Close">
            ✕
          </button>
        </header>

        {blurb && <p className="company-background">{blurb}</p>}

        {perf && (
          <div className="performance-block">
            <div className="performance-main">
              <span className="mono detail-price">{formatPrice(perf.price)}</span>
              <PctPill label="1D" value={perf.change1D} />
              <PctPill label="30D" value={perf.change30D} />
            </div>
            {industrySnap && (
              <div className="stat-chips">
                {rank >= 0 && (
                  <StatChip
                    label="Group rank"
                    value={`#${rank + 1} of ${industrySnap.breadthTotal}`}
                    color={accent}
                  />
                )}
                {vsGroup != null && (
                  <StatChip
                    label="vs group 30D"
                    value={formatPct(vsGroup)}
                    color={vsGroup >= 0 ? "var(--green)" : "var(--red)"}
                  />
                )}
                <StatChip
                  label="Breadth"
                  value={`${industrySnap.breadthUp}/${industrySnap.breadthTotal} up`}
                  color={
                    industrySnap.breadthUp > industrySnap.breadthTotal / 2
                      ? "var(--green)"
                      : "var(--orange)"
                  }
                />
              </div>
            )}
          </div>
        )}

        {snap && (
          <div className="technicals-row">
            {snap.rsi != null && (
              <TechnicalBadge
                label="RSI"
                value={snap.rsi.toFixed(1)}
                hint={snap.rsi > 70 ? "Overbought" : snap.rsi < 30 ? "Oversold" : "Neutral"}
                tone={snap.rsi > 70 ? "hot" : snap.rsi < 30 ? "cold" : "neutral"}
              />
            )}
            {snap.sma_20 != null && (
              <TechnicalBadge label="SMA 20" value={`$${snap.sma_20.toFixed(2)}`} />
            )}
            {snap.change_5m_pct != null && (
              <TechnicalBadge label="5m" value={formatPct(snap.change_5m_pct)} />
            )}
            {snap.change_15m_pct != null && (
              <TechnicalBadge label="15m" value={formatPct(snap.change_15m_pct)} />
            )}
            {snap.quote_source && (
              <TechnicalBadge label="Quote" value={snap.quote_source} />
            )}
          </div>
        )}

        <div className="chart-section">
          <div className="chart-section-header">
            <SectionLabel text="Price History" />
            <div className="chart-days-toggle">
              <button
                type="button"
                className={chartDays === 30 ? "active" : ""}
                onClick={() => setChartDays(30)}
              >
                30D
              </button>
              <button
                type="button"
                className={chartDays === 90 ? "active" : ""}
                onClick={() => setChartDays(90)}
              >
                90D
              </button>
            </div>
          </div>
          <PriceChart
            bars={bars}
            color={accent}
            height={180}
            sma20={snap?.sma_20}
            positive={(perf?.change30D ?? snap?.change_30d_pct ?? 0) >= 0}
          />
        </div>

        {industry && industrySnap && (
          <GroupContextPanel
            industrySnap={industrySnap}
            ticker={sym}
            accent={accent}
            onSelectPeer={onSelectPeer}
          />
        )}

        {badges.length > 0 && (
          <div className="detail-section">
            <SectionLabel text="Ripple Signals" />
            <div className="ripple-badges-row">
              {badges.map((b) => (
                <VerdictBadge key={b.catalystTicker} verdict={parseVerdict(b.verdict)} />
              ))}
            </div>
          </div>
        )}

        {links.length > 0 && (
          <div className="detail-section">
            <SectionLabel text="Ripple Network" />
            {links.map((l) => (
              <div key={`${l.catalystTicker}-${l.role}`} className="mono ripple-link">
                {l.catalystTicker} — {l.role}
              </div>
            ))}
          </div>
        )}

        <NewsSection title={`${sym} Headlines`} articles={news} loading={newsLoading} accent={accent} />

        {industry && industryNews.length > 0 && (
          <NewsSection
            title={`${industry.name} Pulse`}
            articles={industryNews}
            loading={newsLoading}
            accent={accent}
          />
        )}
      </div>
    </SPCard>
    </div>
  );
}

function PctPill({ label, value }: { label: string; value: number }) {
  return (
    <div className="pct-pill">
      <span className="pct-pill-label">{label}</span>
      <span className={`mono pct-pill-value ${value >= 0 ? "positive" : "negative"}`}>
        {formatPct(value)}
      </span>
    </div>
  );
}

function StatChip({ label, value, color }: { label: string; value: string; color: string }) {
  return (
    <div className="stat-chip" style={{ background: `${color}18` }}>
      <span className="stat-chip-label">{label}</span>
      <span className="mono stat-chip-value" style={{ color }}>
        {value}
      </span>
    </div>
  );
}

function TechnicalBadge({
  label,
  value,
  hint,
  tone,
}: {
  label: string;
  value: string;
  hint?: string;
  tone?: "hot" | "cold" | "neutral";
}) {
  return (
    <div className={`technical-badge tone-${tone ?? "neutral"}`}>
      <span className="technical-label">{label}</span>
      <span className="mono technical-value">{value}</span>
      {hint && <span className="technical-hint">{hint}</span>}
    </div>
  );
}

function GroupContextPanel({
  industrySnap,
  ticker,
  accent,
  onSelectPeer,
}: {
  industrySnap: IndustrySnapshot;
  ticker: string;
  accent: string;
  onSelectPeer: (t: string) => void;
}) {
  const { industry, avgChange1D } = industrySnap;
  return (
    <div className="group-context" style={{ background: `${accent}10` }}>
      <div className="group-context-header">
        <SectionLabel text={industry.name} />
        <span className={`mono group-avg ${avgChange1D >= 0 ? "positive" : "negative"}`}>
          {formatPct(avgChange1D)} avg 1D
        </span>
      </div>
      <p className="group-desc">{industry.description}</p>
      <div className="peer-scroll">
        {industrySnap.constituents.map((peer) => (
          <button
            key={peer.ticker}
            type="button"
            className={`peer-chip ${peer.ticker === ticker ? "selected" : ""}`}
            style={
              peer.ticker === ticker
                ? { borderColor: `${accent}80`, background: `${accent}26`, color: accent }
                : undefined
            }
            onClick={() => onSelectPeer(peer.ticker)}
          >
            <span className="mono peer-ticker">{peer.ticker}</span>
            <span className={`mono peer-chg ${peer.change1D >= 0 ? "positive" : "negative"}`}>
              {formatPct(peer.change1D)}
            </span>
          </button>
        ))}
      </div>
    </div>
  );
}

function NewsSection({
  title,
  articles,
  loading,
  accent,
}: {
  title: string;
  articles: APINewsItem[];
  loading: boolean;
  accent: string;
}) {
  return (
    <div className="detail-section news-section">
      <SectionLabel text={title} />
      {loading ? (
        <div className="news-loading">Loading headlines…</div>
      ) : articles.length === 0 ? (
        <p className="news-empty">No recent headlines. News refreshes every 15 minutes.</p>
      ) : (
        articles.map((a) => <NewsRow key={a.url} article={a} accent={accent} />)
      )}
    </div>
  );
}

function NewsRow({ article, accent }: { article: APINewsItem; accent: string }) {
  const sentimentColor =
    article.sentiment_score == null
      ? accent
      : article.sentiment_score > 0.15
        ? "var(--green)"
        : article.sentiment_score < -0.15
          ? "var(--red)"
          : "var(--orange)";

  const sentimentLabel =
    article.sentiment_score == null
      ? null
      : article.sentiment_score > 0.15
        ? "Bullish"
        : article.sentiment_score < -0.15
          ? "Bearish"
          : "Neutral";

  return (
    <a href={article.url} target="_blank" rel="noopener noreferrer" className="news-row">
      <span className="news-sentiment-bar" style={{ background: sentimentColor }} />
      <div className="news-content">
        <div className="news-headline">{article.headline}</div>
        {article.summary && <div className="news-summary">{article.summary.slice(0, 120)}…</div>}
        <div className="news-meta">
          {article.source && (
            <span className="mono news-source" style={{ color: accent }}>
              {article.source}
            </span>
          )}
          <span className="mono news-time">{relativePhrase(article.published_at)}</span>
          {sentimentLabel && (
            <span className="news-sentiment-tag" style={{ color: sentimentColor }}>
              {sentimentLabel}
            </span>
          )}
        </div>
      </div>
      <span className="news-external">↗</span>
    </a>
  );
}

import { verdictColors } from "@/lib/design-system";

interface TextSegment {
  text: string;
  className?: string;
  style?: React.CSSProperties;
}

const COMMON_WORDS = new Set([
  "AI", "AM", "PM", "ET", "UTC", "USD", "THE", "AND", "FOR", "NEW", "ALL", "TOP",
]);

const NEGATIVE_WORDS = [
  "drop", "drops", "dropped", "decline", "declined", "fall", "fell",
  "loss", "losses", "down", "lower", "slide", "slid", "sink", "retreat",
  "weaken", "underperform", "selloff", "sell-off", "off",
];

const POSITIVE_WORDS = [
  "gain", "gains", "gained", "rose", "rise", "rally", "climb", "jump",
  "surge", "up", "higher", "beat", "rebound", "advance", "bullish",
];

interface Match {
  start: number;
  end: number;
  className?: string;
  style?: React.CSSProperties;
}

function addMatches(text: string, pattern: RegExp, match: (snippet: string) => Match | null): Match[] {
  const results: Match[] = [];
  for (const m of text.matchAll(pattern)) {
    if (m.index === undefined) continue;
    const snippet = m[0];
    const resolved = match(snippet);
    if (resolved) {
      results.push({ ...resolved, start: m.index, end: m.index + snippet.length });
    }
  }
  return results;
}

function contextSentiment(text: string, at: number): "positive" | "negative" | null {
  const start = Math.max(0, at - 45);
  const context = text.slice(start, at).toLowerCase();
  let closest = -1;
  let sentiment: "positive" | "negative" | null = null;

  for (const word of NEGATIVE_WORDS) {
    const idx = context.lastIndexOf(word);
    if (idx > closest) {
      closest = idx;
      sentiment = "negative";
    }
  }
  for (const word of POSITIVE_WORDS) {
    const idx = context.lastIndexOf(word);
    if (idx > closest) {
      closest = idx;
      sentiment = "positive";
    }
  }
  return sentiment;
}

function collectMatches(text: string): Match[] {
  let matches: Match[] = [];

  matches = matches.concat(
    addMatches(text, /^#{1,2}\s*.+$/gm, () => ({
      start: 0,
      end: 0,
      className: "hr-heading",
    })),
  );

  matches = matches.concat(
    addMatches(text, /\b(CONFIRMED|FORMING|FAILED|WATCHING)\b/g, (snippet) => ({
      start: 0,
      end: 0,
      style: { color: verdictColors[snippet as keyof typeof verdictColors] ?? "var(--blue)" },
      className: "mono bold",
    })),
  );

  matches = matches.concat(
    addMatches(text, /[+-]?\d+(?:\.\d+)?%/g, (snippet) => {
      let color = "var(--text-second)";
      if (snippet.startsWith("-")) color = "var(--red)";
      else if (snippet.startsWith("+")) color = "var(--green)";
      else {
        const sentiment = contextSentiment(text, text.indexOf(snippet));
        if (sentiment === "negative") color = "var(--red)";
        else if (sentiment === "positive") color = "var(--green)";
      }
      return { start: 0, end: 0, style: { color }, className: "mono bold" };
    }),
  );

  matches = matches.concat(
    addMatches(text, /\b[A-Z]{2,5}\b/g, (snippet) => {
      if (COMMON_WORDS.has(snippet)) return null;
      return { start: 0, end: 0, style: { color: "var(--orange)" }, className: "mono bold" };
    }),
  );

  matches = matches.concat(
    addMatches(text, /\b(WATCH|AVOID)\b/g, (snippet) => ({
      start: 0,
      end: 0,
      style: { color: snippet === "WATCH" ? "var(--green)" : "var(--red)" },
      className: "mono bold",
    })),
  );

  matches = matches.concat(
    addMatches(
      text,
      /\b(bullish|bearish|neutral|RSI|SMA|overbought|oversold|breakout|support|resistance)\b/gi,
      () => ({ start: 0, end: 0, style: { color: "var(--purple)" }, className: "semibold" }),
    ),
  );

  return matches;
}

function segmentsFromMatches(text: string, matches: Match[]): TextSegment[] {
  if (matches.length === 0) return [{ text }];

  const sorted = [...matches].sort((a, b) => a.start - b.start || b.end - a.end);
  const occupied: boolean[] = new Array(text.length).fill(false);
  const picked: Match[] = [];

  for (const m of sorted) {
    let overlap = false;
    for (let i = m.start; i < m.end; i++) {
      if (occupied[i]) {
        overlap = true;
        break;
      }
    }
    if (overlap) continue;
    for (let i = m.start; i < m.end; i++) occupied[i] = true;
    picked.push(m);
  }

  picked.sort((a, b) => a.start - b.start);
  const segments: TextSegment[] = [];
  let cursor = 0;

  for (const m of picked) {
    if (m.start > cursor) segments.push({ text: text.slice(cursor, m.start) });
    segments.push({
      text: text.slice(m.start, m.end),
      className: m.className,
      style: m.style,
    });
    cursor = m.end;
  }
  if (cursor < text.length) segments.push({ text: text.slice(cursor) });

  return segments;
}

interface HighlightedReportTextProps {
  text: string;
  fontSize?: number;
  emphasis?: boolean;
}

export function HighlightedReportText({
  text,
  fontSize = 12,
  emphasis = false,
}: HighlightedReportTextProps) {
  const matches = collectMatches(text);
  const segments = segmentsFromMatches(text, matches);

  return (
    <span
      className="highlighted-report"
      style={{
        fontSize,
        color: emphasis ? "var(--text-primary)" : "var(--text-second)",
        lineHeight: 1.6,
        whiteSpace: "pre-wrap",
      }}
    >
      {segments.map((seg, i) => (
        <span
          key={i}
          className={seg.className}
          style={seg.style}
        >
          {seg.text}
        </span>
      ))}
    </span>
  );
}

interface ParsedReportBody {
  whatsNew: string | null;
  researchWatchlist: string | null;
  context: string | null;
  remainder: string;
  hasStructuredSections: boolean;
}

function parseReportBody(body: string): ParsedReportBody {
  const lines = body.split("\n");
  const whatsNew: string[] = [];
  const research: string[] = [];
  const context: string[] = [];
  const remainder: string[] = [];
  let section: "new" | "research" | "context" | null = null;

  for (const line of lines) {
    const trimmed = line.trim();
    if (/^#{0,2}\s*what'?s new\s*$/i.test(trimmed)) {
      section = "new";
      continue;
    }
    if (/^#{0,2}\s*research watchlist\s*$/i.test(trimmed)) {
      section = "research";
      continue;
    }
    if (/^#{0,2}\s*context\s*$/i.test(trimmed)) {
      section = "context";
      continue;
    }
    if (section === "new") whatsNew.push(line);
    else if (section === "research") research.push(line);
    else if (section === "context") context.push(line);
    else remainder.push(line);
  }

  const newText = whatsNew.join("\n").trim() || null;
  const researchText = research.join("\n").trim() || null;
  const contextText = context.join("\n").trim() || null;
  const restText = remainder.join("\n").trim();

  if (newText || researchText || contextText) {
    return {
      whatsNew: newText,
      researchWatchlist: researchText,
      context: contextText,
      remainder: restText,
      hasStructuredSections: true,
    };
  }
  return { whatsNew: null, researchWatchlist: null, context: null, remainder: body, hasStructuredSections: false };
}

export function MarketTabReportBody({
  bodyText,
  mode,
}: {
  bodyText: string;
  mode: "whatsNewOnly" | "researchOnly";
}) {
  const parsed = parseReportBody(bodyText);

  if (mode === "whatsNewOnly") {
    const text = parsed.whatsNew ?? bodyText;
    return <HighlightedReportText text={text} fontSize={13} emphasis />;
  }

  if (parsed.researchWatchlist) {
    return <HighlightedReportText text={parsed.researchWatchlist} fontSize={12} emphasis />;
  }
  return <p className="empty-hint">No research watchlist in the latest pulse yet.</p>;
}

export function StructuredReportBody({ bodyText }: { bodyText: string }) {
  const parsed = parseReportBody(bodyText);

  return (
    <div className="structured-report">
      {parsed.whatsNew && (
        <div className="structured-section">
          <div className="structured-label whats-new">WHAT&apos;S NEW</div>
          <HighlightedReportText text={parsed.whatsNew} fontSize={13} emphasis />
        </div>
      )}
      {parsed.researchWatchlist && (
        <div className="structured-section">
          <div className="structured-label research-label">RESEARCH WATCHLIST</div>
          <HighlightedReportText text={parsed.researchWatchlist} fontSize={12} emphasis />
        </div>
      )}
      {parsed.context && (
        <details className="structured-context">
          <summary className="structured-label context-label">Background context</summary>
          <HighlightedReportText text={parsed.context} fontSize={11} />
        </details>
      )}
      {parsed.remainder && (
        <HighlightedReportText
          text={parsed.remainder}
          fontSize={parsed.hasStructuredSections ? 11 : 12}
          emphasis={!parsed.hasStructuredSections}
        />
      )}
    </div>
  );
}

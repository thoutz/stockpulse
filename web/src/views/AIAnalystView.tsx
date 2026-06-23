import { useEffect, useState } from "react";
import { HighlightedReportText } from "@/components/HighlightedReportText";
import { SectionLabel } from "@/components/SectionLabel";
import { ViewHeader } from "@/components/ViewHeader";
import { api } from "@/lib/api";
import { fallbackChatPrompts, normalizeChatPrompts } from "@/lib/chatPrompts";
import { aiStamp } from "@/lib/digest";
import "./AIAnalystView.css";

interface AIAnalystViewProps {
  usesLiveData: boolean;
}

export function AIAnalystView({ usesLiveData }: AIAnalystViewProps) {
  const [query, setQuery] = useState("");
  const [response, setResponse] = useState("");
  const [responseAt, setResponseAt] = useState<Date | null>(null);
  const [loading, setLoading] = useState(false);
  const [chatPrompts, setChatPrompts] = useState<string[]>([]);

  useEffect(() => {
    let cancelled = false;
    void (async () => {
      try {
        const prompts = normalizeChatPrompts(await api.chatPrompts());
        if (!cancelled && prompts.length > 0) {
          setChatPrompts(prompts);
          return;
        }
      } catch {
        // Fall through to local fallback.
      }
      if (!cancelled) {
        setChatPrompts(await fallbackChatPrompts());
      }
    })();
    return () => {
      cancelled = true;
    };
  }, []);

  const statusLabel = usesLiveData ? "Server assistant + data" : "Waiting for market data";

  const askAI = async (prompt?: string) => {
    const text = (prompt ?? query).trim();
    if (!text) return;
    setLoading(true);
    setResponse("");
    setResponseAt(null);
    try {
      const res = await api.chat(text, 0);
      setResponse(res.response);
      setResponseAt(new Date());
      if (prompt) setQuery(prompt);
    } catch (e) {
      setResponse(e instanceof Error ? e.message : "Server AI error.");
      setResponseAt(new Date());
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="ai-view">
      <ViewHeader title="Ask AI" live={usesLiveData} liveLabel={statusLabel} />

      <div className="view-section">
        <div className="suggestion-chips">
          {chatPrompts.map((q) => (
            <button key={q} type="button" className="suggestion-chip" onClick={() => void askAI(q)}>
              {q}
            </button>
          ))}
        </div>

        <div className="chat-input-row">
          <textarea
            value={query}
            onChange={(e) => setQuery(e.target.value)}
            placeholder="Ask about ripples, timing, trends..."
            rows={2}
            className="chat-input"
            onKeyDown={(e) => {
              if (e.key === "Enter" && !e.shiftKey) {
                e.preventDefault();
                void askAI();
              }
            }}
          />
          <button
            type="button"
            className={`chat-send ${loading ? "spinning" : ""}`}
            disabled={!query.trim() || loading}
            onClick={() => void askAI()}
            aria-label="Send"
          >
            {loading ? "↻" : "↑"}
          </button>
        </div>

        {response && (
          <div className="ai-response">
            <div className="ai-response-header">
              <SectionLabel text="Analysis" />
              {responseAt && (
                <span className="mono ai-response-time">{aiStamp(responseAt.toISOString())}</span>
              )}
            </div>
            <HighlightedReportText text={response} fontSize={14} emphasis />
          </div>
        )}

        {loading && !response && (
          <div className="ai-loading">
            <span className="ai-spinner" />
            Analyzing market data...
          </div>
        )}
      </div>
    </div>
  );
}

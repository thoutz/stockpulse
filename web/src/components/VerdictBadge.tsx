import type { RippleVerdict } from "@/data/catalysts";
import { verdictBg, verdictColors, verdictIcons } from "@/lib/design-system";
import "./VerdictBadge.css";

export function VerdictBadge({ verdict }: { verdict: RippleVerdict | string }) {
  const v = verdict.toUpperCase() as RippleVerdict;
  const color = verdictColors[v] ?? verdictColors.WATCHING;
  const bg = verdictBg[v] ?? verdictBg.WATCHING;
  const icon = verdictIcons[v] ?? verdictIcons.WATCHING;

  return (
    <span className="verdict-badge" style={{ color, background: bg }}>
      <span>{icon}</span>
      {v}
    </span>
  );
}

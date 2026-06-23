import type { AppTab } from "@/lib/api";
import "./TabBar.css";

const tabs: { id: AppTab; label: string; icon: string }[] = [
  { id: "pulse", label: "Pulse", icon: "♡" },
  { id: "watchlist", label: "Monitor", icon: "◎" },
  { id: "analyst", label: "Analyst", icon: "▤" },
  { id: "ai", label: "AI", icon: "◈" },
];

interface TabBarProps {
  selected: AppTab;
  onSelect: (tab: AppTab) => void;
}

export function TabBar({ selected, onSelect }: TabBarProps) {
  return (
    <nav className="tab-bar" aria-label="Main navigation">
      {tabs.map((tab) => (
        <button
          key={tab.id}
          type="button"
          className={`tab-item ${selected === tab.id ? "active" : ""}`}
          onClick={() => onSelect(tab.id)}
          aria-current={selected === tab.id ? "page" : undefined}
        >
          <span className="tab-icon">{tab.icon}</span>
          <span className="tab-label">{tab.label}</span>
        </button>
      ))}
    </nav>
  );
}

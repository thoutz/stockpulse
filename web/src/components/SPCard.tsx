import { ReactNode } from "react";
import "./SPCard.css";

interface SPCardProps {
  children: ReactNode;
  className?: string;
  onClick?: () => void;
}

export function SPCard({ children, className = "", onClick }: SPCardProps) {
  return (
    <div className={`sp-card ${className}`} onClick={onClick} role={onClick ? "button" : undefined}>
      {children}
    </div>
  );
}

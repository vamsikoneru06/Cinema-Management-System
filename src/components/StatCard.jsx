// StatCard — KPI card with optional live-update indicator
// Props:
//   label   string   e.g. "Total Revenue"
//   value   string|number
//   sub     string   optional note below value
//   icon    string   emoji
//   accent  string   CSS hex colour (used for glow + icon bg)
//   live    boolean  shows animated "LIVE" badge
//   pulse   boolean  triggers value flash animation

import React from "react";
import "./StatCard.css";

function hexToRgb(hex) {
  const clean = hex.replace("#", "");
  const r = parseInt(clean.slice(0,2),16);
  const g = parseInt(clean.slice(2,4),16);
  const b = parseInt(clean.slice(4,6),16);
  return `${r},${g},${b}`;
}

export default function StatCard({ label, value, sub, icon, accent, live = false, pulse = false }) {
  const style = accent
    ? { "--stat-accent": accent, "--stat-rgb": hexToRgb(accent) }
    : {};

  return (
    <div className="stat-card" style={style}>
      {icon && <div className="stat-card__icon">{icon}</div>}

      <div className="stat-card__body">
        <p className="stat-card__label">{label}</p>
        <p className={`stat-card__value${pulse ? " stat-card__value--live" : ""}`}>
          {value !== undefined && value !== null ? value : "—"}
        </p>
        {sub && <p className="stat-card__sub">{sub}</p>}
      </div>

      {live && (
        <div className="stat-card__live">
          <span className="stat-card__live-dot" />
          Live
        </div>
      )}
    </div>
  );
}

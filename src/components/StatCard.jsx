// ============================================================
//  components/StatCard.jsx
//  Displays a single KPI metric on the Dashboard.
//
//  Props:
//    label   – string  e.g. "Total Movies"
//    value   – number | string
//    sub     – string  (optional) small note below value
//    icon    – string  (optional) emoji / character
//    accent  – string  (optional) CSS colour for left border
// ============================================================

import React from "react";
import "./StatCard.css";

export default function StatCard({ label, value, sub, icon, accent }) {
  const style = accent
    ? { "--stat-accent": accent }
    : {};

  return (
    <div className="stat-card" style={style}>
      {icon && <div className="stat-card__icon">{icon}</div>}
      <div className="stat-card__body">
        <p className="stat-card__label">{label}</p>
        <p className="stat-card__value">
          {value !== undefined && value !== null ? value : "—"}
        </p>
        {sub && <p className="stat-card__sub">{sub}</p>}
      </div>
    </div>
  );
}

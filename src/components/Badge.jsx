// ============================================================
//  components/Badge.jsx
//  Inline coloured status / label badge.
//
//  Props:
//    text    – string  text to display
//    variant – "success" | "warning" | "danger" | "info"
//              | "purple" | "orange" | "default"
// ============================================================

import React from "react";
import "./Badge.css";

const VARIANT_MAP = {
  success: "badge--success",
  warning: "badge--warning",
  danger:  "badge--danger",
  info:    "badge--info",
  purple:  "badge--purple",
  orange:  "badge--orange",
  default: "badge--default",
};

export default function Badge({ text, variant = "default" }) {
  const cls = VARIANT_MAP[variant] || VARIANT_MAP.default;
  return (
    <span className={`badge ${cls}`}>
      {text}
    </span>
  );
}

// ── Convenience helper used in table column renderers ────────
export function paymentStatusBadge(status) {
  const map = {
    paid:      { text: "Paid",      variant: "success" },
    pending:   { text: "Pending",   variant: "warning" },
    cancelled: { text: "Cancelled", variant: "danger"  },
  };
  const p = map[status?.toLowerCase()] || { text: status, variant: "default" };
  return <Badge text={p.text} variant={p.variant} />;
}

export function bookingStatusBadge(status) {
  const map = {
    available: { text: "Available", variant: "success" },
    booked:    { text: "Booked",    variant: "info"    },
    reserved:  { text: "Reserved",  variant: "warning" },
  };
  const p = map[status?.toLowerCase()] || { text: status, variant: "default" };
  return <Badge text={p.text} variant={p.variant} />;
}

export function genreBadge(genre) {
  const map = {
    action:   "danger",
    drama:    "info",
    masala:   "orange",
    thriller: "purple",
    comedy:   "success",
  };
  return <Badge text={genre} variant={map[genre?.toLowerCase()] || "default"} />;
}

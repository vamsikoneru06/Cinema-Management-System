// ============================================================
//  pages/Bookings.jsx
//  View all bookings; filter by status; cancel bookings.
// ============================================================

import React, { useEffect, useState, useCallback } from "react";
import DataTable from "../components/DataTable";
import { paymentStatusBadge } from "../components/Badge";
import { bookingApi } from "../services/api";
import "./Page.css";

const STATUS_FILTERS = ["all", "paid", "pending", "cancelled"];

const COLUMNS = [
  { key: "booking_id",     label: "ID",        render: (v) => `#BK${String(v).padStart(3, "0")}` },
  { key: "customer_name",  label: "Customer",  render: (v) => <strong>{v}</strong> },
  { key: "movie_title",    label: "Movie"      },
  { key: "booking_date",   label: "Date",      render: (v) => v ? new Date(v).toLocaleDateString("en-IN") : "—" },
  {
    key: "total_amount", label: "Amount",
    render: (v) => v != null ? `₹${Number(v).toLocaleString("en-IN")}` : "—",
  },
  { key: "payment_status", label: "Status",    render: (v) => paymentStatusBadge(v) },
];

export default function Bookings() {
  const [bookings,  setBookings ] = useState([]);
  const [loading,   setLoading  ] = useState(true);
  const [error,     setError    ] = useState(null);
  const [toast,     setToast    ] = useState(null);
  const [activeFilter, setActiveFilter] = useState("all");

  const fetchBookings = useCallback(async () => {
    setLoading(true); setError(null);
    try {
      const data = await bookingApi.getAll();
      setBookings(Array.isArray(data) ? data : []);
    } catch (err) { setError(err.message); }
    finally { setLoading(false); }
  }, []);

  useEffect(() => { fetchBookings(); }, [fetchBookings]);

  const showToast = (msg, type = "success") => {
    setToast({ msg, type });
    setTimeout(() => setToast(null), 3000);
  };

  // Cancel a booking
  const handleCancel = async (row) => {
    if (row.payment_status === "cancelled") return;
    if (!window.confirm(`Cancel booking #BK${String(row.booking_id).padStart(3, "0")}?`)) return;
    try {
      await bookingApi.update(row.booking_id, { payment_status: "cancelled" });
      showToast("Booking cancelled. Trigger logged the change.");
      fetchBookings();
    } catch (err) { showToast(err.message, "error"); }
  };

  // Filter data client-side
  const filtered = activeFilter === "all"
    ? bookings
    : bookings.filter((b) => b.payment_status === activeFilter);

  // Stats
  const paidTotal = bookings
    .filter((b) => b.payment_status === "paid")
    .reduce((s, b) => s + Number(b.total_amount || 0), 0);

  // Custom actions column (cancel button)
  const columnsWithCancel = [
    ...COLUMNS,
    {
      key: "_actions", label: "Actions",
      render: (_, row) =>
        row.payment_status !== "cancelled" ? (
          <button className="btn btn--sm btn--danger" onClick={() => handleCancel(row)}>
            Cancel
          </button>
        ) : null,
    },
  ];

  return (
    <div className="page">
      {toast && <div className={`toast toast--${toast.type}`}>{toast.msg}</div>}

      <div className="page-header">
        <h1 className="page-title">Bookings</h1>
        <span style={{ fontSize: 14, color: "#555" }}>
          Revenue: <strong>₹{paidTotal.toLocaleString("en-IN")}</strong>
        </span>
      </div>

      {error && <div className="alert alert--error">⚠ {error}</div>}

      {/* Status filter pills */}
      <div className="filter-bar">
        {STATUS_FILTERS.map((s) => (
          <button
            key={s}
            className={`filter-btn${activeFilter === s ? " filter-btn--active" : ""}`}
            onClick={() => setActiveFilter(s)}
          >
            {s === "all" ? "All" : s.charAt(0).toUpperCase() + s.slice(1)}
            {" "}({s === "all" ? bookings.length : bookings.filter((b) => b.payment_status === s).length})
          </button>
        ))}
      </div>

      <DataTable
        title="Booking Records"
        columns={columnsWithCancel}
        data={filtered}
        loading={loading}
        searchKeys={["customer_name", "movie_title"]}
      />
    </div>
  );
}

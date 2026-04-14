// ============================================================
//  pages/Dashboard.jsx
//  Overview page: KPI stats + top-rated movies bar chart.
// ============================================================

import React, { useEffect, useState, useCallback } from "react";
import StatCard from "../components/StatCard";
import { dashboardApi, movieApi } from "../services/api";
import "./Dashboard.css";

// Fallback stats shape so UI never crashes
const EMPTY_STATS = {
  totalMovies:    0,
  totalCustomers: 0,
  totalBookings:  0,
  totalRevenue:   0,
  pendingBookings:   0,
  cancelledBookings: 0,
  activeShows:    0,
  totalReviews:   0,
};

export default function Dashboard() {
  const [stats,      setStats     ] = useState(EMPTY_STATS);
  const [topMovies,  setTopMovies ] = useState([]);
  const [loading,    setLoading   ] = useState(true);
  const [error,      setError     ] = useState(null);

  const fetchData = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const [statsData, moviesData] = await Promise.all([
        dashboardApi.getStats(),
        movieApi.getAll({ sort: "rating", order: "desc", limit: 6 }),
      ]);
      setStats({ ...EMPTY_STATS, ...statsData });
      setTopMovies(Array.isArray(moviesData) ? moviesData.slice(0, 6) : []);
    } catch (err) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => { fetchData(); }, [fetchData]);

  const maxRating = Math.max(...topMovies.map((m) => Number(m.rating) || 0), 10);

  return (
    <div className="page">
      <div className="page-header">
        <h1 className="page-title">Dashboard</h1>
        <button className="btn btn--secondary btn--sm" onClick={fetchData}>
          ↻ Refresh
        </button>
      </div>

      {error && (
        <div className="alert alert--error">
          ⚠ Could not load dashboard data: {error}
        </div>
      )}

      {/* ── KPI Cards ── */}
      <section className="dash-stats">
        <StatCard icon="🎬" label="Total Movies"    value={loading ? "…" : stats.totalMovies}    accent="#c0392b" />
        <StatCard icon="👥" label="Customers"        value={loading ? "…" : stats.totalCustomers} accent="#2980b9" />
        <StatCard icon="🎟" label="Total Bookings"   value={loading ? "…" : stats.totalBookings}  accent="#27ae60" />
        <StatCard
          icon="₹"
          label="Revenue (Paid)"
          value={loading ? "…" : "₹" + Number(stats.totalRevenue || 0).toLocaleString("en-IN")}
          sub="INR"
          accent="#f39c12"
        />
        <StatCard icon="⏳" label="Pending Bookings"   value={loading ? "…" : stats.pendingBookings}   accent="#e67e22" />
        <StatCard icon="❌" label="Cancelled Bookings" value={loading ? "…" : stats.cancelledBookings} accent="#95a5a6" />
        <StatCard icon="📺" label="Active Shows"       value={loading ? "…" : stats.activeShows}       accent="#8e44ad" />
        <StatCard icon="⭐" label="Reviews"             value={loading ? "…" : stats.totalReviews}      accent="#16a085" />
      </section>

      {/* ── Top Rated Movies ── */}
      <section className="dash-section">
        <div className="dash-section-header">
          <h2 className="dash-section-title">Top Rated Movies</h2>
          {topMovies.length > 0 && (
            <span className="dash-section-sub">by IMDB rating</span>
          )}
        </div>

        {loading ? (
          <div className="dash-loading">Loading chart…</div>
        ) : topMovies.length === 0 ? (
          <div className="dash-empty">No movie data available.</div>
        ) : (
          <div className="dash-chart">
            {topMovies.map((movie) => {
              const pct = Math.round(((Number(movie.rating) || 0) / maxRating) * 100);
              return (
                <div className="dash-bar-row" key={movie.movie_id ?? movie.id}>
                  <span className="dash-bar-label" title={movie.title}>
                    {movie.title}
                  </span>
                  <div className="dash-bar-track">
                    <div
                      className="dash-bar-fill"
                      style={{ width: `${pct}%` }}
                    />
                  </div>
                  <span className="dash-bar-val">{movie.rating}</span>
                </div>
              );
            })}
          </div>
        )}
      </section>

      {/* ── Info Banner ── */}
      <section className="dash-info">
        <p>
          <strong>API connection:</strong> All data is fetched from{" "}
          <code>http://localhost:5000/api</code>. Start your Express backend
          before using this dashboard.
        </p>
      </section>
    </div>
  );
}

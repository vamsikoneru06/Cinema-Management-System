import React, { useEffect, useState, useCallback, useRef } from "react";
import StatCard from "../components/StatCard";
import { dashboardApi, movieApi } from "../services/api";
import "./Dashboard.css";

const EMPTY_STATS = {
  totalMovies:       0,
  totalCustomers:    0,
  totalBookings:     0,
  totalRevenue:      0,
  pendingBookings:   0,
  cancelledBookings: 0,
  activeShows:       0,
  totalReviews:      0,
  avgMovieRating:    0,
  totalCities:       0,
};

function fmtINR(n) {
  return Number(n || 0).toLocaleString("en-IN");
}

function fmtDate(iso) {
  if (!iso) return null;
  const d = new Date(iso);
  return d.toLocaleTimeString("en-IN", { hour: "2-digit", minute: "2-digit", hour12: true });
}

export default function Dashboard() {
  const [stats,       setStats      ] = useState(EMPTY_STATS);
  const [topMovies,   setTopMovies  ] = useState([]);
  const [trendData,   setTrendData  ] = useState([]);
  const [loading,     setLoading    ] = useState(true);
  const [error,       setError      ] = useState(null);
  const [liveRevenue, setLiveRevenue] = useState(null);
  const [lastUpdated, setLastUpdated] = useState(null);
  const [revPulse,    setRevPulse   ] = useState(false);
  const [sseConnected,setSseConnected] = useState(false);

  const prevRevRef = useRef(null);

  // ── Initial data fetch ───────────────────────────────────
  const fetchData = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const [statsData, moviesData, trend] = await Promise.all([
        dashboardApi.getStats(),
        movieApi.getAll(),
        fetch("http://localhost:5000/api/revenue/trend").then((r) => r.json()).catch(() => []),
      ]);
      setStats({ ...EMPTY_STATS, ...statsData });
      setTopMovies(Array.isArray(moviesData) ? moviesData.slice(0, 7) : []);
      setTrendData(Array.isArray(trend) ? trend : []);
      if (statsData.totalRevenue != null && liveRevenue === null) {
        setLiveRevenue(Number(statsData.totalRevenue));
      }
    } catch (err) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  }, [liveRevenue]);

  useEffect(() => { fetchData(); }, []); // eslint-disable-line

  // ── SSE – live revenue stream ────────────────────────────
  useEffect(() => {
    let es;
    function connect() {
      es = new EventSource("http://localhost:5000/api/revenue/stream");

      es.onopen = () => setSseConnected(true);

      es.onmessage = (e) => {
        try {
          const { revenue, last_updated } = JSON.parse(e.data);
          const val = Number(revenue);
          if (prevRevRef.current !== null && prevRevRef.current !== val) {
            setRevPulse(true);
            setTimeout(() => setRevPulse(false), 700);
          }
          prevRevRef.current = val;
          setLiveRevenue(val);
          setLastUpdated(last_updated);
          setSseConnected(true);
        } catch { /* ignore parse errors */ }
      };

      es.onerror = () => {
        setSseConnected(false);
        es.close();
        // Retry after 5 s if disconnected
        setTimeout(connect, 5000);
      };
    }

    connect();
    return () => { if (es) es.close(); };
  }, []);

  const displayRevenue = liveRevenue !== null ? liveRevenue : stats.totalRevenue;
  const maxRating = Math.max(...topMovies.map((m) => Number(m.rating) || 0), 10);
  const maxTrend  = Math.max(...trendData.map((d) => Number(d.revenue) || 0), 1);

  return (
    <div className="page">
      {/* ── Page header ── */}
      <div className="page-header">
        <div>
          <h1 className="page-title">Dashboard</h1>
        </div>
        <div style={{ display:"flex", gap:"0.625rem", alignItems:"center" }}>
          {sseConnected && (
            <span className="dash-live-indicator">
              <span className="dash-live-dot" />
              Real-time
            </span>
          )}
          <button className="btn btn--secondary btn--sm" onClick={fetchData}>
            ↻ Refresh
          </button>
        </div>
      </div>

      {error && <div className="alert alert--error">⚠ {error}</div>}

      {/* ── Hero Revenue Card ── */}
      <div className="dash-hero">
        <div>
          <div className="dash-hero-label">
            Total Revenue (Paid Bookings)
            {sseConnected && (
              <span className="dash-live-indicator" style={{marginLeft:8}}>
                <span className="dash-live-dot" /> Live
              </span>
            )}
          </div>
          <div className={`dash-hero-revenue${revPulse ? " dash-hero-revenue--updated" : ""}`}>
            {loading ? "—" : `₹${fmtINR(displayRevenue)}`}
          </div>
          <div className="dash-hero-sub">
            {lastUpdated
              ? `Last updated at ${fmtDate(lastUpdated)}`
              : "Connects to Revenue_Log in real time"}
          </div>
        </div>
        <div className="dash-hero-meta">
          <div className="dash-hero-stat">
            Active Shows <strong>{loading ? "—" : stats.activeShows}</strong>
          </div>
          <div className="dash-hero-stat">
            Pending <strong>{loading ? "—" : stats.pendingBookings}</strong>
          </div>
          <div className="dash-hero-stat">
            Cancelled <strong>{loading ? "—" : stats.cancelledBookings}</strong>
          </div>
          <div className="dash-hero-stat">
            Avg Rating <strong>{loading ? "—" : `⭐ ${stats.avgMovieRating}`}</strong>
          </div>
        </div>
      </div>

      {/* ── KPI Grid ── */}
      <section className="dash-stats">
        <StatCard icon="🎬" label="Total Movies"    value={loading?"…":stats.totalMovies}    accent="#e63946" />
        <StatCard icon="👤" label="Customers"       value={loading?"…":stats.totalCustomers} accent="#60a5fa" />
        <StatCard icon="🎟" label="Total Bookings"  value={loading?"…":stats.totalBookings}  accent="#2dd4bf" />
        <StatCard icon="📅" label="Active Shows"    value={loading?"…":stats.activeShows}    accent="#a78bfa" />
        <StatCard icon="⭐" label="Reviews"         value={loading?"…":stats.totalReviews}   accent="#ffd166" />
        <StatCard icon="🏙" label="Cities"          value={loading?"…":stats.totalCities}    accent="#fb923c" />
      </section>

      {/* ── Lower section: Chart + Trend ── */}
      <div className="dash-lower">
        {/* Top-rated movies bar chart */}
        <section className="dash-section">
          <div className="dash-section-header">
            <h2 className="dash-section-title">Top Rated Movies</h2>
            <span className="dash-section-sub">by IMDB rating</span>
          </div>
          {loading ? (
            <div className="dash-loading">Loading…</div>
          ) : topMovies.length === 0 ? (
            <div className="dash-empty">No data.</div>
          ) : (
            <div className="dash-chart">
              {topMovies.map((m) => {
                const pct = Math.round(((Number(m.rating) || 0) / maxRating) * 100);
                return (
                  <div className="dash-bar-row" key={m.movie_id}>
                    <span className="dash-bar-label" title={m.title}>{m.title}</span>
                    <div className="dash-bar-track">
                      <div className="dash-bar-fill" style={{ width: `${pct}%` }} />
                    </div>
                    <span className="dash-bar-val">{m.rating}</span>
                  </div>
                );
              })}
            </div>
          )}
        </section>

        {/* Revenue trend + quick stats */}
        <div style={{ display:"flex", flexDirection:"column", gap:"1.25rem" }}>
          {/* Revenue trend */}
          <section className="dash-section" style={{ flex: 1 }}>
            <div className="dash-section-header">
              <h2 className="dash-section-title">Revenue Trend</h2>
              <span className="dash-section-sub">last 14 days</span>
            </div>
            {loading ? (
              <div className="dash-loading">Loading…</div>
            ) : trendData.length === 0 ? (
              <div className="dash-empty">No recent data.</div>
            ) : (
              <div className="dash-trend">
                {trendData.map((d, i) => {
                  const pct = Math.round((Number(d.revenue) / maxTrend) * 100);
                  const label = new Date(d.day).toLocaleDateString("en-IN",
                    { month:"short", day:"numeric" });
                  return (
                    <div className="dash-trend-row" key={i}>
                      <span className="dash-trend-day">{label}</span>
                      <div className="dash-trend-bar-track">
                        <div className="dash-trend-bar-fill" style={{ width:`${pct}%` }} />
                      </div>
                      <span className="dash-trend-amt">₹{fmtINR(d.revenue)}</span>
                    </div>
                  );
                })}
              </div>
            )}
          </section>

          {/* Quick stats pills */}
          <section className="dash-section">
            <div className="dash-section-header">
              <h2 className="dash-section-title">Quick Stats</h2>
            </div>
            <div className="dash-pills">
              {[
                { icon: "⏳", label: "Pending Bookings",   value: stats.pendingBookings },
                { icon: "❌", label: "Cancelled Bookings", value: stats.cancelledBookings },
                { icon: "⭐", label: "Avg. Movie Rating",  value: `${stats.avgMovieRating} / 10` },
              ].map((p) => (
                <div className="dash-pill" key={p.label}>
                  <div className="dash-pill-left">
                    <div className="dash-pill-icon">{p.icon}</div>
                    <span className="dash-pill-label">{p.label}</span>
                  </div>
                  <span className="dash-pill-value">{loading ? "—" : p.value}</span>
                </div>
              ))}
            </div>
          </section>
        </div>
      </div>

      {/* ── Info banner ── */}
      <section className="dash-info">
        <strong>Real-time revenue</strong> streams via Server-Sent Events from{" "}
        <code>GET /api/revenue/stream</code>. Revenue_Log is updated atomically inside
        each booking transaction — no polling needed.
      </section>
    </div>
  );
}

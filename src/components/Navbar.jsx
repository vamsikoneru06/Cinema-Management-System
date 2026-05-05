import React from "react";
import { NavLink } from "react-router-dom";
import "./Navbar.css";

const NAV_LINKS = [
  { to: "/",          label: "Dashboard",  icon: "⬛" },
  { to: "/movies",    label: "Movies",     icon: "🎬" },
  { to: "/customers", label: "Customers",  icon: "👤" },
  { to: "/bookings",  label: "Bookings",   icon: "🎟" },
  { to: "/showtimes", label: "Show Times", icon: "📅" },
  { to: "/reviews",   label: "Reviews",    icon: "⭐" },
];

export default function Navbar() {
  return (
    <header className="navbar">
      {/* Brand */}
      <div className="navbar-brand">
        <div className="navbar-logo-wrap">🎥</div>
        <div>
          <span className="navbar-title">
            Cinema<span className="navbar-title-accent">MS</span>
          </span>
          <span className="navbar-title-sub">Management Suite</span>
        </div>
      </div>

      {/* Nav links */}
      <nav className="navbar-links">
        {NAV_LINKS.map(({ to, label, icon }) => (
          <NavLink
            key={to}
            to={to}
            end={to === "/"}
            className={({ isActive }) =>
              isActive ? "nav-link nav-link--active" : "nav-link"
            }
          >
            <span className="nav-icon">{icon}</span>
            {label}
          </NavLink>
        ))}
      </nav>

      {/* Live indicator */}
      <div className="navbar-right">
        <span className="navbar-live-badge">
          <span className="live-dot" />
          Live
        </span>
      </div>
    </header>
  );
}

// ============================================================
//  components/Navbar.jsx
//  Top navigation bar with active link highlighting.
// ============================================================

import React from "react";
import { NavLink } from "react-router-dom";
import "./Navbar.css";

const NAV_LINKS = [
  { to: "/",          label: "Dashboard"   },
  { to: "/movies",    label: "Movies"      },
  { to: "/customers", label: "Customers"   },
  { to: "/bookings",  label: "Bookings"    },
  { to: "/showtimes", label: "Show Times"  },
  { to: "/reviews",   label: "Reviews"     },
];

export default function Navbar() {
  return (
    <header className="navbar">
      <div className="navbar-brand">
        <span className="navbar-logo">&#127916;</span>
        <span className="navbar-title">
          Cinema<span className="navbar-title-accent">MS</span>
        </span>
      </div>

      <nav className="navbar-links">
        {NAV_LINKS.map(({ to, label }) => (
          <NavLink
            key={to}
            to={to}
            end={to === "/"}
            className={({ isActive }) =>
              isActive ? "nav-link nav-link--active" : "nav-link"
            }
          >
            {label}
          </NavLink>
        ))}
      </nav>
    </header>
  );
}

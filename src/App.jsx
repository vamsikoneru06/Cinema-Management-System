// ============================================================
//  App.jsx
//  Root component. Sets up React Router and global layout.
// ============================================================

import React from "react";
import { BrowserRouter, Routes, Route, Navigate } from "react-router-dom";
import Navbar     from "./components/Navbar";
import Dashboard  from "./pages/Dashboard";
import Movies     from "./pages/Movies";
import Customers  from "./pages/Customers";
import Bookings   from "./pages/Bookings";
import ShowTimes  from "./pages/ShowTimes";
import Reviews    from "./pages/Reviews";
import "./App.css";

export default function App() {
  return (
    <BrowserRouter>
      {/* ── Sticky top navigation ── */}
      <Navbar />

      {/* ── Main content area ── */}
      <main className="app-main">
        <Routes>
          <Route path="/"           element={<Dashboard  />} />
          <Route path="/movies"     element={<Movies     />} />
          <Route path="/customers"  element={<Customers  />} />
          <Route path="/bookings"   element={<Bookings   />} />
          <Route path="/showtimes"  element={<ShowTimes  />} />
          <Route path="/reviews"    element={<Reviews    />} />

          {/* Catch-all → redirect to dashboard */}
          <Route path="*" element={<Navigate to="/" replace />} />
        </Routes>
      </main>

      {/* ── Footer ── */}
      <footer className="app-footer">
        <span>Cinema Management System</span>
        <span className="app-footer-sep">·</span>
        <span>21CSC205P — SRM IST Kattankulathur</span>
        <span className="app-footer-sep">·</span>
        <span>API: <code>http://localhost:5000/api</code></span>
      </footer>
    </BrowserRouter>
  );
}

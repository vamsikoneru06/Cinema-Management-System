# 🎬 Cinema Management System — React Frontend

**Course:** 21CSC205P Database Management Systems  
**Authors:** K Mohan Vamsi [RA2411030010013] · A Teja Rayal [RA2411030010022]  
**Guide:** Dr. Saranya G  
**Institute:** SRM Institute of Science and Technology, Kattankulathur – 603 203

---

## 1. Project Overview

A production-ready React frontend for the Cinema Management System database project. It provides full CRUD (Create, Read, Update, Delete) operations for all major entities — Movies, Customers, Bookings, Show Times, and Reviews — through a clean, responsive UI that communicates with a SQL database via a REST API layer.

**Key features:**
- Dashboard with live KPI stats
- Data tables with search & filter on every page
- Add / Edit / Delete via modal forms with validation
- Booking cancellation (triggers a SQL trigger on the backend)
- Reusable components: `Navbar`, `DataTable`, `Modal`, `StatCard`, `Badge`
- Centralized API layer in `services/api.js` using Axios
- React Router v6 for client-side navigation

---

## 2. Folder Structure

```
cinema-management/
│
├── public/
│   └── index.html              ← HTML shell for Create React App
│
├── src/
│   │
│   ├── components/             ← Reusable UI components
│   │   ├── Navbar.jsx          ← Top navigation bar
│   │   ├── Navbar.css
│   │   ├── StatCard.jsx        ← KPI metric card (Dashboard)
│   │   ├── StatCard.css
│   │   ├── DataTable.jsx       ← Generic data table with search
│   │   ├── DataTable.css       ← Table + shared .btn styles
│   │   ├── Modal.jsx           ← Dialog + form field helpers
│   │   ├── Modal.css           ← Modal + .form-* styles
│   │   ├── Badge.jsx           ← Coloured status badge
│   │   └── Badge.css
│   │
│   ├── pages/                  ← One file per route/feature
│   │   ├── Dashboard.jsx       ← Stats overview + bar chart
│   │   ├── Dashboard.css
│   │   ├── Movies.jsx          ← Full CRUD for movies
│   │   ├── Customers.jsx       ← Full CRUD for customers
│   │   ├── Bookings.jsx        ← View / filter / cancel bookings
│   │   ├── ShowTimes.jsx       ← Full CRUD for show schedules
│   │   ├── Reviews.jsx         ← Add / delete customer reviews
│   │   └── Page.css            ← Shared page styles (toast, alerts, filters)
│   │
│   ├── services/
│   │   └── api.js              ← ALL Axios calls live here
│   │
│   ├── App.jsx                 ← Root component + React Router setup
│   ├── App.css                 ← Global CSS reset + design tokens
│   └── index.js                ← ReactDOM.createRoot entry point
│
├── package.json
└── README.md
```

---

## 3. Installation & Running

### Prerequisites
- Node.js ≥ 18.x ([https://nodejs.org](https://nodejs.org))
- npm ≥ 9.x (comes with Node)
- Your Express/Node backend running on port 5000 (see Section 5)

### Steps

```bash
# 1. Clone or download the project
cd cinema-management

# 2. Install all dependencies
npm install

# 3. Start the development server
npm start
```

The app opens at **http://localhost:3000**

To create a production build:
```bash
npm run build
```

---

## 4. Environment Configuration

The API base URL is set in `src/services/api.js`:

```js
const BASE_URL = "http://localhost:5000/api";
```

If your backend runs on a different port or host, update this value.

Alternatively, you can use a `.env` file in the project root:

```env
REACT_APP_API_URL=http://localhost:5000/api
```

Then in `api.js`:
```js
const BASE_URL = process.env.REACT_APP_API_URL || "http://localhost:5000/api";
```

The `package.json` also includes:
```json
"proxy": "http://localhost:5000"
```
This lets you use relative paths like `/api/movies` during development (avoids CORS issues).

---

## 5. HOW TO CONNECT THE SQL DATABASE (Step-by-Step)

> ⚠️ **Important:** React runs in the browser. It **cannot** connect directly to MySQL or any SQL database. A backend server (Node.js + Express) acts as the bridge between React and your database.

### Architecture

```
┌────────────────┐    HTTP Request     ┌──────────────────┐    SQL Query     ┌──────────────┐
│                │  ────────────────▶  │                  │  ─────────────▶  │              │
│  React (3000)  │                     │  Express (5000)  │                  │  MySQL DB    │
│  (Browser)     │  ◀────────────────  │  (Node.js)       │  ◀─────────────  │              │
│                │    JSON Response    │                  │    Result Set    │              │
└────────────────┘                     └──────────────────┘                  └──────────────┘
```

---

### Step 1 — Create the backend folder

```bash
mkdir cinema-backend
cd cinema-backend
npm init -y
```

---

### Step 2 — Install backend dependencies

```bash
# Express framework
npm install express

# MySQL driver
npm install mysql2

# CORS (allow React on port 3000 to call API on port 5000)
npm install cors

# Optional: auto-restart on file changes
npm install --save-dev nodemon
```

Add to `package.json` scripts:
```json
"scripts": {
  "start": "node server.js",
  "dev":   "nodemon server.js"
}
```

---

### Step 3 — Create the database connection file

**`cinema-backend/db.js`**

```js
const mysql = require("mysql2");

// Create a connection pool (more efficient than single connections)
const pool = mysql.createPool({
  host:     "localhost",   // your MySQL host
  port:     3306,          // default MySQL port
  user:     "root",        // your MySQL username
  password: "your_password", // your MySQL password
  database: "CinemaManagement",
  waitForConnections: true,
  connectionLimit: 10,
  queueLimit: 0,
});

// Promisify for async/await usage
const db = pool.promise();

// Test connection on startup
(async () => {
  try {
    await db.query("SELECT 1");
    console.log("✅ MySQL connected successfully");
  } catch (err) {
    console.error("❌ MySQL connection failed:", err.message);
    process.exit(1);
  }
})();

module.exports = db;
```

---

### Step 4 — Create the Express server with all API routes

**`cinema-backend/server.js`**

```js
const express = require("express");
const cors    = require("cors");
const db      = require("./db");

const app  = express();
const PORT = 5000;

// ── Middleware ────────────────────────────────────────────────
app.use(cors({ origin: "http://localhost:3000" }));
app.use(express.json());

// ── Helper: send consistent error responses ───────────────────
const sendError = (res, err, code = 500) => {
  console.error(err);
  res.status(code).json({ message: err.message || "Server error" });
};

// ============================================================
//  MOVIES  –  /api/movies
// ============================================================
app.get("/api/movies", async (req, res) => {
  try {
    const [rows] = await db.query(`
      SELECT m.*, g.genre_name
      FROM Movie m
      LEFT JOIN Genre g ON m.genre_id = g.genre_id
      ORDER BY m.rating DESC
    `);
    res.json(rows);
  } catch (err) { sendError(res, err); }
});

app.get("/api/movies/:id", async (req, res) => {
  try {
    const [rows] = await db.query("SELECT * FROM Movie WHERE movie_id = ?", [req.params.id]);
    if (!rows.length) return res.status(404).json({ message: "Movie not found" });
    res.json(rows[0]);
  } catch (err) { sendError(res, err); }
});

app.post("/api/movies", async (req, res) => {
  try {
    const { title, director, producer, genre_id, release_date, duration, rating, budget } = req.body;
    if (!title || !director || !duration) {
      return res.status(400).json({ message: "title, director, duration are required" });
    }
    const [result] = await db.query(
      "INSERT INTO Movie (title, director, producer, genre_id, release_date, duration, rating, budget) VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
      [title, director, producer, genre_id, release_date, duration, rating, budget]
    );
    res.status(201).json({ movie_id: result.insertId, message: "Movie added" });
  } catch (err) { sendError(res, err); }
});

app.put("/api/movies/:id", async (req, res) => {
  try {
    const { title, director, producer, genre_id, release_date, duration, rating, budget } = req.body;
    await db.query(
      "UPDATE Movie SET title=?, director=?, producer=?, genre_id=?, release_date=?, duration=?, rating=?, budget=? WHERE movie_id=?",
      [title, director, producer, genre_id, release_date, duration, rating, budget, req.params.id]
    );
    res.json({ message: "Movie updated" });
  } catch (err) { sendError(res, err); }
});

app.delete("/api/movies/:id", async (req, res) => {
  try {
    await db.query("DELETE FROM Movie WHERE movie_id = ?", [req.params.id]);
    res.json({ message: "Movie deleted" });
  } catch (err) { sendError(res, err); }
});

// ============================================================
//  CUSTOMERS  –  /api/customers
// ============================================================
app.get("/api/customers", async (req, res) => {
  try {
    // Never return passwords to the frontend
    const [rows] = await db.query(
      "SELECT customer_id, name, email, phone, created_at FROM Customer ORDER BY customer_id DESC"
    );
    res.json(rows);
  } catch (err) { sendError(res, err); }
});

app.get("/api/customers/:id", async (req, res) => {
  try {
    const [rows] = await db.query(
      "SELECT customer_id, name, email, phone FROM Customer WHERE customer_id = ?",
      [req.params.id]
    );
    if (!rows.length) return res.status(404).json({ message: "Customer not found" });
    res.json(rows[0]);
  } catch (err) { sendError(res, err); }
});

app.post("/api/customers", async (req, res) => {
  try {
    const { name, email, phone, password } = req.body;
    if (!name || !email || !password) {
      return res.status(400).json({ message: "name, email, password are required" });
    }
    // NOTE: Hash passwords in production! e.g. bcrypt.hash(password, 10)
    const [result] = await db.query(
      "INSERT INTO Customer (name, email, phone, password) VALUES (?, ?, ?, ?)",
      [name, email, phone, password]
    );
    res.status(201).json({ customer_id: result.insertId, message: "Customer created" });
  } catch (err) { sendError(res, err); }
});

app.put("/api/customers/:id", async (req, res) => {
  try {
    const { name, email, phone } = req.body;
    await db.query(
      "UPDATE Customer SET name=?, email=?, phone=? WHERE customer_id=?",
      [name, email, phone, req.params.id]
    );
    res.json({ message: "Customer updated" });
  } catch (err) { sendError(res, err); }
});

app.delete("/api/customers/:id", async (req, res) => {
  try {
    await db.query("DELETE FROM Customer WHERE customer_id = ?", [req.params.id]);
    res.json({ message: "Customer deleted" });
  } catch (err) { sendError(res, err); }
});

// ============================================================
//  BOOKINGS  –  /api/bookings
// ============================================================
app.get("/api/bookings", async (req, res) => {
  try {
    const [rows] = await db.query(`
      SELECT
        b.booking_id, b.booking_date, b.total_amount, b.payment_status,
        c.name  AS customer_name,
        m.title AS movie_title
      FROM Booking b
      JOIN Customer  c  ON b.customer_id    = c.customer_id
      LEFT JOIN Booking_Detail bd ON b.booking_id = bd.booking_id
      LEFT JOIN Ticket         t  ON bd.ticket_id  = t.ticket_id
      LEFT JOIN Show_Time      s  ON t.show_id     = s.show_id
      LEFT JOIN Movie          m  ON s.movie_id    = m.movie_id
      GROUP BY b.booking_id, c.name
      ORDER BY b.booking_date DESC
    `);
    res.json(rows);
  } catch (err) { sendError(res, err); }
});

app.put("/api/bookings/:id", async (req, res) => {
  try {
    const { payment_status } = req.body;
    // Updating to 'cancelled' fires the SQL trigger trg_after_booking_cancel
    await db.query(
      "UPDATE Booking SET payment_status=? WHERE booking_id=?",
      [payment_status, req.params.id]
    );
    res.json({ message: "Booking updated" });
  } catch (err) { sendError(res, err); }
});

// ============================================================
//  SHOW TIMES  –  /api/showtimes
// ============================================================
app.get("/api/showtimes", async (req, res) => {
  try {
    const [rows] = await db.query(`
      SELECT
        s.show_id, s.show_date, s.start_time, s.end_time, s.language,
        s.movie_id, s.auditorium_id,
        m.title       AS movie_title,
        t.name        AS theatre_name,
        a.hall_number
      FROM Show_Time  s
      JOIN Movie      m  ON s.movie_id      = m.movie_id
      JOIN Auditorium a  ON s.auditorium_id = a.auditorium_id
      JOIN Theatre    t  ON a.theatre_id    = t.theatre_id
      ORDER BY s.show_date DESC, s.start_time
    `);
    res.json(rows);
  } catch (err) { sendError(res, err); }
});

app.post("/api/showtimes", async (req, res) => {
  try {
    const { movie_id, auditorium_id, show_date, start_time, end_time, language } = req.body;
    const [result] = await db.query(
      "INSERT INTO Show_Time (movie_id, auditorium_id, show_date, start_time, end_time, language) VALUES (?, ?, ?, ?, ?, ?)",
      [movie_id, auditorium_id, show_date, start_time, end_time, language]
    );
    res.status(201).json({ show_id: result.insertId, message: "Show scheduled" });
  } catch (err) { sendError(res, err); }
});

app.put("/api/showtimes/:id", async (req, res) => {
  try {
    const { movie_id, auditorium_id, show_date, start_time, end_time, language } = req.body;
    await db.query(
      "UPDATE Show_Time SET movie_id=?, auditorium_id=?, show_date=?, start_time=?, end_time=?, language=? WHERE show_id=?",
      [movie_id, auditorium_id, show_date, start_time, end_time, language, req.params.id]
    );
    res.json({ message: "Show updated" });
  } catch (err) { sendError(res, err); }
});

app.delete("/api/showtimes/:id", async (req, res) => {
  try {
    await db.query("DELETE FROM Show_Time WHERE show_id = ?", [req.params.id]);
    res.json({ message: "Show deleted" });
  } catch (err) { sendError(res, err); }
});

// ============================================================
//  REVIEWS  –  /api/reviews
// ============================================================
app.get("/api/reviews", async (req, res) => {
  try {
    const [rows] = await db.query(`
      SELECT
        r.review_id, r.rating, r.comment, r.created_at,
        c.name  AS customer_name,
        m.title AS movie_title
      FROM Review   r
      JOIN Customer c ON r.customer_id = c.customer_id
      JOIN Movie    m ON r.movie_id    = m.movie_id
      ORDER BY r.review_id DESC
    `);
    res.json(rows);
  } catch (err) { sendError(res, err); }
});

app.post("/api/reviews", async (req, res) => {
  try {
    const { customer_id, movie_id, rating, comment } = req.body;
    const [result] = await db.query(
      "INSERT INTO Review (customer_id, movie_id, rating, comment) VALUES (?, ?, ?, ?)",
      [customer_id, movie_id, rating, comment]
    );
    res.status(201).json({ review_id: result.insertId, message: "Review added" });
  } catch (err) { sendError(res, err); }
});

app.delete("/api/reviews/:id", async (req, res) => {
  try {
    await db.query("DELETE FROM Review WHERE review_id = ?", [req.params.id]);
    res.json({ message: "Review deleted" });
  } catch (err) { sendError(res, err); }
});

// ============================================================
//  GENRES  –  /api/genres  (used by Movies form dropdown)
// ============================================================
app.get("/api/genres", async (req, res) => {
  try {
    const [rows] = await db.query("SELECT * FROM Genre ORDER BY genre_name");
    res.json(rows);
  } catch (err) { sendError(res, err); }
});

// ============================================================
//  THEATRES / AUDITORIUMS  –  /api/theatres
//  Returns flat join so React dropdowns have all needed info
// ============================================================
app.get("/api/theatres", async (req, res) => {
  try {
    const [rows] = await db.query(`
      SELECT
        a.auditorium_id,
        a.hall_number,
        a.capacity,
        t.theatre_id,
        t.name       AS theatre_name,
        t.location
      FROM Auditorium a
      JOIN Theatre    t ON a.theatre_id = t.theatre_id
      ORDER BY t.name, a.hall_number
    `);
    res.json(rows);
  } catch (err) { sendError(res, err); }
});

// ============================================================
//  DASHBOARD STATS  –  /api/dashboard/stats
// ============================================================
app.get("/api/dashboard/stats", async (req, res) => {
  try {
    const [[movies]]    = await db.query("SELECT COUNT(*) AS cnt FROM Movie");
    const [[customers]] = await db.query("SELECT COUNT(*) AS cnt FROM Customer");
    const [[bookings]]  = await db.query("SELECT COUNT(*) AS cnt FROM Booking");
    const [[revenue]]   = await db.query("SELECT COALESCE(SUM(total_amount),0) AS total FROM Booking WHERE payment_status='paid'");
    const [[pending]]   = await db.query("SELECT COUNT(*) AS cnt FROM Booking WHERE payment_status='pending'");
    const [[cancelled]] = await db.query("SELECT COUNT(*) AS cnt FROM Booking WHERE payment_status='cancelled'");
    const [[shows]]     = await db.query("SELECT COUNT(*) AS cnt FROM Show_Time WHERE show_date >= CURDATE()");
    const [[reviews]]   = await db.query("SELECT COUNT(*) AS cnt FROM Review");

    res.json({
      totalMovies:       movies.cnt,
      totalCustomers:    customers.cnt,
      totalBookings:     bookings.cnt,
      totalRevenue:      revenue.total,
      pendingBookings:   pending.cnt,
      cancelledBookings: cancelled.cnt,
      activeShows:       shows.cnt,
      totalReviews:      reviews.cnt,
    });
  } catch (err) { sendError(res, err); }
});

// ── Start server ──────────────────────────────────────────────
app.listen(PORT, () => {
  console.log(`🚀 Cinema API server running → http://localhost:${PORT}/api`);
});
```

---

### Step 5 — Run the backend

```bash
# Development mode (auto-restart on save)
npm run dev

# OR production mode
npm start
```

You should see:
```
✅ MySQL connected successfully
🚀 Cinema API server running → http://localhost:5000/api
```

---

### Step 6 — Start the React frontend

Open a **second terminal**:
```bash
cd cinema-management
npm start
```

The app opens at **http://localhost:3000** and communicates with the API at port 5000.

---

## 6. Complete Data Flow

```
User fills form → React validates input → Axios POST/PUT/DELETE
      ↓
services/api.js (http://localhost:5000/api/movies)
      ↓
Express route handler (server.js)
      ↓
db.query("INSERT INTO Movie …")  ←  mysql2 driver
      ↓
MySQL executes query + fires triggers (Booking_Log, etc.)
      ↓
JSON response → Axios → React state update → UI re-renders
```

---

## 7. API Endpoint Reference

| Method | Endpoint                    | Description                  |
|--------|-----------------------------|------------------------------|
| GET    | /api/movies                 | List all movies              |
| POST   | /api/movies                 | Add a movie                  |
| PUT    | /api/movies/:id             | Update a movie               |
| DELETE | /api/movies/:id             | Delete a movie               |
| GET    | /api/customers              | List all customers           |
| POST   | /api/customers              | Add a customer               |
| PUT    | /api/customers/:id          | Update a customer            |
| DELETE | /api/customers/:id          | Delete a customer            |
| GET    | /api/bookings               | List all bookings (with join)|
| PUT    | /api/bookings/:id           | Cancel / update a booking    |
| GET    | /api/showtimes              | List all show times          |
| POST   | /api/showtimes              | Schedule a new show          |
| PUT    | /api/showtimes/:id          | Update a show                |
| DELETE | /api/showtimes/:id          | Remove a show                |
| GET    | /api/reviews                | List all reviews             |
| POST   | /api/reviews                | Add a review                 |
| DELETE | /api/reviews/:id            | Delete a review              |
| GET    | /api/genres                 | List genres (for dropdowns)  |
| GET    | /api/theatres               | List auditoriums (dropdowns) |
| GET    | /api/dashboard/stats        | Aggregate KPI stats          |

---

## 8. How SQL Triggers Are Activated via the React UI

The SQL triggers defined in `cinema_management_system.sql` fire automatically when the React frontend makes API calls:

| UI Action                         | API Call                                | SQL Trigger Fired                   |
|-----------------------------------|-----------------------------------------|-------------------------------------|
| New booking created               | POST /api/bookings                      | `trg_after_booking_insert`          |
| Booking cancelled (Cancel button) | PUT /api/bookings/:id {cancelled}       | `trg_after_booking_cancel`          |
| Ticket price updated              | PUT /api/tickets/:id                    | `trg_after_ticket_price_update`     |
| Negative price entered for ticket | POST /api/tickets (price < 0)           | `trg_before_ticket_insert` (fix)    |

---

## 9. Troubleshooting

| Issue                          | Fix                                                             |
|--------------------------------|-----------------------------------------------------------------|
| `CORS error` in browser        | Ensure `cors()` middleware is added in `server.js`             |
| `ECONNREFUSED localhost:5000`  | Start the Express backend first (`npm run dev`)                |
| `ER_ACCESS_DENIED_ERROR`       | Check MySQL username/password in `db.js`                       |
| `Table doesn't exist`          | Run the SQL script: `source cinema_management_system.sql`      |
| Empty dropdowns in forms       | Backend must return genres/theatres from `/api/genres` etc.    |
| React shows `Loading…` forever | Open browser DevTools → Network tab → check failed API calls   |

---

## 10. Project Authors

| Name           | Register No.       |
|----------------|--------------------|
| K Mohan Vamsi  | RA2411030010013    |
| A Teja Rayal   | RA2411030010022    |

**Department:** Networking and Communications — School of Computing  
**Guide:** Dr. Saranya G (Assistant Professor)

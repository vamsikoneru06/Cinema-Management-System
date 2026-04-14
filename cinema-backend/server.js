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
const express = require("express");
const cors    = require("cors");
const db      = require("./db");

const app  = express();
const PORT = 5000;

app.use(cors({
  origin: "http://localhost:3000",
  methods: ["GET","POST","PUT","DELETE"],
  allowedHeaders: ["Content-Type","Authorization"],
}));
app.use(express.json());

const sendError = (res, err, code = 500) => {
  console.error(err);
  res.status(code).json({ message: err.message || "Server error" });
};

// ============================================================
//  REAL-TIME REVENUE  –  Server-Sent Events
// ============================================================

// Set of active SSE response objects – one per connected browser tab
const revenueClients = new Set();

// Fetch current revenue and push it to all connected clients
async function broadcastRevenue() {
  try {
    const [[row]] = await db.query(`
      SELECT
        COALESCE(SUM(CASE WHEN action='credit' THEN amount ELSE 0 END),0)
          - COALESCE(SUM(CASE WHEN action='debit' THEN amount ELSE 0 END),0) AS total,
        MAX(logged_at) AS last_updated
      FROM Revenue_Log
    `);
    const payload = JSON.stringify({
      revenue:      Number(row.total || 0),
      last_updated: row.last_updated,
      timestamp:    new Date().toISOString(),
    });
    revenueClients.forEach((client) => client.write(`data: ${payload}\n\n`));
  } catch (e) {
    console.error("[SSE broadcast error]", e.message);
  }
}

// SSE endpoint – browsers subscribe here for live revenue updates
app.get("/api/revenue/stream", (req, res) => {
  res.setHeader("Content-Type",  "text/event-stream");
  res.setHeader("Cache-Control", "no-cache");
  res.setHeader("Connection",    "keep-alive");
  res.setHeader("Access-Control-Allow-Origin", "http://localhost:3000");
  res.flushHeaders();

  revenueClients.add(res);

  // Send current value immediately on connect
  broadcastRevenue();

  // Keep connection alive with a comment every 25 s
  const keepAlive = setInterval(() => res.write(": ping\n\n"), 25000);

  req.on("close", () => {
    revenueClients.delete(res);
    clearInterval(keepAlive);
  });
});

// Revenue trend – last 14 days (for dashboard line chart)
app.get("/api/revenue/trend", async (req, res) => {
  try {
    const [rows] = await db.query(`
      SELECT DATE(b.booking_date) AS day,
             SUM(b.total_amount)  AS revenue
      FROM Booking b
      WHERE b.payment_status = 'paid'
        AND b.booking_date  >= DATE_SUB(CURDATE(), INTERVAL 14 DAY)
      GROUP BY DATE(b.booking_date)
      ORDER BY day
    `);
    res.json(rows);
  } catch (err) { sendError(res, err); }
});

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
    if (!title || !director || !duration)
      return res.status(400).json({ message: "title, director, duration are required" });
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
  const conn = await db.getConnection();
  try {
    await conn.beginTransaction();
    const id = req.params.id;

    // 1. Get all show_ids for this movie
    const [shows] = await conn.query(
      "SELECT show_id FROM Show_Time WHERE movie_id = ?", [id]
    );
    const showIds = shows.map(r => r.show_id);

    if (showIds.length) {
      // 2. Get all ticket_ids for those shows
      const [tickets] = await conn.query(
        `SELECT ticket_id FROM Ticket WHERE show_id IN (${showIds.map(() => '?').join(',')})`,
        showIds
      );
      const ticketIds = tickets.map(r => r.ticket_id);

      if (ticketIds.length) {
        // 3. Get all booking_ids linked to those tickets
        const [details] = await conn.query(
          `SELECT DISTINCT booking_id FROM Booking_Detail WHERE ticket_id IN (${ticketIds.map(() => '?').join(',')})`,
          ticketIds
        );
        const bookingIds = details.map(r => r.booking_id);

        if (bookingIds.length) {
          const bPlaceholders = bookingIds.map(() => '?').join(',');
          // 4. Delete child records of those bookings (correct order)
          await conn.query(`DELETE FROM Revenue_Log WHERE booking_id IN (${bPlaceholders})`, bookingIds);
          await conn.query(`DELETE FROM Booking_Log  WHERE booking_id IN (${bPlaceholders})`, bookingIds);
          await conn.query(`DELETE FROM Payment       WHERE booking_id IN (${bPlaceholders})`, bookingIds);
          await conn.query(`DELETE FROM Booking_Detail WHERE booking_id IN (${bPlaceholders})`, bookingIds);
          await conn.query(`DELETE FROM Booking        WHERE booking_id IN (${bPlaceholders})`, bookingIds);
        } else {
          // No bookings but tickets exist – still remove booking_details by ticket
          const tPlaceholders = ticketIds.map(() => '?').join(',');
          await conn.query(`DELETE FROM Booking_Detail WHERE ticket_id IN (${tPlaceholders})`, ticketIds);
        }

        // 5. Delete tickets for those shows
        const tPlaceholders = ticketIds.map(() => '?').join(',');
        await conn.query(`DELETE FROM Ticket WHERE ticket_id IN (${tPlaceholders})`, ticketIds);
      }

      // 6. Delete show_times
      await conn.query(
        `DELETE FROM Show_Time WHERE show_id IN (${showIds.map(() => '?').join(',')})`,
        showIds
      );
    }

    // 7. Delete reviews for this movie
    await conn.query("DELETE FROM Review WHERE movie_id = ?", [id]);

    // 8. Finally delete the movie (Movie_Actor uses ON DELETE CASCADE)
    await conn.query("DELETE FROM Movie WHERE movie_id = ?", [id]);

    await conn.commit();
    res.json({ message: "Movie deleted" });
  } catch (err) {
    await conn.rollback();
    sendError(res, err);
  } finally {
    conn.release();
  }
});

// ============================================================
//  CUSTOMERS  –  /api/customers
// ============================================================
app.get("/api/customers", async (req, res) => {
  try {
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
    if (!name || !email || !password)
      return res.status(400).json({ message: "name, email, password are required" });
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
  const conn = await db.getConnection();
  try {
    await conn.beginTransaction();
    const id = req.params.id;

    // 1. Get all bookings for this customer
    const [bookings] = await conn.query(
      "SELECT booking_id FROM Booking WHERE customer_id = ?", [id]
    );
    const bookingIds = bookings.map(r => r.booking_id);

    if (bookingIds.length) {
      const bPlaceholders = bookingIds.map(() => '?').join(',');

      // 2. Get ticket_ids linked to these bookings (to release them)
      const [details] = await conn.query(
        `SELECT ticket_id FROM Booking_Detail WHERE booking_id IN (${bPlaceholders})`,
        bookingIds
      );
      const ticketIds = details.map(r => r.ticket_id);

      // 3. Delete child records in correct FK order
      await conn.query(`DELETE FROM Revenue_Log   WHERE booking_id IN (${bPlaceholders})`, bookingIds);
      await conn.query(`DELETE FROM Booking_Log   WHERE booking_id IN (${bPlaceholders})`, bookingIds);
      await conn.query(`DELETE FROM Payment        WHERE booking_id IN (${bPlaceholders})`, bookingIds);
      await conn.query(`DELETE FROM Booking_Detail WHERE booking_id IN (${bPlaceholders})`, bookingIds);

      // 4. Release the tickets back to available
      if (ticketIds.length) {
        await conn.query(
          `UPDATE Ticket SET booking_status='available', version=version+1
           WHERE ticket_id IN (${ticketIds.map(() => '?').join(',')})`,
          ticketIds
        );
      }

      await conn.query(`DELETE FROM Booking WHERE booking_id IN (${bPlaceholders})`, bookingIds);
    }

    // 5. Delete reviews left by this customer
    await conn.query("DELETE FROM Review WHERE customer_id = ?", [id]);

    // 6. Delete the customer
    await conn.query("DELETE FROM Customer WHERE customer_id = ?", [id]);

    await conn.commit();
    res.json({ message: "Customer deleted" });
  } catch (err) {
    await conn.rollback();
    sendError(res, err);
  } finally {
    conn.release();
  }
});

// ============================================================
//  BOOKINGS  –  /api/bookings
// ============================================================
app.get("/api/bookings", async (req, res) => {
  try {
    const [rows] = await db.query(`
      SELECT
        b.booking_id, b.booking_date, b.total_amount, b.payment_status,
        c.name        AS customer_name,
        MAX(m.title)  AS movie_title
      FROM Booking b
      JOIN Customer  c  ON b.customer_id    = c.customer_id
      LEFT JOIN Booking_Detail bd ON b.booking_id = bd.booking_id
      LEFT JOIN Ticket         t  ON bd.ticket_id  = t.ticket_id
      LEFT JOIN Show_Time      s  ON t.show_id     = s.show_id
      LEFT JOIN Movie          m  ON s.movie_id    = m.movie_id
      GROUP BY b.booking_id, b.booking_date, b.total_amount, b.payment_status, c.name
      ORDER BY b.booking_date DESC
    `);
    res.json(rows);
  } catch (err) { sendError(res, err); }
});

// Cancel / update booking  –  wrapped in a transaction
app.put("/api/bookings/:id", async (req, res) => {
  const conn = await db.getConnection();
  try {
    await conn.beginTransaction();

    const { payment_status } = req.body;
    const [existing] = await conn.query(
      "SELECT payment_status, total_amount FROM Booking WHERE booking_id = ? FOR UPDATE",
      [req.params.id]
    );

    if (!existing.length) {
      await conn.rollback();
      return res.status(404).json({ message: "Booking not found" });
    }

    const booking = existing[0];

    // Prevent double-cancel
    if (payment_status === "cancelled" && booking.payment_status === "cancelled") {
      await conn.rollback();
      return res.status(409).json({ message: "Booking is already cancelled" });
    }

    await conn.query(
      "UPDATE Booking SET payment_status=?, version=version+1 WHERE booking_id=?",
      [payment_status, req.params.id]
    );

    await conn.commit();
    broadcastRevenue(); // push live update to all SSE clients
    res.json({ message: "Booking updated" });
  } catch (err) {
    await conn.rollback();
    sendError(res, err);
  } finally {
    conn.release();
  }
});

// Hard-delete a booking and release its tickets
app.delete("/api/bookings/:id", async (req, res) => {
  const conn = await db.getConnection();
  try {
    await conn.beginTransaction();
    const id = req.params.id;

    // 1. Get ticket_ids linked to this booking
    const [details] = await conn.query(
      "SELECT ticket_id FROM Booking_Detail WHERE booking_id = ?", [id]
    );
    const ticketIds = details.map(r => r.ticket_id);

    // 2. Delete child rows in correct FK order
    await conn.query("DELETE FROM Revenue_Log   WHERE booking_id = ?", [id]);
    await conn.query("DELETE FROM Booking_Log   WHERE booking_id = ?", [id]);
    await conn.query("DELETE FROM Payment        WHERE booking_id = ?", [id]);
    await conn.query("DELETE FROM Booking_Detail WHERE booking_id = ?", [id]);

    // 3. Release the tickets
    if (ticketIds.length) {
      await conn.query(
        `UPDATE Ticket SET booking_status='available', version=version+1
         WHERE ticket_id IN (${ticketIds.map(() => '?').join(',')})`,
        ticketIds
      );
    }

    // 4. Delete the booking itself
    await conn.query("DELETE FROM Booking WHERE booking_id = ?", [id]);

    await conn.commit();
    broadcastRevenue();
    res.json({ message: "Booking deleted" });
  } catch (err) {
    await conn.rollback();
    sendError(res, err);
  } finally {
    conn.release();
  }
});

// Create a new booking with full transaction + pessimistic lock
app.post("/api/bookings", async (req, res) => {
  const conn = await db.getConnection();
  try {
    await conn.beginTransaction();

    const { customer_id, show_id, seat_id, payment_method = "UPI (Google Pay)" } = req.body;
    if (!customer_id || !show_id || !seat_id) {
      await conn.rollback();
      return res.status(400).json({ message: "customer_id, show_id, seat_id are required" });
    }

    // Pessimistic lock – prevents concurrent double-booking of same seat
    const [tickets] = await conn.query(
      "SELECT ticket_id, price FROM Ticket WHERE show_id=? AND seat_id=? AND booking_status='available' LIMIT 1 FOR UPDATE",
      [show_id, seat_id]
    );

    if (!tickets.length) {
      await conn.rollback();
      return res.status(409).json({ message: "Seat is no longer available" });
    }

    const { ticket_id, price } = tickets[0];

    await conn.query(
      "UPDATE Ticket SET booking_status='booked', version=version+1 WHERE ticket_id=?",
      [ticket_id]
    );

    const [bookingResult] = await conn.query(
      "INSERT INTO Booking (customer_id, total_amount, payment_status) VALUES (?,?,'paid')",
      [customer_id, price]
    );
    const booking_id = bookingResult.insertId;

    await conn.query(
      "INSERT INTO Booking_Detail (booking_id, ticket_id) VALUES (?,?)",
      [booking_id, ticket_id]
    );

    await conn.query(
      "INSERT INTO Payment (booking_id, payment_method) VALUES (?,?)",
      [booking_id, payment_method]
    );

    await conn.commit();
    broadcastRevenue();
    res.status(201).json({ booking_id, message: `Booking #${booking_id} confirmed. Amount: ₹${price}` });
  } catch (err) {
    await conn.rollback();
    sendError(res, err);
  } finally {
    conn.release();
  }
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
      "INSERT INTO Show_Time (movie_id, auditorium_id, show_date, start_time, end_time, language) VALUES (?,?,?,?,?,?)",
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
  const conn = await db.getConnection();
  try {
    await conn.beginTransaction();
    const id = req.params.id;

    // 1. Get all tickets for this show
    const [tickets] = await conn.query(
      "SELECT ticket_id FROM Ticket WHERE show_id = ?", [id]
    );
    const ticketIds = tickets.map(r => r.ticket_id);

    if (ticketIds.length) {
      const tPlaceholders = ticketIds.map(() => '?').join(',');

      // 2. Get booking_ids linked to those tickets
      const [details] = await conn.query(
        `SELECT DISTINCT booking_id FROM Booking_Detail WHERE ticket_id IN (${tPlaceholders})`,
        ticketIds
      );
      const bookingIds = details.map(r => r.booking_id);

      if (bookingIds.length) {
        const bPlaceholders = bookingIds.map(() => '?').join(',');
        await conn.query(`DELETE FROM Revenue_Log   WHERE booking_id IN (${bPlaceholders})`, bookingIds);
        await conn.query(`DELETE FROM Booking_Log   WHERE booking_id IN (${bPlaceholders})`, bookingIds);
        await conn.query(`DELETE FROM Payment        WHERE booking_id IN (${bPlaceholders})`, bookingIds);
        await conn.query(`DELETE FROM Booking_Detail WHERE booking_id IN (${bPlaceholders})`, bookingIds);
        await conn.query(`DELETE FROM Booking        WHERE booking_id IN (${bPlaceholders})`, bookingIds);
      } else {
        await conn.query(`DELETE FROM Booking_Detail WHERE ticket_id IN (${tPlaceholders})`, ticketIds);
      }

      // 3. Delete tickets
      await conn.query(`DELETE FROM Ticket WHERE ticket_id IN (${tPlaceholders})`, ticketIds);
    }

    // 4. Delete the showtime
    await conn.query("DELETE FROM Show_Time WHERE show_id = ?", [id]);

    await conn.commit();
    res.json({ message: "Show deleted" });
  } catch (err) {
    await conn.rollback();
    sendError(res, err);
  } finally {
    conn.release();
  }
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
      "INSERT INTO Review (customer_id, movie_id, rating, comment) VALUES (?,?,?,?)",
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
//  GENRES  –  /api/genres
// ============================================================
app.get("/api/genres", async (req, res) => {
  try {
    const [rows] = await db.query("SELECT * FROM Genre ORDER BY genre_name");
    res.json(rows);
  } catch (err) { sendError(res, err); }
});

// ============================================================
//  THEATRES / AUDITORIUMS  –  /api/theatres
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
        t.location,
        ci.city_name
      FROM Auditorium a
      JOIN Theatre    t  ON a.theatre_id = t.theatre_id
      JOIN City       ci ON t.city_id    = ci.city_id
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
    const [[revenue]]   = await db.query(`
      SELECT COALESCE(
        SUM(CASE WHEN action='credit' THEN amount ELSE 0 END)
        - SUM(CASE WHEN action='debit' THEN amount ELSE 0 END), 0
      ) AS total
      FROM Revenue_Log
    `);
    const [[pending]]   = await db.query("SELECT COUNT(*) AS cnt FROM Booking WHERE payment_status='pending'");
    const [[cancelled]] = await db.query("SELECT COUNT(*) AS cnt FROM Booking WHERE payment_status='cancelled'");
    const [[shows]]     = await db.query("SELECT COUNT(*) AS cnt FROM Show_Time WHERE show_date >= CURDATE()");
    const [[reviews]]   = await db.query("SELECT COUNT(*) AS cnt FROM Review");
    const [[avgRating]] = await db.query("SELECT ROUND(AVG(rating),1) AS avg FROM Movie");
    const [[cities]]    = await db.query("SELECT COUNT(*) AS cnt FROM City");

    res.json({
      totalMovies:       movies.cnt,
      totalCustomers:    customers.cnt,
      totalBookings:     bookings.cnt,
      totalRevenue:      revenue.total,
      pendingBookings:   pending.cnt,
      cancelledBookings: cancelled.cnt,
      activeShows:       shows.cnt,
      totalReviews:      reviews.cnt,
      avgMovieRating:    avgRating.avg,
      totalCities:       cities.cnt,
    });
  } catch (err) { sendError(res, err); }
});

// ── Start ─────────────────────────────────────────────────────
app.listen(PORT, () => {
  console.log(`Cinema API running → http://localhost:${PORT}/api`);
});

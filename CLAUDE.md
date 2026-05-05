# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Full-stack Cinema Management System (DBMS mini project). Three-tier architecture: React SPA → Express REST API → MySQL.

## Development Commands

### Frontend (root directory)
```bash
npm start       # React dev server on http://localhost:3000
npm run build   # Production build
npm test        # Run Jest (no tests currently implemented)
```

### Backend (cinema-backend/)
```bash
cd cinema-backend
npm run dev     # nodemon server.js — auto-restart on file changes (port 5000)
npm start       # node server.js — production mode
```

### Database Setup
Import the schema before first run:
```bash
mysql -u root -p cinemamanagement < cinema_management_system.sql
```
DB credentials are hardcoded in `cinema-backend/db.js` (host: localhost, port: 3306, db: `cinemamanagement`, user: `root`).

## Architecture

```
React (port 3000)  →  Express API (port 5000)  →  MySQL (port 3306)
```

- Frontend proxies `/api` to `http://localhost:5000` via `package.json` `"proxy"` field
- All Axios calls go through `src/services/api.js`, which exports a `createEndpoint(resource)` factory that generates standard CRUD methods (`getAll`, `getById`, `create`, `update`, `delete`). Named exports: `movieApi`, `customerApi`, `bookingApi`, `showtimeApi`, `reviewApi`, `genreApi`, `theatreApi`.
- All Express routes live in a single file: `cinema-backend/server.js`. Each resource has GET/POST/PUT/DELETE handlers using parameterized queries via the `mysql2` pool in `cinema-backend/db.js`.

## Key Files

| File | Purpose |
|------|---------|
| `src/App.jsx` | React Router v6 route definitions |
| `src/services/api.js` | Axios base instance + endpoint factory |
| `src/pages/*.jsx` | One page per feature (Movies, Customers, Bookings, ShowTimes, Reviews, Dashboard) |
| `src/components/DataTable.jsx` | Reusable table with search/filter |
| `src/components/Modal.jsx` | Shared dialog + form component |
| `cinema-backend/server.js` | All REST API routes |
| `cinema-backend/db.js` | MySQL connection pool |
| `cinema_management_system.sql` | Full schema, triggers, and seed-ready structure |

## Database Schema Highlights

Core tables: `Movie`, `Customer`, `Booking`, `Booking_Detail`, `Ticket`, `Show_Time`, `Review`, `Theatre`, `Auditorium`, `Seat`.

Four triggers handle booking lifecycle:
- `trg_after_booking_insert` — fires on new booking
- `trg_after_booking_cancel` — logs cancellation to `Booking_Log`
- `trg_before_ticket_insert` — validates price
- `trg_after_ticket_price_update` — cascades price changes

## Real-time Revenue (SSE)

The backend streams live revenue via Server-Sent Events: `GET /api/revenue/stream`.  
`Dashboard.jsx` connects with `new EventSource(...)` and updates the hero card on every `onmessage`.  
Writes to `Revenue_Log` happen inside every booking/cancellation transaction; after commit the server calls `broadcastRevenue()` to push to all connected clients.

## Concurrency & Transactions

- **Pessimistic locking** (`SELECT … FOR UPDATE`) is used in `POST /api/bookings` and `PUT /api/bookings/:id` via a dedicated connection from the pool (`db.getConnection()`).  
- **Optimistic locking** columns (`version INT`) exist on `Ticket` and `Booking`; the SQL file demonstrates this via `BookTicketsTxn` and `CancelBookingTxn` stored procedures.  
- All multi-step mutations acquire a connection, call `beginTransaction()`, and either `commit()` or `rollback()` inside a try/catch.

## Normalisation Notes

- `City` table: Theatre no longer embeds city in the location string; `theatre.city_id` FK references `City`.
- `Seat_Category` table: Standard/Gold/Platinum/IMAX with `base_price`; `Seat.category_id` FK replaces ad-hoc prices per ticket.
- `Customer.created_at` and `Review.created_at` added (were missing from original schema but queried by the backend).

## Adding New Features

To add a new resource:
1. Add routes in `cinema-backend/server.js` following the existing pattern
2. Add a `createEndpoint('resource-name')` export in `src/services/api.js`
3. Create `src/pages/NewPage.jsx` and register it in `src/App.jsx`

## Design System (dark cinema theme)

CSS variables live in `src/App.css` under `:root`. Key tokens:
- `--c-bg: #0e0e14` — page background
- `--c-surface: #16161f` — cards / tables
- `--c-red: #e63946` — primary brand
- `--c-gold: #ffd166` — revenue / highlights
- `--c-text: #f0f0f8` — body text
- `--c-border: rgba(255,255,255,0.07)` — dividers

Fonts: **Inter** (body) + **Outfit** (headings/numbers) loaded from Google Fonts.

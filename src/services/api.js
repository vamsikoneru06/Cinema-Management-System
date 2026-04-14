// ============================================================
//  services/api.js
//  Centralized API layer for Cinema Management System
//  All HTTP calls go through this file.
//  Base URL points to your Express/Node backend on port 5000.
// ============================================================

import axios from "axios";

// ── Base configuration ───────────────────────────────────────
const BASE_URL = "http://localhost:5000/api";

const api = axios.create({
  baseURL: BASE_URL,
  headers: {
    "Content-Type": "application/json",
  },
  timeout: 10000, // 10 seconds
});

// ── Request interceptor (attach auth token if needed) ────────
api.interceptors.request.use(
  (config) => {
    const token = localStorage.getItem("token");
    if (token) {
      config.headers.Authorization = `Bearer ${token}`;
    }
    return config;
  },
  (error) => Promise.reject(error)
);

// ── Response interceptor (centralised error handling) ────────
api.interceptors.response.use(
  (response) => response,
  (error) => {
    const message =
      error.response?.data?.message || error.message || "Something went wrong";
    console.error("[API Error]", message);
    return Promise.reject(new Error(message));
  }
);

// ============================================================
//  Generic CRUD factory
//  Usage:
//    const movieApi = createEndpoint("movies");
//    movieApi.getAll()
//    movieApi.getById(1)
//    movieApi.create({ title: "RRR", ... })
//    movieApi.update(1, { rating: 9.2 })
//    movieApi.remove(1)
// ============================================================
const createEndpoint = (resource) => ({
  getAll: (params = {}) =>
    api.get(`/${resource}`, { params }).then((r) => r.data),

  getById: (id) =>
    api.get(`/${resource}/${id}`).then((r) => r.data),

  create: (data) =>
    api.post(`/${resource}`, data).then((r) => r.data),

  update: (id, data) =>
    api.put(`/${resource}/${id}`, data).then((r) => r.data),

  remove: (id) =>
    api.delete(`/${resource}/${id}`).then((r) => r.data),
});

// ============================================================
//  Table-specific endpoints
// ============================================================
export const movieApi     = createEndpoint("movies");
export const customerApi  = createEndpoint("customers");
export const bookingApi   = createEndpoint("bookings");
export const showTimeApi  = createEndpoint("showtimes");
export const reviewApi    = createEndpoint("reviews");
export const theatreApi   = createEndpoint("theatres");
export const genreApi     = createEndpoint("genres");
export const staffApi     = createEndpoint("staff");

// ============================================================
//  Dashboard – single aggregated endpoint
// ============================================================
export const dashboardApi = {
  getStats: () => api.get("/dashboard/stats").then((r) => r.data),
};

// ============================================================
//  Generic helpers (used when resource name is dynamic)
// ============================================================
export const getAll    = (table, params) => api.get(`/${table}`, { params }).then((r) => r.data);
export const getById   = (table, id)     => api.get(`/${table}/${id}`).then((r) => r.data);
export const create    = (table, data)   => api.post(`/${table}`, data).then((r) => r.data);
export const update    = (table, id, data) => api.put(`/${table}/${id}`, data).then((r) => r.data);
export const remove    = (table, id)     => api.delete(`/${table}/${id}`).then((r) => r.data);

export default api;

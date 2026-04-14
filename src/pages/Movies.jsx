// ============================================================
//  pages/Movies.jsx
//  Full CRUD: list, add, edit, delete movies.
// ============================================================

import React, { useEffect, useState, useCallback } from "react";
import DataTable from "../components/DataTable";
import Modal, { FormGroup, FormInput, FormSelect, FormRow } from "../components/Modal";
import { genreBadge } from "../components/Badge";
import { movieApi, genreApi } from "../services/api";
import "./Page.css";

const EMPTY_FORM = {
  title:        "",
  director:     "",
  producer:     "",
  genre_id:     "",
  release_date: "",
  duration:     "",
  rating:       "",
  budget:       "",
};

function validate(form) {
  const errors = {};
  if (!form.title.trim())                              errors.title    = "Title is required";
  if (!form.director.trim())                           errors.director = "Director is required";
  if (!form.duration || isNaN(form.duration) || +form.duration <= 0)
    errors.duration = "Enter a valid duration in minutes";
  if (form.rating && (+form.rating < 0 || +form.rating > 10))
    errors.rating = "Rating must be between 0 and 10";
  if (form.budget && isNaN(form.budget))
    errors.budget = "Budget must be a number";
  return errors;
}

const COLUMNS = [
  { key: "title",        label: "Title",    render: (v) => <strong>{v}</strong> },
  { key: "director",     label: "Director"  },
  { key: "genre_name",   label: "Genre",    render: (v) => genreBadge(v) },
  { key: "duration",     label: "Duration", render: (v) => v ? `${v} min` : "—" },
  { key: "rating",       label: "Rating",   render: (v) => v ? `⭐ ${v}` : "—" },
  { key: "release_date", label: "Released", render: (v) => v ? v.slice(0, 10) : "—" },
];

export default function Movies() {
  const [movies,  setMovies ] = useState([]);
  const [genres,  setGenres ] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error,   setError  ] = useState(null);
  const [saving,  setSaving ] = useState(false);
  const [toast,   setToast  ] = useState(null);

  const [modalOpen, setModalOpen] = useState(false);
  const [editRow,   setEditRow  ] = useState(null);
  const [form,      setForm     ] = useState(EMPTY_FORM);
  const [formErrors,setFormErrors] = useState({});

  // ── Fetch ────────────────────────────────────────────────
  const fetchMovies = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const [moviesData, genresData] = await Promise.all([
        movieApi.getAll(),
        genreApi.getAll(),
      ]);
      setMovies(Array.isArray(moviesData) ? moviesData : []);
      setGenres(Array.isArray(genresData) ? genresData : []);
    } catch (err) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => { fetchMovies(); }, [fetchMovies]);

  // ── Toast helper ─────────────────────────────────────────
  const showToast = (msg, type = "success") => {
    setToast({ msg, type });
    setTimeout(() => setToast(null), 3000);
  };

  // ── Modal helpers ─────────────────────────────────────────
  const openAdd = () => {
    setEditRow(null);
    setForm(EMPTY_FORM);
    setFormErrors({});
    setModalOpen(true);
  };

  const openEdit = (row) => {
    setEditRow(row);
    setForm({
      title:        row.title        ?? "",
      director:     row.director     ?? "",
      producer:     row.producer     ?? "",
      genre_id:     row.genre_id     ?? "",
      release_date: (row.release_date ?? "").slice(0, 10),
      duration:     String(row.duration ?? ""),
      rating:       String(row.rating   ?? ""),
      budget:       String(row.budget   ?? ""),
    });
    setFormErrors({});
    setModalOpen(true);
  };

  const closeModal = () => { setModalOpen(false); setEditRow(null); };

  const handleChange = (key) => (e) => {
    setForm((f) => ({ ...f, [key]: e.target.value }));
    if (formErrors[key]) setFormErrors((e) => ({ ...e, [key]: undefined }));
  };

  // ── Save ──────────────────────────────────────────────────
  const handleSave = async () => {
    const errors = validate(form);
    if (Object.keys(errors).length) { setFormErrors(errors); return; }

    setSaving(true);
    try {
      const payload = {
        ...form,
        duration: Number(form.duration),
        rating:   form.rating  ? Number(form.rating)  : null,
        budget:   form.budget  ? Number(form.budget)  : null,
        genre_id: form.genre_id ? Number(form.genre_id) : null,
      };
      if (editRow) {
        await movieApi.update(editRow.movie_id ?? editRow.id, payload);
        showToast("Movie updated successfully.");
      } else {
        await movieApi.create(payload);
        showToast("Movie added successfully.");
      }
      closeModal();
      fetchMovies();
    } catch (err) {
      showToast(err.message, "error");
    } finally {
      setSaving(false);
    }
  };

  // ── Delete ────────────────────────────────────────────────
  const handleDelete = async (row) => {
    if (!window.confirm(`Delete "${row.title}"? This cannot be undone.`)) return;
    try {
      await movieApi.remove(row.movie_id ?? row.id);
      showToast("Movie deleted.");
      fetchMovies();
    } catch (err) {
      showToast(err.message, "error");
    }
  };

  // ── Render ────────────────────────────────────────────────
  return (
    <div className="page">
      {toast && <div className={`toast toast--${toast.type}`}>{toast.msg}</div>}

      <div className="page-header">
        <h1 className="page-title">Movies</h1>
      </div>

      {error && <div className="alert alert--error">⚠ {error}</div>}

      <DataTable
        title="All Movies"
        columns={COLUMNS}
        data={movies}
        loading={loading}
        error={null}
        onEdit={openEdit}
        onDelete={handleDelete}
        onAdd={openAdd}
        addLabel="Add Movie"
        searchKeys={["title", "director", "genre_name"]}
      />

      {/* ── Add / Edit Modal ── */}
      <Modal
        isOpen={modalOpen}
        onClose={closeModal}
        onSubmit={handleSave}
        title={editRow ? `Edit: ${editRow.title}` : "Add New Movie"}
        submitLabel={editRow ? "Update" : "Add Movie"}
        loading={saving}
        size="lg"
      >
        <FormGroup label="Title" required error={formErrors.title}>
          <FormInput
            value={form.title}
            onChange={handleChange("title")}
            placeholder="e.g. RRR"
            error={formErrors.title}
          />
        </FormGroup>

        <FormRow>
          <FormGroup label="Director" required error={formErrors.director}>
            <FormInput
              value={form.director}
              onChange={handleChange("director")}
              placeholder="e.g. S.S. Rajamouli"
              error={formErrors.director}
            />
          </FormGroup>
          <FormGroup label="Producer">
            <FormInput
              value={form.producer}
              onChange={handleChange("producer")}
              placeholder="e.g. DVV Danayya"
            />
          </FormGroup>
        </FormRow>

        <FormRow>
          <FormGroup label="Genre">
            <FormSelect value={form.genre_id} onChange={handleChange("genre_id")}>
              <option value="">— Select genre —</option>
              {genres.map((g) => (
                <option key={g.genre_id ?? g.id} value={g.genre_id ?? g.id}>
                  {g.genre_name}
                </option>
              ))}
            </FormSelect>
          </FormGroup>
          <FormGroup label="Release Date">
            <FormInput
              type="date"
              value={form.release_date}
              onChange={handleChange("release_date")}
            />
          </FormGroup>
        </FormRow>

        <FormRow>
          <FormGroup label="Duration (minutes)" required error={formErrors.duration}>
            <FormInput
              type="number"
              value={form.duration}
              onChange={handleChange("duration")}
              placeholder="182"
              min="1"
              error={formErrors.duration}
            />
          </FormGroup>
          <FormGroup label="Rating (0–10)" error={formErrors.rating}>
            <FormInput
              type="number"
              step="0.1"
              value={form.rating}
              onChange={handleChange("rating")}
              placeholder="9.1"
              min="0"
              max="10"
              error={formErrors.rating}
            />
          </FormGroup>
        </FormRow>

        <FormGroup label="Budget (INR)" error={formErrors.budget}>
          <FormInput
            type="number"
            value={form.budget}
            onChange={handleChange("budget")}
            placeholder="5500000000"
            error={formErrors.budget}
          />
        </FormGroup>
      </Modal>
    </div>
  );
}

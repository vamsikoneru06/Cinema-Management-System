// ============================================================
//  pages/Reviews.jsx
//  View and delete customer reviews; add new reviews.
// ============================================================

import React, { useEffect, useState, useCallback } from "react";
import DataTable from "../components/DataTable";
import Modal, { FormGroup, FormInput, FormSelect, FormRow } from "../components/Modal";
import { reviewApi, customerApi, movieApi } from "../services/api";
import "./Page.css";

const EMPTY_FORM = { customer_id: "", movie_id: "", rating: "", comment: "" };

function validate(form) {
  const errors = {};
  if (!form.customer_id) errors.customer_id = "Select a customer";
  if (!form.movie_id)    errors.movie_id    = "Select a movie";
  if (!form.rating || isNaN(form.rating) || +form.rating < 0 || +form.rating > 5)
    errors.rating = "Rating must be between 0 and 5";
  return errors;
}

function StarRating({ value }) {
  const n = Math.round(Number(value) * 2) / 2;
  return (
    <span title={`${value} / 5`}>
      {"★".repeat(Math.floor(n))}{"☆".repeat(5 - Math.ceil(n))}{" "}
      <small style={{ color: "#888" }}>{value}</small>
    </span>
  );
}

const COLUMNS = [
  { key: "customer_name", label: "Customer", render: (v) => <strong>{v}</strong> },
  { key: "movie_title",   label: "Movie"    },
  { key: "rating",        label: "Rating",  render: (v) => <StarRating value={v} /> },
  { key: "comment",       label: "Comment", render: (v) => <span style={{ color: "#555", fontSize: 13 }}>{v}</span> },
  {
    key: "created_at", label: "Date",
    render: (v) => v ? new Date(v).toLocaleDateString("en-IN") : "—",
  },
];

export default function Reviews() {
  const [reviews,   setReviews  ] = useState([]);
  const [customers, setCustomers] = useState([]);
  const [movies,    setMovies   ] = useState([]);
  const [loading,   setLoading  ] = useState(true);
  const [error,     setError    ] = useState(null);
  const [saving,    setSaving   ] = useState(false);
  const [toast,     setToast    ] = useState(null);
  const [modalOpen, setModalOpen] = useState(false);
  const [form,      setForm     ] = useState(EMPTY_FORM);
  const [formErrors,setFormErrors] = useState({});

  const fetchAll = useCallback(async () => {
    setLoading(true); setError(null);
    try {
      const [rev, cust, mov] = await Promise.all([
        reviewApi.getAll(),
        customerApi.getAll(),
        movieApi.getAll(),
      ]);
      setReviews(Array.isArray(rev)   ? rev   : []);
      setCustomers(Array.isArray(cust) ? cust : []);
      setMovies(Array.isArray(mov)    ? mov    : []);
    } catch (err) { setError(err.message); }
    finally { setLoading(false); }
  }, []);

  useEffect(() => { fetchAll(); }, [fetchAll]);

  const showToast = (msg, type = "success") => {
    setToast({ msg, type });
    setTimeout(() => setToast(null), 3000);
  };

  const openAdd = () => {
    setForm(EMPTY_FORM); setFormErrors({}); setModalOpen(true);
  };
  const closeModal = () => setModalOpen(false);

  const handleChange = (key) => (e) => {
    setForm((f) => ({ ...f, [key]: e.target.value }));
    if (formErrors[key]) setFormErrors((fe) => ({ ...fe, [key]: undefined }));
  };

  const handleSave = async () => {
    const errors = validate(form);
    if (Object.keys(errors).length) { setFormErrors(errors); return; }
    setSaving(true);
    try {
      await reviewApi.create({
        customer_id: Number(form.customer_id),
        movie_id:    Number(form.movie_id),
        rating:      Number(form.rating),
        comment:     form.comment,
      });
      showToast("Review added.");
      closeModal(); fetchAll();
    } catch (err) { showToast(err.message, "error"); }
    finally { setSaving(false); }
  };

  const handleDelete = async (row) => {
    if (!window.confirm("Delete this review?")) return;
    try {
      await reviewApi.remove(row.review_id ?? row.id);
      showToast("Review deleted."); fetchAll();
    } catch (err) { showToast(err.message, "error"); }
  };

  const avgRating = reviews.length
    ? (reviews.reduce((s, r) => s + Number(r.rating || 0), 0) / reviews.length).toFixed(1)
    : "—";

  return (
    <div className="page">
      {toast && <div className={`toast toast--${toast.type}`}>{toast.msg}</div>}
      <div className="page-header">
        <h1 className="page-title">Reviews</h1>
        <span style={{ fontSize: 14, color: "#555" }}>
          Avg rating: <strong>⭐ {avgRating} / 5</strong>
        </span>
      </div>
      {error && <div className="alert alert--error">⚠ {error}</div>}

      <DataTable
        title={`Customer Reviews (${reviews.length})`}
        columns={COLUMNS}
        data={reviews}
        loading={loading}
        onDelete={handleDelete}
        onAdd={openAdd}
        addLabel="Add Review"
        searchKeys={["customer_name", "movie_title", "comment"]}
      />

      <Modal
        isOpen={modalOpen}
        onClose={closeModal}
        onSubmit={handleSave}
        title="Add New Review"
        submitLabel="Submit Review"
        loading={saving}
        size="lg"
      >
        <FormRow>
          <FormGroup label="Customer" required error={formErrors.customer_id}>
            <FormSelect value={form.customer_id} onChange={handleChange("customer_id")} error={formErrors.customer_id}>
              <option value="">— Select customer —</option>
              {customers.map((c) => (
                <option key={c.customer_id ?? c.id} value={c.customer_id ?? c.id}>{c.name}</option>
              ))}
            </FormSelect>
          </FormGroup>
          <FormGroup label="Movie" required error={formErrors.movie_id}>
            <FormSelect value={form.movie_id} onChange={handleChange("movie_id")} error={formErrors.movie_id}>
              <option value="">— Select movie —</option>
              {movies.map((m) => (
                <option key={m.movie_id ?? m.id} value={m.movie_id ?? m.id}>{m.title}</option>
              ))}
            </FormSelect>
          </FormGroup>
        </FormRow>

        <FormGroup label="Rating (0–5)" required error={formErrors.rating}>
          <FormInput
            type="number"
            step="0.5"
            min="0"
            max="5"
            value={form.rating}
            onChange={handleChange("rating")}
            placeholder="4.5"
            error={formErrors.rating}
          />
        </FormGroup>

        <FormGroup label="Comment">
          <textarea
            className="form-input form-textarea"
            value={form.comment}
            onChange={handleChange("comment")}
            placeholder="Write your review here…"
            rows={3}
          />
        </FormGroup>
      </Modal>
    </div>
  );
}

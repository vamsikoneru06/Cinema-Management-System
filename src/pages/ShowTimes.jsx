// ============================================================
//  pages/ShowTimes.jsx
//  Full CRUD for movie show schedules.
// ============================================================

import React, { useEffect, useState, useCallback } from "react";
import DataTable from "../components/DataTable";
import Modal, { FormGroup, FormInput, FormSelect, FormRow } from "../components/Modal";
import { showTimeApi, movieApi, theatreApi } from "../services/api";
import "./Page.css";

const LANGUAGES = ["Hindi", "Telugu", "Tamil", "Kannada", "Malayalam", "English"];

const EMPTY_FORM = {
  movie_id:      "",
  auditorium_id: "",
  show_date:     "",
  start_time:    "",
  end_time:      "",
  language:      "Hindi",
};

function validate(form) {
  const errors = {};
  if (!form.movie_id)      errors.movie_id      = "Select a movie";
  if (!form.auditorium_id) errors.auditorium_id = "Select a theatre/hall";
  if (!form.show_date)     errors.show_date     = "Date is required";
  if (!form.start_time)    errors.start_time    = "Start time is required";
  if (!form.end_time)      errors.end_time      = "End time is required";
  if (form.start_time && form.end_time && form.start_time >= form.end_time)
    errors.end_time = "End time must be after start time";
  return errors;
}

const COLUMNS = [
  { key: "movie_title",     label: "Movie",    render: (v) => <strong>{v}</strong> },
  { key: "theatre_name",    label: "Theatre"   },
  { key: "show_date",       label: "Date",     render: (v) => v ? v.slice(0, 10) : "—" },
  { key: "start_time",      label: "Starts",   render: (v) => v?.slice(0, 5) ?? "—" },
  { key: "end_time",        label: "Ends",     render: (v) => v?.slice(0, 5) ?? "—" },
  { key: "language",        label: "Language"  },
];

export default function ShowTimes() {
  const [shows,     setShows    ] = useState([]);
  const [movies,    setMovies   ] = useState([]);
  const [theatres,  setTheatres ] = useState([]);
  const [loading,   setLoading  ] = useState(true);
  const [error,     setError    ] = useState(null);
  const [saving,    setSaving   ] = useState(false);
  const [toast,     setToast    ] = useState(null);
  const [modalOpen, setModalOpen] = useState(false);
  const [editRow,   setEditRow  ] = useState(null);
  const [form,      setForm     ] = useState(EMPTY_FORM);
  const [formErrors,setFormErrors] = useState({});

  const fetchAll = useCallback(async () => {
    setLoading(true); setError(null);
    try {
      const [showsData, moviesData, theatresData] = await Promise.all([
        showTimeApi.getAll(),
        movieApi.getAll(),
        theatreApi.getAll(),
      ]);
      setShows(Array.isArray(showsData)   ? showsData   : []);
      setMovies(Array.isArray(moviesData) ? moviesData  : []);
      setTheatres(Array.isArray(theatresData) ? theatresData : []);
    } catch (err) { setError(err.message); }
    finally { setLoading(false); }
  }, []);

  useEffect(() => { fetchAll(); }, [fetchAll]);

  const showToast = (msg, type = "success") => {
    setToast({ msg, type });
    setTimeout(() => setToast(null), 3000);
  };

  const openAdd = () => {
    setEditRow(null); setForm(EMPTY_FORM); setFormErrors({}); setModalOpen(true);
  };
  const openEdit = (row) => {
    setEditRow(row);
    setForm({
      movie_id:      String(row.movie_id      ?? ""),
      auditorium_id: String(row.auditorium_id ?? ""),
      show_date:     (row.show_date ?? "").slice(0, 10),
      start_time:    (row.start_time ?? "").slice(0, 5),
      end_time:      (row.end_time   ?? "").slice(0, 5),
      language:      row.language ?? "Hindi",
    });
    setFormErrors({}); setModalOpen(true);
  };
  const closeModal = () => { setModalOpen(false); setEditRow(null); };

  const handleChange = (key) => (e) => {
    setForm((f) => ({ ...f, [key]: e.target.value }));
    if (formErrors[key]) setFormErrors((fe) => ({ ...fe, [key]: undefined }));
  };

  const handleSave = async () => {
    const errors = validate(form);
    if (Object.keys(errors).length) { setFormErrors(errors); return; }
    setSaving(true);
    try {
      const payload = { ...form, movie_id: Number(form.movie_id), auditorium_id: Number(form.auditorium_id) };
      if (editRow) {
        await showTimeApi.update(editRow.show_id ?? editRow.id, payload);
        showToast("Show updated.");
      } else {
        await showTimeApi.create(payload);
        showToast("Show scheduled.");
      }
      closeModal(); fetchAll();
    } catch (err) { showToast(err.message, "error"); }
    finally { setSaving(false); }
  };

  const handleDelete = async (row) => {
    if (!window.confirm("Remove this show?")) return;
    try {
      await showTimeApi.remove(row.show_id ?? row.id);
      showToast("Show removed."); fetchAll();
    } catch (err) { showToast(err.message, "error"); }
  };

  return (
    <div className="page">
      {toast && <div className={`toast toast--${toast.type}`}>{toast.msg}</div>}
      <div className="page-header"><h1 className="page-title">Show Times</h1></div>
      {error && <div className="alert alert--error">⚠ {error}</div>}

      <DataTable
        title="Scheduled Shows"
        columns={COLUMNS}
        data={shows}
        loading={loading}
        onEdit={openEdit}
        onDelete={handleDelete}
        onAdd={openAdd}
        addLabel="Schedule Show"
        searchKeys={["movie_title", "theatre_name", "language"]}
      />

      <Modal
        isOpen={modalOpen}
        onClose={closeModal}
        onSubmit={handleSave}
        title={editRow ? "Edit Show" : "Schedule New Show"}
        submitLabel={editRow ? "Update" : "Schedule"}
        loading={saving}
        size="lg"
      >
        <FormRow>
          <FormGroup label="Movie" required error={formErrors.movie_id}>
            <FormSelect value={form.movie_id} onChange={handleChange("movie_id")} error={formErrors.movie_id}>
              <option value="">— Select movie —</option>
              {movies.map((m) => (
                <option key={m.movie_id ?? m.id} value={m.movie_id ?? m.id}>{m.title}</option>
              ))}
            </FormSelect>
          </FormGroup>
          <FormGroup label="Theatre / Auditorium" required error={formErrors.auditorium_id}>
            <FormSelect value={form.auditorium_id} onChange={handleChange("auditorium_id")} error={formErrors.auditorium_id}>
              <option value="">— Select hall —</option>
              {theatres.map((t) => (
                <option key={t.auditorium_id ?? t.id} value={t.auditorium_id ?? t.id}>
                  {t.theatre_name ?? t.name} — Hall {t.hall_number}
                </option>
              ))}
            </FormSelect>
          </FormGroup>
        </FormRow>

        <FormRow>
          <FormGroup label="Show Date" required error={formErrors.show_date}>
            <FormInput type="date" value={form.show_date} onChange={handleChange("show_date")} error={formErrors.show_date} />
          </FormGroup>
          <FormGroup label="Language">
            <FormSelect value={form.language} onChange={handleChange("language")}>
              {LANGUAGES.map((l) => <option key={l}>{l}</option>)}
            </FormSelect>
          </FormGroup>
        </FormRow>

        <FormRow>
          <FormGroup label="Start Time" required error={formErrors.start_time}>
            <FormInput type="time" value={form.start_time} onChange={handleChange("start_time")} error={formErrors.start_time} />
          </FormGroup>
          <FormGroup label="End Time" required error={formErrors.end_time}>
            <FormInput type="time" value={form.end_time} onChange={handleChange("end_time")} error={formErrors.end_time} />
          </FormGroup>
        </FormRow>
      </Modal>
    </div>
  );
}

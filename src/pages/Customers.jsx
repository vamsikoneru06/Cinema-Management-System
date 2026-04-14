// ============================================================
//  pages/Customers.jsx
//  Full CRUD for registered cinema customers.
// ============================================================

import React, { useEffect, useState, useCallback } from "react";
import DataTable from "../components/DataTable";
import Modal, { FormGroup, FormInput, FormRow } from "../components/Modal";
import { customerApi } from "../services/api";
import "./Page.css";

const EMPTY_FORM = { name: "", email: "", phone: "+91", password: "" };

function validate(form, isEdit) {
  const errors = {};
  if (!form.name.trim()) errors.name = "Name is required";
  if (!form.email.trim() || !/\S+@\S+\.\S+/.test(form.email))
    errors.email = "Enter a valid email address";
  if (!isEdit && form.password.length < 6)
    errors.password = "Password must be at least 6 characters";
  if (form.phone && !/^\+91\d{10}$/.test(form.phone))
    errors.phone = "Phone format: +91XXXXXXXXXX";
  return errors;
}

const COLUMNS = [
  {
    key: "name", label: "Name",
    render: (v, row) => (
      <div style={{ display: "flex", alignItems: "center", gap: 10 }}>
        <div style={{
          width: 30, height: 30, borderRadius: "50%",
          background: "#fdecea", color: "#c0392b",
          display: "flex", alignItems: "center", justifyContent: "center",
          fontSize: 12, fontWeight: 700, flexShrink: 0,
        }}>
          {(v || "?").split(" ").map((w) => w[0]).join("").slice(0, 2).toUpperCase()}
        </div>
        <span style={{ fontWeight: 500 }}>{v}</span>
      </div>
    ),
  },
  { key: "email", label: "Email" },
  { key: "phone", label: "Phone" },
  {
    key: "created_at", label: "Joined",
    render: (v) => v ? new Date(v).toLocaleDateString("en-IN") : "—",
  },
];

export default function Customers() {
  const [customers, setCustomers] = useState([]);
  const [loading,   setLoading  ] = useState(true);
  const [error,     setError    ] = useState(null);
  const [saving,    setSaving   ] = useState(false);
  const [toast,     setToast    ] = useState(null);
  const [modalOpen, setModalOpen] = useState(false);
  const [editRow,   setEditRow  ] = useState(null);
  const [form,      setForm     ] = useState(EMPTY_FORM);
  const [formErrors,setFormErrors] = useState({});

  const fetchCustomers = useCallback(async () => {
    setLoading(true); setError(null);
    try {
      const data = await customerApi.getAll();
      setCustomers(Array.isArray(data) ? data : []);
    } catch (err) { setError(err.message); }
    finally { setLoading(false); }
  }, []);

  useEffect(() => { fetchCustomers(); }, [fetchCustomers]);

  const showToast = (msg, type = "success") => {
    setToast({ msg, type });
    setTimeout(() => setToast(null), 3000);
  };

  const openAdd = () => {
    setEditRow(null); setForm(EMPTY_FORM); setFormErrors({}); setModalOpen(true);
  };
  const openEdit = (row) => {
    setEditRow(row);
    setForm({ name: row.name ?? "", email: row.email ?? "", phone: row.phone ?? "+91", password: "" });
    setFormErrors({}); setModalOpen(true);
  };
  const closeModal = () => { setModalOpen(false); setEditRow(null); };

  const handleChange = (key) => (e) => {
    setForm((f) => ({ ...f, [key]: e.target.value }));
    if (formErrors[key]) setFormErrors((fe) => ({ ...fe, [key]: undefined }));
  };

  const handleSave = async () => {
    const errors = validate(form, !!editRow);
    if (Object.keys(errors).length) { setFormErrors(errors); return; }
    setSaving(true);
    try {
      const payload = { name: form.name, email: form.email, phone: form.phone };
      if (!editRow) payload.password = form.password;
      if (editRow) {
        await customerApi.update(editRow.customer_id ?? editRow.id, payload);
        showToast("Customer updated.");
      } else {
        await customerApi.create(payload);
        showToast("Customer added.");
      }
      closeModal(); fetchCustomers();
    } catch (err) { showToast(err.message, "error"); }
    finally { setSaving(false); }
  };

  const handleDelete = async (row) => {
    if (!window.confirm(`Delete customer "${row.name}"?`)) return;
    try {
      await customerApi.remove(row.customer_id ?? row.id);
      showToast("Customer deleted.");
      fetchCustomers();
    } catch (err) { showToast(err.message, "error"); }
  };

  return (
    <div className="page">
      {toast && <div className={`toast toast--${toast.type}`}>{toast.msg}</div>}
      <div className="page-header"><h1 className="page-title">Customers</h1></div>
      {error && <div className="alert alert--error">⚠ {error}</div>}

      <DataTable
        title="Registered Customers"
        columns={COLUMNS}
        data={customers}
        loading={loading}
        onEdit={openEdit}
        onDelete={handleDelete}
        onAdd={openAdd}
        addLabel="Add Customer"
        searchKeys={["name", "email", "phone"]}
      />

      <Modal
        isOpen={modalOpen}
        onClose={closeModal}
        onSubmit={handleSave}
        title={editRow ? `Edit: ${editRow.name}` : "Add New Customer"}
        submitLabel={editRow ? "Update" : "Add Customer"}
        loading={saving}
      >
        <FormGroup label="Full Name" required error={formErrors.name}>
          <FormInput value={form.name} onChange={handleChange("name")} placeholder="Rajesh Kumar" error={formErrors.name} />
        </FormGroup>
        <FormGroup label="Email" required error={formErrors.email}>
          <FormInput type="email" value={form.email} onChange={handleChange("email")} placeholder="rajesh@example.com" error={formErrors.email} />
        </FormGroup>
        <FormRow>
          <FormGroup label="Phone" error={formErrors.phone}>
            <FormInput value={form.phone} onChange={handleChange("phone")} placeholder="+919876543210" error={formErrors.phone} />
          </FormGroup>
          {!editRow && (
            <FormGroup label="Password" required error={formErrors.password}>
              <FormInput type="password" value={form.password} onChange={handleChange("password")} placeholder="Min 6 characters" error={formErrors.password} />
            </FormGroup>
          )}
        </FormRow>
      </Modal>
    </div>
  );
}

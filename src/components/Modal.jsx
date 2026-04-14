// ============================================================
//  components/Modal.jsx
//  Generic modal dialog for create / edit forms.
//
//  Props:
//    isOpen   – boolean
//    onClose  – () => void
//    onSubmit – () => void
//    title    – string
//    children – ReactNode  (form fields go here)
//    submitLabel – string  (default "Save")
//    loading  – boolean    (disables submit while saving)
//    size     – "sm" | "md" | "lg"  (default "md")
// ============================================================

import React, { useEffect } from "react";
import "./Modal.css";

export default function Modal({
  isOpen,
  onClose,
  onSubmit,
  title,
  children,
  submitLabel = "Save",
  loading = false,
  size = "md",
}) {
  // Close on Escape key
  useEffect(() => {
    if (!isOpen) return;
    const handler = (e) => {
      if (e.key === "Escape") onClose();
    };
    window.addEventListener("keydown", handler);
    return () => window.removeEventListener("keydown", handler);
  }, [isOpen, onClose]);

  // Prevent body scroll while open
  useEffect(() => {
    document.body.style.overflow = isOpen ? "hidden" : "";
    return () => { document.body.style.overflow = ""; };
  }, [isOpen]);

  if (!isOpen) return null;

  return (
    <div
      className="modal-overlay"
      onClick={(e) => { if (e.target === e.currentTarget) onClose(); }}
      role="dialog"
      aria-modal="true"
      aria-labelledby="modal-title"
    >
      <div className={`modal modal--${size}`}>
        {/* ── Header ── */}
        <div className="modal__header">
          <h2 className="modal__title" id="modal-title">{title}</h2>
          <button
            className="modal__close"
            onClick={onClose}
            aria-label="Close"
          >
            ×
          </button>
        </div>

        {/* ── Body ── */}
        <div className="modal__body">{children}</div>

        {/* ── Footer ── */}
        <div className="modal__footer">
          <button
            className="btn btn--secondary"
            onClick={onClose}
            disabled={loading}
            type="button"
          >
            Cancel
          </button>
          <button
            className="btn btn--primary"
            onClick={onSubmit}
            disabled={loading}
            type="button"
          >
            {loading ? "Saving…" : submitLabel}
          </button>
        </div>
      </div>
    </div>
  );
}

// ── Reusable form field helpers ──────────────────────────────

export function FormGroup({ label, error, children, required }) {
  return (
    <div className="form-group">
      {label && (
        <label className="form-label">
          {label}
          {required && <span className="form-required"> *</span>}
        </label>
      )}
      {children}
      {error && <p className="form-error">{error}</p>}
    </div>
  );
}

export function FormInput({ error, ...props }) {
  return (
    <input
      className={`form-input${error ? " form-input--error" : ""}`}
      {...props}
    />
  );
}

export function FormSelect({ error, children, ...props }) {
  return (
    <select
      className={`form-input${error ? " form-input--error" : ""}`}
      {...props}
    >
      {children}
    </select>
  );
}

export function FormTextarea({ error, ...props }) {
  return (
    <textarea
      className={`form-input form-textarea${error ? " form-input--error" : ""}`}
      {...props}
    />
  );
}

export function FormRow({ children }) {
  return <div className="form-row">{children}</div>;
}

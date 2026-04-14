// ============================================================
//  components/DataTable.jsx
//  Generic, reusable data table with search, loading, empty
//  states, and per-row action buttons.
//
//  Props:
//    columns  – Array<{ key, label, render? }>
//    data     – Array<object>
//    loading  – boolean
//    error    – string | null
//    onEdit   – (row) => void  (optional)
//    onDelete – (row) => void  (optional)
//    searchKeys – Array<string> (keys to search across)
//    title    – string
//    onAdd    – () => void  (optional – shows "+ Add" button)
//    addLabel – string  (defaults to "Add")
// ============================================================

import React, { useState, useMemo } from "react";
import "./DataTable.css";

export default function DataTable({
  columns = [],
  data = [],
  loading = false,
  error = null,
  onEdit,
  onDelete,
  searchKeys = [],
  title = "",
  onAdd,
  addLabel = "Add",
}) {
  const [query, setQuery] = useState("");

  // Client-side search
  const filtered = useMemo(() => {
    if (!query.trim() || searchKeys.length === 0) return data;
    const q = query.toLowerCase();
    return data.filter((row) =>
      searchKeys.some((key) =>
        String(row[key] ?? "").toLowerCase().includes(q)
      )
    );
  }, [data, query, searchKeys]);

  const showActions = onEdit || onDelete;

  return (
    <div className="dt-wrapper">
      {/* ── Header ── */}
      <div className="dt-header">
        <div className="dt-header-left">
          {title && <h2 className="dt-title">{title}</h2>}
          <span className="dt-count">{filtered.length} record{filtered.length !== 1 ? "s" : ""}</span>
        </div>

        <div className="dt-header-right">
          {searchKeys.length > 0 && (
            <div className="dt-search-wrap">
              <span className="dt-search-icon">&#128269;</span>
              <input
                className="dt-search"
                type="text"
                placeholder="Search…"
                value={query}
                onChange={(e) => setQuery(e.target.value)}
              />
              {query && (
                <button className="dt-clear-btn" onClick={() => setQuery("")}>×</button>
              )}
            </div>
          )}
          {onAdd && (
            <button className="btn btn--primary" onClick={onAdd}>
              + {addLabel}
            </button>
          )}
        </div>
      </div>

      {/* ── Table ── */}
      <div className="dt-scroll">
        {loading ? (
          <div className="dt-state">
            <div className="dt-spinner" />
            <p>Loading…</p>
          </div>
        ) : error ? (
          <div className="dt-state dt-state--error">
            <p>&#9888;&#65039; {error}</p>
          </div>
        ) : filtered.length === 0 ? (
          <div className="dt-state">
            <p>{query ? "No results match your search." : "No records found."}</p>
          </div>
        ) : (
          <table className="dt-table">
            <thead>
              <tr>
                {columns.map((col) => (
                  <th key={col.key}>{col.label}</th>
                ))}
                {showActions && <th className="dt-col-actions">Actions</th>}
              </tr>
            </thead>
            <tbody>
              {filtered.map((row, idx) => (
                <tr key={row.id ?? idx}>
                  {columns.map((col) => (
                    <td key={col.key}>
                      {col.render
                        ? col.render(row[col.key], row)
                        : row[col.key] ?? "—"}
                    </td>
                  ))}
                  {showActions && (
                    <td className="dt-col-actions">
                      <div className="dt-actions">
                        {onEdit && (
                          <button
                            className="btn btn--sm btn--outline"
                            onClick={() => onEdit(row)}
                          >
                            Edit
                          </button>
                        )}
                        {onDelete && (
                          <button
                            className="btn btn--sm btn--danger"
                            onClick={() => onDelete(row)}
                          >
                            Delete
                          </button>
                        )}
                      </div>
                    </td>
                  )}
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </div>
    </div>
  );
}

import React, { useEffect, useMemo, useState } from "react";
import { collection, limit, onSnapshot, query } from "firebase/firestore";
import { httpsCallable } from "firebase/functions";
import { db, credibilityFunctions } from "../firebase";

// Only http(s) links are ever rendered as clickable (blocks javascript:/data: URLs).
const isSafeWebUrl = (url) => {
  if (!url || typeof url !== "string") return false;
  const t = url.trim().toLowerCase();
  return t.startsWith("https://") || t.startsWith("http://");
};

const STATUS_STYLE = {
  pending_review: { label: "Pending review", color: "#f59e0b" },
  applied: { label: "Applied", color: "#10b981" },
  approved_pending_rerun: { label: "Approved (no single claim)", color: "#38bdf8" },
  link_failed: { label: "Link failed check", color: "#ef4444" },
  rejected: { label: "Rejected", color: "#9ca3af" },
};

const toMillis = (v) => (v?.toMillis ? v.toMillis() : typeof v === "number" ? v : new Date(v || 0).getTime());

/**
 * Reviewer queue for sources submitted from the AI Check page ("Provide source") and
 * creator disputes. Approving runs the live link check and re-checks the single claim;
 * the outcome (verdict changed or not) is shown on the card.
 */
export default function CommunityEvidenceQueue({ formatDate }) {
  const [items, setItems] = useState([]);
  const [filter, setFilter] = useState("pending_review");
  const [notes, setNotes] = useState({});
  const [busyId, setBusyId] = useState("");
  const [message, setMessage] = useState({ type: "", text: "" });

  useEffect(() => {
    const q = query(collection(db, "claim_sources"), limit(300));
    const unsub = onSnapshot(
      q,
      (snap) => {
        const list = snap.docs.map((d) => ({ id: d.id, ...d.data() }));
        list.sort((a, b) => toMillis(b.createdAtMs || b.submittedAt) - toMillis(a.createdAtMs || a.submittedAt));
        setItems(list);
      },
      () => setMessage({ type: "error", text: "Could not load the evidence queue. Please refresh the page." })
    );
    return () => unsub();
  }, []);

  const visible = useMemo(
    () => (filter === "all" ? items : items.filter((i) => (i.status || "pending_review") === filter)),
    [items, filter]
  );
  const pendingCount = items.filter((i) => (i.status || "pending_review") === "pending_review").length;

  const review = async (item, decision) => {
    setBusyId(item.id);
    setMessage({ type: "", text: "" });
    try {
      const fn = httpsCallable(credibilityFunctions, "reviewCommunityEvidence");
      const res = await fn({ evidenceId: item.evidenceId || item.id, decision, reviewerNotes: notes[item.id] || "" });
      const outcome = res?.data?.outcome?.message;
      setMessage({ type: "success", text: outcome || (decision === "approve" ? "Evidence approved." : "Evidence rejected.") });
    } catch (err) {
      setMessage({ type: "error", text: err?.message || "Could not complete the review. Please try again." });
    } finally {
      setBusyId("");
    }
  };

  return (
    <div className="glass" style={{ padding: "16px", borderRadius: "12px", border: "1px solid var(--border)", display: "flex", flexDirection: "column", gap: "12px" }}>
      <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", flexWrap: "wrap", gap: "8px" }}>
        <div>
          <div style={{ fontSize: "16px", fontWeight: 700 }}>Community Evidence Queue</div>
          <div style={{ fontSize: "12px", color: "var(--text-secondary)" }}>
            {pendingCount} pending · Approving checks the link live and re-checks only that claim. The verdict may stay the same.
          </div>
        </div>
        <select value={filter} onChange={(e) => setFilter(e.target.value)} style={{ padding: "6px 10px", borderRadius: "8px" }}>
          <option value="pending_review">Pending review</option>
          <option value="applied">Applied</option>
          <option value="approved_pending_rerun">Approved (no single claim)</option>
          <option value="link_failed">Link failed</option>
          <option value="rejected">Rejected</option>
          <option value="all">All</option>
        </select>
      </div>

      {message.text && (
        <div style={{ fontSize: "13px", padding: "8px 12px", borderRadius: "8px", background: message.type === "error" ? "rgba(239,68,68,0.12)" : "rgba(16,185,129,0.12)", color: message.type === "error" ? "#fca5a5" : "#6ee7b7" }}>
          {message.text}
        </div>
      )}

      {visible.length === 0 ? (
        <div style={{ fontSize: "13px", color: "var(--text-muted)", padding: "12px 0" }}>Nothing in this view.</div>
      ) : (
        visible.map((item) => {
          const status = item.status || "pending_review";
          const st = STATUS_STYLE[status] || { label: status, color: "#9ca3af" };
          const urls = Array.isArray(item.urls) && item.urls.length ? item.urls : item.url ? [item.url] : [];
          const created = item.createdAtMs || item.submittedAt;
          return (
            <div key={item.id} style={{ background: "rgba(0,0,0,0.25)", borderRadius: "10px", padding: "12px", border: "1px solid rgba(255,255,255,0.06)", display: "flex", flexDirection: "column", gap: "6px" }}>
              <div style={{ display: "flex", justifyContent: "space-between", gap: "8px", flexWrap: "wrap" }}>
                <span style={{ fontSize: "12px", fontWeight: 700, color: st.color }}>{st.label}</span>
                <span style={{ fontSize: "11px", color: "var(--text-muted)" }}>
                  {item.submitterRole === "creator" ? "Creator" : "Viewer"} · Video {item.videoId} · {created && formatDate ? formatDate(created) : ""}
                </span>
              </div>
              <div style={{ fontSize: "13px" }}>
                <strong>Claim:</strong> {item.claimText || (item.claimId ? `Claim ${item.claimId}` : "Entire video")}
              </div>
              {item.note && (
                <div style={{ fontSize: "12px", color: "#d1d5db" }}>
                  <strong>Submitter says:</strong> {item.note}
                </div>
              )}
              <div style={{ display: "flex", flexDirection: "column", gap: "2px" }}>
                {urls.map((u) =>
                  isSafeWebUrl(u) ? (
                    <a key={u} href={u} target="_blank" rel="noopener noreferrer nofollow" style={{ fontSize: "12px", color: "#38bdf8", wordBreak: "break-all" }}>{u}</a>
                  ) : (
                    <span key={u} style={{ fontSize: "12px", color: "var(--text-muted)", wordBreak: "break-all" }}>{u}</span>
                  )
                )}
              </div>
              {item.outcome?.message && (
                <div style={{ fontSize: "12px", color: "var(--text-secondary)" }}>
                  <strong>Outcome:</strong> {item.outcome.message}
                  {item.outcome.previousStatus && ` (${item.outcome.previousStatus} → ${item.outcome.newStatus})`}
                </div>
              )}
              {status === "pending_review" && (
                <div style={{ display: "flex", gap: "8px", alignItems: "center", flexWrap: "wrap", marginTop: "4px" }}>
                  <input
                    type="text"
                    placeholder="Reviewer notes (optional)"
                    value={notes[item.id] || ""}
                    onChange={(e) => setNotes({ ...notes, [item.id]: e.target.value })}
                    style={{ flex: "1 1 220px", padding: "6px 10px", borderRadius: "8px" }}
                  />
                  <button disabled={busyId === item.id} onClick={() => review(item, "approve")}
                    style={{ padding: "6px 14px", borderRadius: "8px", background: "#10b981", color: "#000", fontWeight: 700, border: "none", cursor: "pointer" }}>
                    {busyId === item.id ? "Working…" : "Approve & re-check"}
                  </button>
                  <button disabled={busyId === item.id} onClick={() => review(item, "reject")}
                    style={{ padding: "6px 14px", borderRadius: "8px", background: "transparent", color: "#fca5a5", border: "1px solid #ef4444", cursor: "pointer" }}>
                    Reject
                  </button>
                </div>
              )}
            </div>
          );
        })
      )}
    </div>
  );
}

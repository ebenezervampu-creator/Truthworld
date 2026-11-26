import React, { useState, useEffect } from "react";
import { 
  collection, 
  query, 
  where, 
  limit, 
  onSnapshot 
} from "firebase/firestore";
import { httpsCallable } from "firebase/functions";
import { db, functions } from "../firebase";
import CommunityEvidenceQueue from "./CommunityEvidenceQueue";

// Helper to strictly validate safe web URLs and prevent XSS (javascript: / data: schemes)
const isSafeWebUrl = (url) => {
  if (!url || typeof url !== "string") return false;
  const trimmed = url.trim().toLowerCase();
  return trimmed.startsWith("https://") || trimmed.startsWith("http://");
};

export default function AppealsDeskTab({ user, formatDate }) {
  const [appeals, setAppeals] = useState([]);
  const [filterStatus, setFilterStatus] = useState("all");
  const [searchQuery, setSearchQuery] = useState("");
  const [selectedAppeal, setSelectedAppeal] = useState(null);

  // Adjudication form state
  const [decision, setDecision] = useState("upheld");
  const [newVerdict, setNewVerdict] = useState("verified_true");
  const [reviewerNotes, setReviewerNotes] = useState("");
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [actionError, setActionError] = useState("");
  const [actionSuccess, setActionSuccess] = useState("");

  // Cryptographic Audit Log verification state
  const [isVerifyingChain, setIsVerifyingChain] = useState(false);
  const [chainVerifyResult, setChainVerifyResult] = useState(null);
  const [auditLogs, setAuditLogs] = useState([]);

  // Real-time listener for claim_appeals
  useEffect(() => {
    const appealsQuery = query(
      collection(db, "claim_appeals"),
      limit(200)
    );

    const unsubscribe = onSnapshot(appealsQuery, (snapshot) => {
      const list = snapshot.docs.map((doc) => ({
        id: doc.id,
        ...doc.data(),
      }));

      // Sort descending by submittedAt or createdAt
      list.sort((a, b) => {
        const timeA = a.submittedAt || a.createdAt || 0;
        const timeB = b.submittedAt || b.createdAt || 0;
        const dtA = timeA?.toMillis ? timeA.toMillis() : new Date(timeA).getTime();
        const dtB = timeB?.toMillis ? timeB.toMillis() : new Date(timeB).getTime();
        return dtB - dtA;
      });

      setAppeals(list);

      // Keep selected appeal updated if currently active
      if (selectedAppeal) {
        const updated = list.find((a) => a.id === selectedAppeal.id);
        if (updated) {
          setSelectedAppeal(updated);
        }
      }
    }, (err) => {
      console.error("[AppealsDesk] Firestore subscription failed:", err);
    });

    return () => unsubscribe();
  }, [selectedAppeal?.id]);

  // Real-time listener for governance audit logs for the selected video/target
  useEffect(() => {
    if (!selectedAppeal?.videoId) {
      setAuditLogs([]);
      setChainVerifyResult(null);
      return;
    }

    const logsQuery = query(
      collection(db, "governance_audit_logs"),
      where("targetId", "==", selectedAppeal.videoId),
      limit(50)
    );

    const unsubLogs = onSnapshot(logsQuery, (snapshot) => {
      const logs = snapshot.docs.map((d) => ({
        id: d.id,
        ...d.data(),
      }));
      logs.sort((a, b) => (b.timestamp || 0) - (a.timestamp || 0));
      setAuditLogs(logs);
    }, (err) => {
      console.warn("[AppealsDesk] Audit logs query warning:", err);
    });

    return () => unsubLogs();
  }, [selectedAppeal?.videoId]);

  // Reset form when selected appeal changes
  useEffect(() => {
    if (selectedAppeal) {
      setDecision("upheld");
      setNewVerdict(selectedAppeal.originalVerdict === "false_claim" ? "verified_true" : "mostly_true");
      setReviewerNotes("");
      setActionError("");
      setActionSuccess("");
      setChainVerifyResult(null);
    }
  }, [selectedAppeal?.id]);

  // Quorum & conflict calculations
  const appellantId = selectedAppeal?.appellantId;
  const channelId = selectedAppeal?.channelId;
  const currentUserId = user?.uid;
  const existingReviews = Array.isArray(selectedAppeal?.reviews) ? selectedAppeal.reviews : [];
  const firstReview = existingReviews[0] || null;
  const secondReview = existingReviews[1] || null;

  const isAppellant = currentUserId && appellantId === currentUserId;
  const isChannelOwner = currentUserId && channelId === currentUserId;
  const hasConflictOfInterest = isAppellant || isChannelOwner;
  const hasAlreadyReviewed = currentUserId && existingReviews.some((r) => r.reviewerId === currentUserId);
  const isResolved = ["upheld", "overturned", "modified"].includes(selectedAppeal?.status);
  const isEscalated = selectedAppeal?.status === "escalated_to_board";

  // Filter appeals
  const filteredAppeals = appeals.filter((a) => {
    const status = (a.status || "submitted").toLowerCase();

    if (filterStatus === "pending") {
      if (!["submitted", "under_review", "under_secondary_review"].includes(status)) return false;
    } else if (filterStatus === "escalated") {
      if (status !== "escalated_to_board") return false;
    } else if (filterStatus === "resolved") {
      if (!["upheld", "overturned", "modified"].includes(status)) return false;
    }

    if (searchQuery.trim()) {
      const q = searchQuery.toLowerCase();
      const matchText = (a.claimText || "").toLowerCase().includes(q);
      const matchVideo = (a.videoId || "").toLowerCase().includes(q);
      const matchAppealId = (a.appealId || a.id || "").toLowerCase().includes(q);
      const matchAppellant = (a.appellantId || "").toLowerCase().includes(q);
      return matchText || matchVideo || matchAppealId || matchAppellant;
    }

    return true;
  });

  // System stats
  const pendingCount = appeals.filter((a) =>
    ["submitted", "under_review", "under_secondary_review"].includes((a.status || "").toLowerCase())
  ).length;
  const escalatedCount = appeals.filter((a) => (a.status || "").toLowerCase() === "escalated_to_board").length;
  const resolvedCount = appeals.filter((a) =>
    ["upheld", "overturned", "modified"].includes((a.status || "").toLowerCase())
  ).length;

  // Handle ombudsman resolution submission
  const handleSubmitDecision = async (e) => {
    e.preventDefault();
    if (!selectedAppeal) return;

    if (!reviewerNotes.trim() || reviewerNotes.trim().length < 10) {
      setActionError("Substantive reviewer rationale is required (minimum 10 characters) for the public audit log.");
      return;
    }

    if (hasConflictOfInterest) {
      setActionError("Conflict of Interest Defense: You cannot adjudicate appeals on your own video content.");
      return;
    }

    if (hasAlreadyReviewed) {
      setActionError("Dual-Signoff Quorum: You have already submitted Review 1. A different ombudsman is required to satisfy quorum.");
      return;
    }

    setIsSubmitting(true);
    setActionError("");
    setActionSuccess("");

    try {
      const resolveClaimAppealFn = httpsCallable(functions, "resolveClaimAppeal");
      const res = await resolveClaimAppealFn({
        appealId: selectedAppeal.appealId || selectedAppeal.id,
        decision,
        newVerdict: decision === "upheld" ? selectedAppeal.originalVerdict : newVerdict,
        reviewerNotes: reviewerNotes.trim(),
      });

      const data = res.data || {};
      if (data.finalStatus === "under_secondary_review") {
        setActionSuccess("Initial ombudsman review recorded! Awaiting secondary independent ombudsman sign-off to satisfy quorum.");
      } else if (data.finalStatus === "escalated_to_board") {
        setActionSuccess("Ombudsman review recorded. Because reviewer findings diverged, this case has been escalated to the IFCN Editorial Board.");
      } else {
        setActionSuccess(`Appeal successfully finalized: Finding marked ${decision.toUpperCase()}. Video claim verdict updated.`);
      }
      setReviewerNotes("");
    } catch (err) {
      console.error("[AppealsDesk] Resolution failed:", err);
      setActionError(err.message || "Failed to submit ombudsman decision. Please try again.");
    } finally {
      setIsSubmitting(false);
    }
  };

  // Handle Cryptographic Audit Log verification
  const handleVerifyChain = async () => {
    if (!selectedAppeal?.videoId) return;
    setIsVerifyingChain(true);
    setChainVerifyResult(null);

    try {
      const verifyAuditChainFn = httpsCallable(functions, "verifyGovernanceAuditChain");
      const res = await verifyAuditChainFn({ targetId: selectedAppeal.videoId });
      setChainVerifyResult(res.data);
    } catch (err) {
      console.error("[AppealsDesk] Chain verification failed:", err);
      setChainVerifyResult({ isValid: false, error: err.message });
    } finally {
      setIsVerifyingChain(false);
    }
  };

  const getStatusBadge = (status) => {
    const s = (status || "submitted").toLowerCase();
    switch (s) {
      case "submitted":
      case "under_review":
        return <span className="badge pending" style={{ background: "rgba(245, 158, 11, 0.2)", color: "#f59e0b", border: "1px solid #f59e0b" }}>PENDING QUORUM (0/2)</span>;
      case "under_secondary_review":
        return <span className="badge" style={{ background: "rgba(59, 130, 246, 0.2)", color: "#60a5fa", border: "1px solid #3b82f6" }}>1/2 SIGNATURES RECORDED</span>;
      case "escalated_to_board":
        return <span className="badge" style={{ background: "rgba(168, 85, 247, 0.2)", color: "#c084fc", border: "1px solid #a855f7" }}>ESCALATED TO BOARD</span>;
      case "overturned":
        return <span className="badge approved" style={{ background: "rgba(16, 185, 129, 0.2)", color: "#10b981", border: "1px solid #10b981" }}>OVERTURNED (RESTORED)</span>;
      case "modified":
        return <span className="badge" style={{ background: "rgba(14, 165, 233, 0.2)", color: "#38bdf8", border: "1px solid #0ea5e9" }}>MODIFIED (NUANCED)</span>;
      case "upheld":
        return <span className="badge rejected" style={{ background: "rgba(239, 68, 68, 0.2)", color: "#ef4444", border: "1px solid #ef4444" }}>UPHELD (CONFIRMED)</span>;
      default:
        return <span className="badge">{status.toUpperCase()}</span>;
    }
  };

  const getVerdictBadge = (verdict) => {
    const v = (verdict || "").toLowerCase();
    if (v.includes("true") || v.includes("correct")) {
      return <span className="badge approved">{verdict}</span>;
    }
    if (v.includes("false") || v.includes("incorrect") || v.includes("misleading")) {
      return <span className="badge rejected">{verdict}</span>;
    }
    return <span className="badge pending" style={{ background: "rgba(234, 179, 8, 0.2)", color: "#eab308" }}>{verdict}</span>;
  };

  return (
    <div className="appeals-desk-container" style={{ display: "flex", flexDirection: "column", gap: "20px" }}>
      <CommunityEvidenceQueue formatDate={formatDate} />
      {/* Metrics Bar */}
      <div style={{ display: "grid", gridTemplateColumns: "repeat(auto-fit, minmax(200px, 1fr))", gap: "16px" }}>
        <div className="glass" style={{ padding: "16px", borderRadius: "12px", border: "1px solid var(--border)" }}>
          <div style={{ fontSize: "12px", color: "var(--text-secondary)", textTransform: "uppercase", letterSpacing: "0.5px" }}>Pending Quorum</div>
          <div style={{ fontSize: "28px", fontWeight: "700", color: "#f59e0b", marginTop: "4px" }}>{pendingCount}</div>
          <div style={{ fontSize: "11px", color: "var(--text-secondary)", marginTop: "4px" }}>Awaiting 1st or 2nd ombudsman</div>
        </div>
        <div className="glass" style={{ padding: "16px", borderRadius: "12px", border: "1px solid var(--border)" }}>
          <div style={{ fontSize: "12px", color: "var(--text-secondary)", textTransform: "uppercase", letterSpacing: "0.5px" }}>Board Escalations</div>
          <div style={{ fontSize: "28px", fontWeight: "700", color: "#c084fc", marginTop: "4px" }}>{escalatedCount}</div>
          <div style={{ fontSize: "11px", color: "var(--text-secondary)", marginTop: "4px" }}>Ombudsmen split consensus</div>
        </div>
        <div className="glass" style={{ padding: "16px", borderRadius: "12px", border: "1px solid var(--border)" }}>
          <div style={{ fontSize: "12px", color: "var(--text-secondary)", textTransform: "uppercase", letterSpacing: "0.5px" }}>Resolved Cases</div>
          <div style={{ fontSize: "28px", fontWeight: "700", color: "#10b981", marginTop: "4px" }}>{resolvedCount}</div>
          <div style={{ fontSize: "11px", color: "var(--text-secondary)", marginTop: "4px" }}>Signed with SHA-256 audit proof</div>
        </div>
        <div className="glass" style={{ padding: "16px", borderRadius: "12px", border: "1px solid var(--border)" }}>
          <div style={{ fontSize: "12px", color: "var(--text-secondary)", textTransform: "uppercase", letterSpacing: "0.5px" }}>Total Appeal Filings</div>
          <div style={{ fontSize: "28px", fontWeight: "700", color: "#ffffff", marginTop: "4px" }}>{appeals.length}</div>
          <div style={{ fontSize: "11px", color: "var(--text-secondary)", marginTop: "4px" }}>100% indexed in Firestore</div>
        </div>
      </div>

      {/* Filter & Search Bar */}
      <div className="glass" style={{ padding: "14px 20px", borderRadius: "12px", display: "flex", flexWrap: "wrap", justifyContent: "space-between", alignItems: "center", gap: "12px", border: "1px solid var(--border)" }}>
        <div style={{ display: "flex", gap: "8px", flexWrap: "wrap" }}>
          <button 
            className={`btn-secondary ${filterStatus === "all" ? "active" : ""}`}
            style={{ padding: "6px 14px", fontSize: "13px", borderRadius: "8px", background: filterStatus === "all" ? "var(--accent)" : "transparent", color: filterStatus === "all" ? "#000" : "#fff" }}
            onClick={() => setFilterStatus("all")}
          >
            All Filings ({appeals.length})
          </button>
          <button 
            className={`btn-secondary ${filterStatus === "pending" ? "active" : ""}`}
            style={{ padding: "6px 14px", fontSize: "13px", borderRadius: "8px", background: filterStatus === "pending" ? "var(--accent)" : "transparent", color: filterStatus === "pending" ? "#000" : "#fff" }}
            onClick={() => setFilterStatus("pending")}
          >
            Pending Quorum ({pendingCount})
          </button>
          <button 
            className={`btn-secondary ${filterStatus === "escalated" ? "active" : ""}`}
            style={{ padding: "6px 14px", fontSize: "13px", borderRadius: "8px", background: filterStatus === "escalated" ? "var(--accent)" : "transparent", color: filterStatus === "escalated" ? "#000" : "#fff" }}
            onClick={() => setFilterStatus("escalated")}
          >
            Board Escalations ({escalatedCount})
          </button>
          <button 
            className={`btn-secondary ${filterStatus === "resolved" ? "active" : ""}`}
            style={{ padding: "6px 14px", fontSize: "13px", borderRadius: "8px", background: filterStatus === "resolved" ? "var(--accent)" : "transparent", color: filterStatus === "resolved" ? "#000" : "#fff" }}
            onClick={() => setFilterStatus("resolved")}
          >
            Resolved ({resolvedCount})
          </button>
        </div>

        <div style={{ position: "relative", minWidth: "260px" }}>
          <input 
            type="text"
            placeholder="Search claim, video, or creator ID..."
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            style={{ width: "100%", padding: "8px 12px", borderRadius: "8px", background: "rgba(0,0,0,0.3)", border: "1px solid var(--border)", color: "#fff", fontSize: "13px" }}
          />
          {searchQuery && (
            <button 
              onClick={() => setSearchQuery("")}
              style={{ position: "absolute", right: "8px", top: "50%", transform: "translateY(-50%)", background: "none", border: "none", color: "var(--text-secondary)", cursor: "pointer" }}
            >
              ✕
            </button>
          )}
        </div>
      </div>

      {/* Main Split Layout */}
      <div className={`queue-layout ${selectedAppeal ? "split" : ""}`}>
        {/* Left Pane: Appeals List */}
        <div className="list-pane">
          {filteredAppeals.length === 0 ? (
            <div className="empty-state glass" style={{ padding: "40px", textAlign: "center" }}>
              <div style={{ fontSize: "32px", marginBottom: "8px" }}>🏛️</div>
              <p style={{ color: "var(--text-secondary)", fontSize: "15px" }}>No claim appeals match the current filter.</p>
              <p style={{ fontSize: "12px", color: "var(--text-muted)", marginTop: "4px" }}>Creators can file formal IFCN appeals from the TruthWorld video claim inspector.</p>
            </div>
          ) : (
            filteredAppeals.map((appeal) => (
              <div
                key={appeal.id}
                className={`item-card glass ${selectedAppeal?.id === appeal.id ? "selected" : ""}`}
                onClick={() => setSelectedAppeal(appeal)}
                style={{ cursor: "pointer", borderLeft: selectedAppeal?.id === appeal.id ? "3px solid var(--accent)" : "3px solid transparent" }}
              >
                <div className="item-info" style={{ width: "100%" }}>
                  <div style={{ display: "flex", justifyContent: "space-between", alignItems: "flex-start", gap: "8px" }}>
                    <div className="item-title" style={{ fontSize: "14px", fontWeight: "600", color: "#fff", lineClamp: 2, display: "-webkit-box", WebkitLineClamp: 2, WebkitBoxOrient: "vertical", overflow: "hidden" }}>
                      "{appeal.claimText || "Contested Claim"}"
                    </div>
                  </div>

                  <div className="item-meta" style={{ display: "flex", flexWrap: "wrap", alignItems: "center", gap: "8px", marginTop: "6px" }}>
                    <span>Video: {appeal.videoId?.substring(0, 12)}...</span>
                    <span>•</span>
                    <span>Filed: {formatDate(appeal.submittedAt || appeal.createdAt)}</span>
                  </div>

                  <div style={{ display: "flex", flexWrap: "wrap", gap: "8px", alignItems: "center", marginTop: "10px" }}>
                    {getStatusBadge(appeal.status)}
                    <span style={{ fontSize: "11px", color: "var(--text-secondary)" }}>Original:</span>
                    {getVerdictBadge(appeal.originalVerdict)}
                  </div>
                </div>
              </div>
            ))
          )}
        </div>

        {/* Right Pane: Selected Appeal Detail & Adjudication Console */}
        {selectedAppeal && (
          <div className="detail-pane glass" style={{ overflowY: "auto", maxHeight: "85vh", padding: "24px" }}>
            <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", borderBottom: "1px solid var(--border)", paddingBottom: "14px", marginBottom: "20px" }}>
              <div>
                <div style={{ fontSize: "11px", textTransform: "uppercase", letterSpacing: "1px", color: "var(--accent)" }}>IFCN Fact-Checking Ombudsman Adjudication</div>
                <h3 style={{ margin: "4px 0 0", fontSize: "18px", color: "#fff" }}>Appeal ID: {selectedAppeal.appealId || selectedAppeal.id}</h3>
              </div>
              <button 
                className="btn-close-pane" 
                onClick={() => setSelectedAppeal(null)}
                style={{ background: "rgba(255,255,255,0.08)", border: "none", color: "#fff", width: "32px", height: "32px", borderRadius: "50%", cursor: "pointer", fontSize: "16px" }}
              >
                ✕
              </button>
            </div>

            {/* Contested Claim Box */}
            <div style={{ background: "rgba(255, 255, 255, 0.03)", border: "1px solid rgba(255, 255, 255, 0.1)", borderRadius: "10px", padding: "16px", marginBottom: "20px" }}>
              <div style={{ fontSize: "11px", color: "var(--text-secondary)", textTransform: "uppercase", letterSpacing: "0.5px", marginBottom: "6px" }}>Contested Verbatim Claim</div>
              <div style={{ fontSize: "15px", fontStyle: "italic", color: "#f3f4f6", lineHeight: "1.5" }}>
                "{selectedAppeal.claimText}"
              </div>
              <div style={{ display: "flex", alignItems: "center", gap: "10px", marginTop: "12px", paddingTop: "12px", borderTop: "1px solid rgba(255,255,255,0.06)" }}>
                <span style={{ fontSize: "12px", color: "var(--text-secondary)" }}>Algorithmic Finding:</span>
                {getVerdictBadge(selectedAppeal.originalVerdict)}
                <span style={{ fontSize: "12px", color: "var(--text-secondary)", marginLeft: "auto" }}>Status:</span>
                {getStatusBadge(selectedAppeal.status)}
              </div>
            </div>

            {/* Creator's Rationale & Evidence */}
            <div style={{ marginBottom: "20px" }}>
              <h4 style={{ color: "#fff", fontSize: "14px", marginBottom: "8px", display: "flex", alignItems: "center", gap: "6px" }}>
                <span>📜</span> Creator's Substantive Rebuttal Context
              </h4>
              <div style={{ background: "rgba(245, 158, 11, 0.05)", border: "1px solid rgba(245, 158, 11, 0.2)", borderRadius: "8px", padding: "14px", color: "#e5e7eb", fontSize: "13px", lineHeight: "1.6" }}>
                {selectedAppeal.creatorRationale || "No substantive context provided."}
              </div>

              {selectedAppeal.evidenceUrls && selectedAppeal.evidenceUrls.length > 0 && (
                <div style={{ marginTop: "10px" }}>
                  <div style={{ fontSize: "12px", color: "var(--text-secondary)", marginBottom: "6px" }}>Supporting Primary Sources / Citations:</div>
                  <ul style={{ margin: 0, paddingLeft: "18px", fontSize: "12px" }}>
                    {selectedAppeal.evidenceUrls.map((url, idx) => (
                      <li key={idx} style={{ marginBottom: "4px" }}>
                        {isSafeWebUrl(url) ? (
                          <a href={url} target="_blank" rel="noopener noreferrer" style={{ color: "var(--accent)", textDecoration: "underline", wordBreak: "break-all" }}>
                            {url}
                          </a>
                        ) : (
                          <span style={{ color: "#ef4444", wordBreak: "break-all" }}>
                            [Blocked Insecure Citation URI]: {String(url).replace(/[<>"'`]/g, "")}
                          </span>
                        )}
                      </li>
                    ))}
                  </ul>
                </div>
              )}
            </div>

            {/* Metadata Table */}
            <div style={{ marginBottom: "24px" }}>
              <h4 style={{ color: "var(--text-secondary)", fontSize: "13px", marginBottom: "8px" }}>Appeal & Target Metadata</h4>
              <table className="metadata-table" style={{ width: "100%", fontSize: "12px" }}>
                <tbody>
                  <tr>
                    <td className="label" style={{ color: "var(--text-muted)", width: "35%" }}>Target Video ID</td>
                    <td className="value" style={{ wordBreak: "break-all" }}>{selectedAppeal.videoId}</td>
                  </tr>
                  <tr>
                    <td className="label" style={{ color: "var(--text-muted)" }}>Contested Claim ID</td>
                    <td className="value">{selectedAppeal.claimId}</td>
                  </tr>
                  <tr>
                    <td className="label" style={{ color: "var(--text-muted)" }}>Appellant (Creator UID)</td>
                    <td className="value" style={{ wordBreak: "break-all" }}>{selectedAppeal.appellantId}</td>
                  </tr>
                  <tr>
                    <td className="label" style={{ color: "var(--text-muted)" }}>Channel ID</td>
                    <td className="value">{selectedAppeal.channelId || "N/A"}</td>
                  </tr>
                  <tr>
                    <td className="label" style={{ color: "var(--text-muted)" }}>Filing Timestamp</td>
                    <td className="value">{formatDate(selectedAppeal.submittedAt || selectedAppeal.createdAt)}</td>
                  </tr>
                  <tr>
                    <td className="label" style={{ color: "var(--text-muted)" }}>Quorum Protocol</td>
                    <td className="value" style={{ color: "#38bdf8" }}>2 Independent Ombudsmen Dual-Signoff Quorum</td>
                  </tr>
                </tbody>
              </table>
            </div>

            {/* Multi-Signatory Quorum Ledger */}
            <div style={{ background: "rgba(0, 0, 0, 0.25)", border: "1px solid var(--border)", borderRadius: "10px", padding: "16px", marginBottom: "24px" }}>
              <h4 style={{ color: "#fff", fontSize: "14px", margin: "0 0 12px", display: "flex", alignItems: "center", gap: "8px" }}>
                <span>⚖️</span> Multi-Signatory Ombudsman Quorum Ledger
              </h4>

              {/* Stepper / Sign-offs */}
              <div style={{ display: "flex", flexDirection: "column", gap: "10px" }}>
                {/* Sign-off 1 */}
                <div style={{ display: "flex", gap: "12px", alignItems: "flex-start", padding: "10px", borderRadius: "8px", background: firstReview ? "rgba(16, 185, 129, 0.08)" : "rgba(255, 255, 255, 0.02)", border: firstReview ? "1px solid rgba(16, 185, 129, 0.3)" : "1px dashed rgba(255, 255, 255, 0.1)" }}>
                  <div style={{ width: "24px", height: "24px", borderRadius: "50%", background: firstReview ? "#10b981" : "rgba(255,255,255,0.1)", display: "flex", alignItems: "center", justifyContent: "center", fontSize: "12px", fontWeight: "700", color: "#000" }}>
                    {firstReview ? "✓" : "1"}
                  </div>
                  <div style={{ flex: 1 }}>
                    <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center" }}>
                      <span style={{ fontSize: "13px", fontWeight: "600", color: firstReview ? "#10b981" : "#fff" }}>
                        {firstReview ? `Ombudsman Signatory 1 (${firstReview.decision.toUpperCase()})` : "First Independent Ombudsman Review"}
                      </span>
                      {firstReview && (
                        <span style={{ fontSize: "11px", color: "var(--text-secondary)" }}>{formatDate(firstReview.reviewedAt)}</span>
                      )}
                    </div>
                    {firstReview ? (
                      <div style={{ fontSize: "12px", color: "var(--text-secondary)", marginTop: "4px" }}>
                        <div>Reviewer ID: <code style={{ color: "#fff" }}>{firstReview.reviewerId}</code></div>
                        <div style={{ marginTop: "2px", color: "#e5e7eb", fontStyle: "italic" }}>"{firstReview.reviewerNotes}"</div>
                        {firstReview.newVerdict && <div style={{ marginTop: "2px" }}>Verdict: <strong>{firstReview.newVerdict}</strong></div>}
                      </div>
                    ) : (
                      <div style={{ fontSize: "12px", color: "var(--text-muted)", marginTop: "2px" }}>Awaiting initial independent ombudsman evaluation.</div>
                    )}
                  </div>
                </div>

                {/* Sign-off 2 */}
                <div style={{ display: "flex", gap: "12px", alignItems: "flex-start", padding: "10px", borderRadius: "8px", background: secondReview ? "rgba(16, 185, 129, 0.08)" : "rgba(255, 255, 255, 0.02)", border: secondReview ? "1px solid rgba(16, 185, 129, 0.3)" : "1px dashed rgba(255, 255, 255, 0.1)" }}>
                  <div style={{ width: "24px", height: "24px", borderRadius: "50%", background: secondReview ? "#10b981" : "rgba(255,255,255,0.1)", display: "flex", alignItems: "center", justifyContent: "center", fontSize: "12px", fontWeight: "700", color: "#000" }}>
                    {secondReview ? "✓" : "2"}
                  </div>
                  <div style={{ flex: 1 }}>
                    <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center" }}>
                      <span style={{ fontSize: "13px", fontWeight: "600", color: secondReview ? "#10b981" : "#fff" }}>
                        {secondReview ? `Ombudsman Signatory 2 (${secondReview.decision.toUpperCase()})` : "Secondary Independent Ombudsman Review"}
                      </span>
                      {secondReview && (
                        <span style={{ fontSize: "11px", color: "var(--text-secondary)" }}>{formatDate(secondReview.reviewedAt)}</span>
                      )}
                    </div>
                    {secondReview ? (
                      <div style={{ fontSize: "12px", color: "var(--text-secondary)", marginTop: "4px" }}>
                        <div>Reviewer ID: <code style={{ color: "#fff" }}>{secondReview.reviewerId}</code></div>
                        <div style={{ marginTop: "2px", color: "#e5e7eb", fontStyle: "italic" }}>"{secondReview.reviewerNotes}"</div>
                        {secondReview.newVerdict && <div style={{ marginTop: "2px" }}>Verdict: <strong>{secondReview.newVerdict}</strong></div>}
                      </div>
                    ) : (
                      <div style={{ fontSize: "12px", color: "var(--text-muted)", marginTop: "2px" }}>
                        {firstReview ? "Requires second distinct ombudsman to confirm or escalate to board." : "Pending initial review completion."}
                      </div>
                    )}
                  </div>
                </div>
              </div>
            </div>

            {/* Conflict of Interest Warning if applicable */}
            {hasConflictOfInterest && (
              <div style={{ background: "rgba(239, 68, 68, 0.1)", border: "1px solid rgba(239, 68, 68, 0.3)", borderRadius: "8px", padding: "12px 16px", marginBottom: "20px", color: "#fca5a5", fontSize: "13px" }}>
                <strong>🛡️ Conflict of Interest Firewall Active:</strong> As the creator or channel administrator for this video, you are barred from adjudicating this appeal. An independent ombudsman must review this case.
              </div>
            )}

            {hasAlreadyReviewed && !isResolved && (
              <div style={{ background: "rgba(59, 130, 246, 0.1)", border: "1px solid rgba(59, 130, 246, 0.3)", borderRadius: "8px", padding: "12px 16px", marginBottom: "20px", color: "#93c5fd", fontSize: "13px" }}>
                <strong>ℹ️ Quorum Notice:</strong> You have already logged Review 1. Under IFCN multi-signatory standards, a different ombudsman account must log Review 2 to prevent single-reviewer bias.
              </div>
            )}

            {isEscalated && (
              <div style={{ background: "rgba(168, 85, 247, 0.1)", border: "1px solid rgba(168, 85, 247, 0.3)", borderRadius: "8px", padding: "12px 16px", marginBottom: "20px", color: "#c084fc", fontSize: "13px" }}>
                <strong>🏛️ Escalated to Board:</strong> Ombudsman reviewers diverged on this case. It is currently before the IFCN Editorial Board for full panel consensus.
              </div>
            )}

            {/* Adjudication Form (only visible if unresolved, unescalated, and not conflicted/already reviewed) */}
            {!isResolved && !isEscalated && !hasConflictOfInterest && !hasAlreadyReviewed && (
              <form onSubmit={handleSubmitDecision} style={{ background: "rgba(255, 255, 255, 0.02)", border: "1px solid var(--border)", borderRadius: "10px", padding: "18px", marginBottom: "24px" }}>
                <h4 style={{ color: "#fff", fontSize: "15px", margin: "0 0 14px", display: "flex", alignItems: "center", gap: "6px" }}>
                  <span>✍️</span> Submit Ombudsman Adjudication
                </h4>

                {/* Decision Selector */}
                <div style={{ marginBottom: "16px" }}>
                  <label style={{ display: "block", fontSize: "12px", color: "var(--text-secondary)", marginBottom: "8px" }}>Adjudication Decision:</label>
                  <div style={{ display: "grid", gridTemplateColumns: "repeat(auto-fit, minmax(130px, 1fr))", gap: "10px" }}>
                    <label style={{ display: "flex", alignItems: "center", gap: "8px", padding: "10px", borderRadius: "8px", border: decision === "upheld" ? "2px solid #ef4444" : "1px solid var(--border)", background: decision === "upheld" ? "rgba(239, 68, 68, 0.1)" : "rgba(0,0,0,0.2)", cursor: "pointer", fontSize: "13px" }}>
                      <input type="radio" name="decision" value="upheld" checked={decision === "upheld"} onChange={() => setDecision("upheld")} />
                      <span>Uphold Finding</span>
                    </label>
                    <label style={{ display: "flex", alignItems: "center", gap: "8px", padding: "10px", borderRadius: "8px", border: decision === "overturned" ? "2px solid #10b981" : "1px solid var(--border)", background: decision === "overturned" ? "rgba(16, 185, 129, 0.1)" : "rgba(0,0,0,0.2)", cursor: "pointer", fontSize: "13px" }}>
                      <input type="radio" name="decision" value="overturned" checked={decision === "overturned"} onChange={() => setDecision("overturned")} />
                      <span>Overturn Finding</span>
                    </label>
                    <label style={{ display: "flex", alignItems: "center", gap: "8px", padding: "10px", borderRadius: "8px", border: decision === "modified" ? "2px solid #38bdf8" : "1px solid var(--border)", background: decision === "modified" ? "rgba(56, 189, 248, 0.1)" : "rgba(0,0,0,0.2)", cursor: "pointer", fontSize: "13px" }}>
                      <input type="radio" name="decision" value="modified" checked={decision === "modified"} onChange={() => setDecision("modified")} />
                      <span>Modify Verdict</span>
                    </label>
                  </div>
                </div>

                {/* Nuanced Verdict Selector if Overturned or Modified */}
                {(decision === "overturned" || decision === "modified") && (
                  <div style={{ marginBottom: "16px" }}>
                    <label style={{ display: "block", fontSize: "12px", color: "var(--text-secondary)", marginBottom: "6px" }}>Target Verdict Classification:</label>
                    <select
                      value={newVerdict}
                      onChange={(e) => setNewVerdict(e.target.value)}
                      style={{ width: "100%", padding: "10px", borderRadius: "8px", background: "rgba(0,0,0,0.4)", border: "1px solid var(--border)", color: "#fff", fontSize: "13px" }}
                    >
                      <option value="verified_true">Verified True (Authoritative consensus)</option>
                      <option value="mostly_true">Mostly True (Substantially accurate)</option>
                      <option value="disputed">Disputed / Frontier (Legitimate scientific or historical ambiguity)</option>
                      <option value="unproven">Unproven (Insufficient authoritative records)</option>
                      <option value="not_historically_verifiable">Not Historically Verifiable (Digital/Archival scarcity)</option>
                      <option value="inconclusive">Inconclusive (No verifiable benchmark data)</option>
                    </select>
                  </div>
                )}

                {/* Rationale Input */}
                <div style={{ marginBottom: "16px" }}>
                  <div style={{ display: "flex", justifyContent: "space-between", marginBottom: "6px" }}>
                    <label style={{ fontSize: "12px", color: "var(--text-secondary)" }}>Editorial Public Rationale (required):</label>
                    <span style={{ fontSize: "11px", color: reviewerNotes.trim().length >= 10 ? "#10b981" : "var(--text-muted)" }}>
                      {reviewerNotes.trim().length} / 10 min chars
                    </span>
                  </div>
                  <textarea
                    rows={4}
                    placeholder="Provide substantive, evidence-grounded reasoning explaining this decision. This rationale will be permanently recorded into the cryptographic SHA-256 governance audit chain..."
                    value={reviewerNotes}
                    onChange={(e) => setReviewerNotes(e.target.value)}
                    style={{ width: "100%", padding: "10px", borderRadius: "8px", background: "rgba(0,0,0,0.3)", border: "1px solid var(--border)", color: "#fff", fontSize: "13px", resize: "vertical" }}
                  />
                </div>

                {/* Error & Success Feedback */}
                {actionError && (
                  <div style={{ color: "#f87171", fontSize: "13px", marginBottom: "12px", padding: "8px 12px", borderRadius: "6px", background: "rgba(239, 68, 68, 0.1)" }}>
                    {actionError}
                  </div>
                )}
                {actionSuccess && (
                  <div style={{ color: "#34d399", fontSize: "13px", marginBottom: "12px", padding: "8px 12px", borderRadius: "6px", background: "rgba(16, 185, 129, 0.1)" }}>
                    {actionSuccess}
                  </div>
                )}

                <button
                  type="submit"
                  disabled={isSubmitting || reviewerNotes.trim().length < 10}
                  className="btn-primary"
                  style={{ width: "100%", padding: "12px", borderRadius: "8px", fontSize: "14px", fontWeight: "600", cursor: isSubmitting || reviewerNotes.trim().length < 10 ? "not-allowed" : "pointer", opacity: isSubmitting || reviewerNotes.trim().length < 10 ? 0.6 : 1 }}
                >
                  {isSubmitting ? "Recording Ombudsman Decision..." : firstReview ? "Submit Secondary Sign-off (Finalize Quorum)" : "Submit Initial Ombudsman Review"}
                </button>
              </form>
            )}

            {/* Cryptographic SHA-256 Audit Proof Section */}
            <div style={{ background: "rgba(255, 255, 255, 0.02)", border: "1px solid var(--border)", borderRadius: "10px", padding: "18px" }}>
              <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: "12px" }}>
                <div>
                  <h4 style={{ color: "#fff", fontSize: "14px", margin: 0, display: "flex", alignItems: "center", gap: "6px" }}>
                    <span>🔗</span> Cryptographic SHA-256 Governance Audit Chain
                  </h4>
                  <div style={{ fontSize: "11px", color: "var(--text-secondary)", marginTop: "2px" }}>
                    Tamper-evident hash chain preventing back-room censorship or retroactive alterations
                  </div>
                </div>

                <button
                  type="button"
                  onClick={handleVerifyChain}
                  disabled={isVerifyingChain}
                  className="btn-secondary"
                  style={{ padding: "6px 12px", fontSize: "12px", borderRadius: "6px", cursor: isVerifyingChain ? "wait" : "pointer" }}
                >
                  {isVerifyingChain ? "Verifying SHA-256 Hashes..." : "Verify Chain Integrity"}
                </button>
              </div>

              {/* Chain Verification Result */}
              {chainVerifyResult && (
                <div style={{ padding: "10px 14px", borderRadius: "8px", marginBottom: "14px", fontSize: "13px", background: chainVerifyResult.isValid ? "rgba(16, 185, 129, 0.1)" : "rgba(239, 68, 68, 0.1)", border: chainVerifyResult.isValid ? "1px solid #10b981" : "1px solid #ef4444", color: chainVerifyResult.isValid ? "#34d399" : "#f87171" }}>
                  {chainVerifyResult.isValid ? (
                    <div>
                      <strong>✅ Cryptographically Intact:</strong> {chainVerifyResult.verifiedCount} chained audit blocks verified with zero hash discrepancies. Genesis seed linked.
                    </div>
                  ) : (
                    <div>
                      <strong>❌ Cryptographic Chain Broken!</strong> Discrepancy detected at block: <code>{chainVerifyResult.brokenAtLogId}</code>. {chainVerifyResult.error}
                    </div>
                  )}
                </div>
              )}

              {/* Audit Log Entries List */}
              {auditLogs.length === 0 ? (
                <div style={{ fontSize: "12px", color: "var(--text-muted)", fontStyle: "italic", textAlign: "center", padding: "12px" }}>
                  No audit logs recorded for this video target yet.
                </div>
              ) : (
                <div style={{ display: "flex", flexDirection: "column", gap: "8px", maxHeight: "250px", overflowY: "auto" }}>
                  {auditLogs.map((log) => (
                    <div key={log.id} style={{ background: "rgba(0,0,0,0.3)", borderRadius: "6px", padding: "10px 12px", fontSize: "12px", border: "1px solid rgba(255,255,255,0.05)" }}>
                      <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center" }}>
                        <span style={{ fontWeight: "600", color: "#38bdf8" }}>{log.action}</span>
                        <span style={{ fontSize: "11px", color: "var(--text-muted)" }}>{formatDate(log.timestamp)}</span>
                      </div>
                      <div style={{ color: "#d1d5db", marginTop: "4px" }}>
                        <strong>Rationale:</strong> "{log.rationale}"
                      </div>
                      <div style={{ display: "flex", gap: "10px", marginTop: "6px", fontSize: "10px", color: "var(--text-muted)", fontFamily: "monospace" }}>
                        <span>Hash: {log.entryHash ? `${log.entryHash.substring(0, 16)}...` : "N/A"}</span>
                        <span>•</span>
                        <span>Prev: {log.previousHash ? `${log.previousHash.substring(0, 16)}...` : "GENESIS"}</span>
                        <span>•</span>
                        <span>Performer: {log.performerId?.substring(0, 10)}...</span>
                      </div>
                    </div>
                  ))}
                </div>
              )}
            </div>
          </div>
        )}
      </div>
    </div>
  );
}

import React, { useState, useEffect } from "react";
import { 
  signInWithEmailAndPassword, 
  signOut, 
  onAuthStateChanged 
} from "firebase/auth";
import { 
  collection, 
  query, 
  orderBy, 
  limit, 
  onSnapshot,
  where 
} from "firebase/firestore";
import { auth, db } from "./firebase";

function App() {
  const [user, setUser] = useState(null);
  const [isAdmin, setIsAdmin] = useState(false);
  const [authChecking, setAuthChecking] = useState(true);
  const [loginEmail, setLoginEmail] = useState("");
  const [loginPassword, setLoginPassword] = useState("");
  const [error, setError] = useState("");
  const [isLoggingIn, setIsLoggingIn] = useState(false);

  // Tab State
  const [currentTab, setCurrentTab] = useState("dashboard");

  // Real-time Data States
  const [videos, setVideos] = useState([]);
  const [images, setImages] = useState([]);
  const [auditLogs, setAuditLogs] = useState([]);
  const [reports, setReports] = useState([]);
  const [systemStats, setSystemStats] = useState({
    pendingVideos: 0,
    pendingImages: 0,
    totalVideos: 0,
    totalImages: 0,
  });

  // Selection / Modal States
  const [selectedItem, setSelectedItem] = useState(null);
  const [isModalOpen, setIsModalOpen] = useState(false);
  const [modalAction, setModalAction] = useState(""); // 'approve' or 'reject'
  const [reasonText, setReasonText] = useState("");
  const [isSubmitting, setIsSubmitting] = useState(false);

  // Auth Listener
  useEffect(() => {
    const unsubscribe = onAuthStateChanged(auth, async (currentUser) => {
      if (currentUser) {
        try {
          // Force refresh token to pull latest custom claims
          const idTokenResult = await currentUser.getIdTokenResult(true);
          if (idTokenResult.claims.admin === true) {
            setUser(currentUser);
            setIsAdmin(true);
            setError("");
          } else {
            setError("Access Denied: Your account does not have admin privileges.");
            await signOut(auth);
            setUser(null);
            setIsAdmin(false);
          }
        } catch (err) {
          console.error("Auth claim validation failed:", err);
          setError("Authentication error. Please try again.");
          setUser(null);
          setIsAdmin(false);
        }
      } else {
        setUser(null);
        setIsAdmin(false);
      }
      setAuthChecking(false);
    });

    return () => unsubscribe();
  }, []);

  // Real-time Firestore Listeners (only run when admin is logged in)
  useEffect(() => {
    if (!user || !isAdmin) return;

    // 1. Listen to Videos
    const videosQuery = query(
      collection(db, "videos"),
      orderBy("createdAt", "desc"),
      limit(100)
    );
    const unsubVideos = onSnapshot(videosQuery, (snapshot) => {
      const videoList = snapshot.docs.map(doc => ({
        id: doc.id,
        ...doc.data()
      }));
      setVideos(videoList);

      // Compute stats
      const pendingCount = videoList.filter(
        v => v.moderation?.status === "processing" || v.moderation?.status === "error" || 
             (v.moderation?.status === "approved" && v.moderation?.violationCategories?.includes("timeout_passthrough"))
      ).length;
      
      setSystemStats(prev => ({
        ...prev,
        pendingVideos: pendingCount,
        totalVideos: videoList.length
      }));
    }, (err) => {
      console.error("Videos subscription failed:", err);
    });

    // 2. Listen to Flagged Images
    const imagesQuery = query(
      collection(db, "flagged_images_review"),
      orderBy("flaggedAt", "desc"),
      limit(100)
    );
    const unsubImages = onSnapshot(imagesQuery, (snapshot) => {
      const imageList = snapshot.docs.map(doc => ({
        id: doc.id,
        ...doc.data()
      }));
      setImages(imageList);

      const pendingCount = imageList.filter(img => img.status === "PENDING_REVIEW").length;

      setSystemStats(prev => ({
        ...prev,
        pendingImages: pendingCount,
        totalImages: imageList.length
      }));
    }, (err) => {
      console.error("Flagged images subscription failed:", err);
    });

    // 3. Listen to Rejection logs
    const logsQuery = query(
      collection(db, "rejected_images_log"),
      orderBy("rejectedAt", "desc"),
      limit(50)
    );
    const unsubLogs = onSnapshot(logsQuery, (snapshot) => {
      const logsList = snapshot.docs.map(doc => ({
        id: doc.id,
        ...doc.data()
      }));
      setAuditLogs(logsList);
    }, (err) => {
      console.error("Logs subscription failed:", err);
    });

    return () => {
      unsubVideos();
      unsubImages();
      unsubLogs();
    };
  }, [user, isAdmin]);

  // Handle Login
  const handleLogin = async (e) => {
    e.preventDefault();
    if (!loginEmail.trim() || !loginPassword.trim()) {
      setError("Please fill in both fields.");
      return;
    }
    setError("");
    setIsLoggingIn(true);
    try {
      await signInWithEmailAndPassword(auth, loginEmail, loginPassword);
    } catch (err) {
      console.error("Login failed:", err);
      setError("Invalid credentials or authentication failed.");
      setIsLoggingIn(false);
    }
  };

  // Handle Sign Out
  const handleSignOut = async () => {
    try {
      await signOut(auth);
      setSelectedItem(null);
    } catch (err) {
      console.error("Signout failed:", err);
    }
  };

  // Open confirmation modal for approval/rejection
  const openConfirmModal = (action) => {
    setModalAction(action);
    setReasonText("");
    setIsModalOpen(true);
  };

  // Submit Moderation Action
  const submitModeration = async () => {
    if (!selectedItem) return;
    setIsSubmitting(true);
    setError("");

    try {
      const token = await auth.currentUser.getIdToken();
      const isVideo = selectedItem.videoUrl !== undefined;
      const endpoint = isVideo 
        ? "moderateVideoManual" 
        : "moderateImageManual";
      
      const payload = isVideo 
        ? { videoId: selectedItem.id, action: modalAction, reason: reasonText }
        : { verificationId: selectedItem.id, action: modalAction, reason: reasonText };

      const response = await fetch(
        `https://asia-south1-truthworld-1.cloudfunctions.net/${endpoint}`,
        {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            "Authorization": `Bearer ${token}`
          },
          body: JSON.stringify(payload)
        }
      );

      const result = await response.json();

      if (!response.ok) {
        throw new Error(result.error || "Failed to process moderation request.");
      }

      // Success
      setIsModalOpen(false);
      setSelectedItem(null);
      setReasonText("");
    } catch (err) {
      console.error("Moderation submission failed:", err);
      setError(err instanceof Error ? err.message : "Error executing moderation.");
    } finally {
      setIsSubmitting(false);
    }
  };

  if (authChecking) {
    return (
      <div className="auth-wrapper">
        <div className="auth-card glass">
          <div className="spinner"></div>
          <p style={{ marginTop: "16px", color: "var(--text-secondary)" }}>Verifying credentials...</p>
        </div>
      </div>
    );
  }

  // Not Logged In Screen
  if (!user || !isAdmin) {
    return (
      <div className="auth-wrapper">
        <div className="auth-card glass">
          <div className="auth-header">
            <h1 className="gradient-text">TruthWorld</h1>
            <p>Admin Moderation Portal</p>
          </div>
          <form className="auth-form" onSubmit={handleLogin}>
            <div className="form-group">
              <label>Email Address</label>
              <input 
                type="email" 
                placeholder="admin@truthworld.com" 
                value={loginEmail}
                onChange={(e) => setLoginEmail(e.target.value)}
                disabled={isLoggingIn}
                required
              />
            </div>
            <div className="form-group">
              <label>Password</label>
              <input 
                type="password" 
                placeholder="••••••••" 
                value={loginPassword}
                onChange={(e) => setLoginPassword(e.target.value)}
                disabled={isLoggingIn}
                required
              />
            </div>
            {error && <div className="error-banner">{error}</div>}
            <button 
              type="submit" 
              className="btn-primary" 
              disabled={isLoggingIn}
            >
              {isLoggingIn ? "Authenticating..." : "Sign In to Console"}
            </button>
          </form>
        </div>
      </div>
    );
  }

  // Helper to format date
  const formatDate = (val) => {
    if (!val) return "N/A";
    const d = val.toMillis ? new Date(val.toMillis()) : new Date(val);
    return d.toLocaleString();
  };

  return (
    <div className="app-container">
      {/* Sidebar */}
      <aside className="sidebar">
        <div className="logo-section">
          <h2 className="gradient-text">TruthWorld</h2>
          <p>Moderation Center</p>
        </div>
        <nav style={{ flex: 1 }}>
          <ul className="nav-links">
            <li>
              <button 
                className={`nav-item ${currentTab === "dashboard" ? "active" : ""}`}
                onClick={() => { setCurrentTab("dashboard"); setSelectedItem(null); }}
              >
                Dashboard
              </button>
            </li>
            <li>
              <button 
                className={`nav-item ${currentTab === "videos" ? "active" : ""}`}
                onClick={() => { setCurrentTab("videos"); setSelectedItem(null); }}
              >
                Video Queue ({systemStats.pendingVideos})
              </button>
            </li>
            <li>
              <button 
                className={`nav-item ${currentTab === "images" ? "active" : ""}`}
                onClick={() => { setCurrentTab("images"); setSelectedItem(null); }}
              >
                Image Queue ({systemStats.pendingImages})
              </button>
            </li>
            <li>
              <button 
                className={`nav-item ${currentTab === "logs" ? "active" : ""}`}
                onClick={() => { setCurrentTab("logs"); setSelectedItem(null); }}
              >
                Audit History Logs
              </button>
            </li>
          </ul>
        </nav>
        <div className="sidebar-footer">
          <div className="admin-profile">
            <div className="admin-name">{user.email}</div>
            <div className="admin-role">System Administrator</div>
          </div>
          <button className="btn-signout" onClick={handleSignOut}>
            Sign Out
          </button>
        </div>
      </aside>

      {/* Main Panel */}
      <main className="main-content">
        <header className="top-bar">
          <div className="page-title">
            <h1>
              {currentTab === "dashboard" && "Dashboard Overview"}
              {currentTab === "videos" && "Video Verification Queue"}
              {currentTab === "images" && "Image Moderation Grid"}
              {currentTab === "logs" && "Audit Logs & Actions Log"}
            </h1>
            <p>
              {currentTab === "dashboard" && "Real-time moderation metrics and statistics."}
              {currentTab === "videos" && "Review videos flagged or timed-out during automatic scanning."}
              {currentTab === "images" && "Inspect flagged thumbnails, avatars, and posts."}
              {currentTab === "logs" && "History of manual actions and quarantined resources."}
            </p>
          </div>
        </header>

        <div className="content-body">
          {error && <div className="error-banner" style={{ marginBottom: "20px" }}>{error}</div>}

          {/* TAB 1: DASHBOARD */}
          {currentTab === "dashboard" && (
            <div>
              <div className="stats-grid">
                <div className="stat-card glass video">
                  <div className="stat-label">Pending Video Reviews</div>
                  <div className="stat-value">{systemStats.pendingVideos}</div>
                  <div className="stat-sub">Videos requiring manual decision</div>
                </div>
                <div className="stat-card glass image">
                  <div className="stat-label">Pending Image Reviews</div>
                  <div className="stat-value">{systemStats.pendingImages}</div>
                  <div className="stat-sub">Flagged images in review queue</div>
                </div>
                <div className="stat-card glass resolved">
                  <div className="stat-label">Total Logs Ingested</div>
                  <div className="stat-value">{auditLogs.length}</div>
                  <div className="stat-sub">Recent quarantined images recorded</div>
                </div>
                <div className="stat-card glass errors">
                  <div className="stat-label">System State</div>
                  <div className="stat-value" style={{ color: "var(--color-success)" }}>Healthy</div>
                  <div className="stat-sub">AI pipelines functioning normally</div>
                </div>
              </div>

              <div className="glass" style={{ padding: "24px", borderRadius: "16px" }}>
                <h3 style={{ marginBottom: "16px", fontFamily: "var(--font-display)" }}>Recent System Activity</h3>
                <div className="audit-table-wrapper">
                  <table className="audit-table">
                    <thead>
                      <tr>
                        <th>Resource ID</th>
                        <th>Type</th>
                        <th>Status</th>
                        <th>Reason</th>
                        <th>Timestamp</th>
                      </tr>
                    </thead>
                    <tbody>
                      {videos.slice(0, 5).map(v => (
                        <tr key={v.id}>
                          <td>{v.id}</td>
                          <td><span className="badge" style={{ background: "rgba(139, 92, 246, 0.1)", color: "var(--accent-purple)" }}>Video</span></td>
                          <td>
                            <span className={`badge ${v.moderation?.status || "pending"}`}>
                              {v.moderation?.status || "pending"}
                            </span>
                          </td>
                          <td>{v.moderation?.reason || "Awaiting moderation trigger"}</td>
                          <td>{formatDate(v.createdAt)}</td>
                        </tr>
                      ))}
                      {images.slice(0, 5).map(img => (
                        <tr key={img.id}>
                          <td>{img.fileName}</td>
                          <td><span className="badge" style={{ background: "rgba(6, 182, 212, 0.1)", color: "var(--accent-cyan)" }}>Image</span></td>
                          <td>
                            <span className={`badge ${img.status?.toLowerCase() || "pending"}`}>
                              {img.status}
                            </span>
                          </td>
                          <td>{img.reason}</td>
                          <td>{formatDate(img.flaggedAt)}</td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
              </div>
            </div>
          )}

          {/* TAB 2: VIDEOS QUEUE */}
          {currentTab === "videos" && (
            <div className={`queue-layout ${selectedItem ? "split" : ""}`}>
              {/* List */}
              <div className="list-pane">
                {videos.filter(v => v.moderation?.status === "processing" || v.moderation?.status === "error" || 
                  (v.moderation?.status === "approved" && v.moderation?.violationCategories?.includes("timeout_passthrough")) || 
                  v.moderation?.status === "rejected" || v.moderation?.status === "pending"
                ).length === 0 ? (
                  <div className="empty-state glass">
                    <p>No videos in the moderation queue.</p>
                  </div>
                ) : (
                  videos.filter(v => v.moderation?.status === "processing" || v.moderation?.status === "error" || 
                    (v.moderation?.status === "approved" && v.moderation?.violationCategories?.includes("timeout_passthrough")) || 
                    v.moderation?.status === "rejected" || v.moderation?.status === "pending"
                  ).map(v => (
                    <div 
                      key={v.id} 
                      className={`item-card glass ${selectedItem?.id === v.id ? "selected" : ""}`}
                      onClick={() => setSelectedItem(v)}
                    >
                      <div className="item-thumb">
                        {v.thumbnailUrl ? <img src={v.thumbnailUrl} alt="Thumbnail" /> : <div style={{ fontSize: "2rem" }}>🎥</div>}
                      </div>
                      <div className="item-info">
                        <div className="item-title">{v.title || "Untitled Video"}</div>
                        <div className="item-meta">
                          <span>User ID: {v.userId || v.ownerId || "Unknown"}</span>
                          <span>•</span>
                          <span>{formatDate(v.createdAt)}</span>
                        </div>
                        <div style={{ display: "flex", gap: "8px", marginTop: "4px" }}>
                          <span className={`badge ${v.moderation?.status || "pending"}`}>
                            {v.moderation?.status || "PENDING"}
                          </span>
                          {v.moderation?.violationCategories?.includes("timeout_passthrough") && (
                            <span className="badge priority-high">TIMEOUT</span>
                          )}
                        </div>
                      </div>
                    </div>
                  ))
                )}
              </div>

              {/* Detail Pane */}
              {selectedItem && (
                <div className="detail-pane glass">
                  <h3 style={{ fontFamily: "var(--font-display)" }}>Inspect Video</h3>
                  
                  <div className="media-preview-container">
                    <video src={selectedItem.videoUrl} controls />
                  </div>

                  <div>
                    <h4 style={{ color: "var(--text-secondary)", marginBottom: "8px" }}>Metadata Information</h4>
                    <table className="metadata-table">
                      <tbody>
                        <tr>
                          <td className="label">Video ID</td>
                          <td className="value">{selectedItem.id}</td>
                        </tr>
                        <tr>
                          <td className="label">Title</td>
                          <td className="value">{selectedItem.title || "Untitled"}</td>
                        </tr>
                        <tr>
                          <td className="label">Description</td>
                          <td className="value">{selectedItem.description || "No description provided."}</td>
                        </tr>
                        <tr>
                          <td className="label">Moderation Status</td>
                          <td className="value">
                            <span className={`badge ${selectedItem.moderation?.status || "pending"}`}>
                              {selectedItem.moderation?.status?.toUpperCase() || "PENDING"}
                            </span>
                          </td>
                        </tr>
                        <tr>
                          <td className="label">Trigger Reason</td>
                          <td className="value">{selectedItem.moderation?.reason || "System pipeline log."}</td>
                        </tr>
                        <tr>
                          <td className="label">Confidence Score</td>
                          <td className="value">{selectedItem.moderation?.confidenceScore ?? "N/A"}</td>
                        </tr>
                        <tr>
                          <td className="label">GCS Path</td>
                          <td className="value">{selectedItem.storage?.videoPath || "N/A"}</td>
                        </tr>
                      </tbody>
                    </table>
                  </div>

                  <div className="action-bar">
                    <button className="btn-approve" onClick={() => openConfirmModal("approve")}>
                      Approve Video
                    </button>
                    <button className="btn-reject" onClick={() => openConfirmModal("reject")}>
                      Reject Video
                    </button>
                  </div>
                </div>
              )}
            </div>
          )}

          {/* TAB 3: IMAGES QUEUE */}
          {currentTab === "images" && (
            <div className={`queue-layout ${selectedItem ? "split" : ""}`}>
              {/* Grid List */}
              <div className="list-pane">
                {images.length === 0 ? (
                  <div className="empty-state glass">
                    <p>No images in the moderation queue.</p>
                  </div>
                ) : (
                  <div className="image-grid">
                    {images.map(img => (
                      <div 
                        key={img.id} 
                        className={`grid-item-card glass ${selectedItem?.id === img.id ? "selected" : ""}`}
                        onClick={() => setSelectedItem(img)}
                      >
                        <div className="grid-item-image">
                          <img src={img.gcsUri?.replace("gs://", "https://storage.googleapis.com/").replace("truthworld-1.firebasestorage.app/", "truthworld-1.firebasestorage.app/") || img.filePath} alt="Flagged" />
                        </div>
                        <div className="grid-item-meta">
                          <div className="grid-item-title">{img.fileName}</div>
                          <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginTop: "4px" }}>
                            <span className="badge priority-medium">{img.category || "image"}</span>
                            <span className={`badge ${img.status?.toLowerCase()}`}>{img.status}</span>
                          </div>
                        </div>
                      </div>
                    ))}
                  </div>
                )}
              </div>

              {/* Detail Pane */}
              {selectedItem && (
                <div className="detail-pane glass">
                  <h3 style={{ fontFamily: "var(--font-display)" }}>Inspect Image</h3>

                  <div className="media-preview-container" style={{ aspectRation: "1" }}>
                    <img src={selectedItem.gcsUri?.replace("gs://", "https://storage.googleapis.com/").replace("truthworld-1.firebasestorage.app/", "truthworld-1.firebasestorage.app/") || selectedItem.filePath} alt="Inspection" />
                  </div>

                  <div>
                    <h4 style={{ color: "var(--text-secondary)", marginBottom: "12px" }}>SafeSearch Criteria Violations</h4>
                    <div className="scores-grid">
                      <div className="score-badge">
                        <span className="score-name">Adult</span>
                        <span className={`score-value val-${selectedItem.detailedScores?.adult || 0}`}>
                          {selectedItem.detailedScores?.adult ?? 0}
                        </span>
                      </div>
                      <div className="score-badge">
                        <span className="score-name">Racy</span>
                        <span className={`score-value val-${selectedItem.detailedScores?.racy || 0}`}>
                          {selectedItem.detailedScores?.racy ?? 0}
                        </span>
                      </div>
                      <div className="score-badge">
                        <span className="score-name">Violence</span>
                        <span className={`score-value val-${selectedItem.detailedScores?.violence || 0}`}>
                          {selectedItem.detailedScores?.violence ?? 0}
                        </span>
                      </div>
                      <div className="score-badge">
                        <span className="score-name">Medical</span>
                        <span className={`score-value val-${selectedItem.detailedScores?.medical || 0}`}>
                          {selectedItem.detailedScores?.medical ?? 0}
                        </span>
                      </div>
                      <div className="score-badge">
                        <span className="score-name">Spoof</span>
                        <span className={`score-value val-${selectedItem.detailedScores?.spoof || 0}`}>
                          {selectedItem.detailedScores?.spoof ?? 0}
                        </span>
                      </div>
                    </div>
                  </div>

                  <div>
                    <h4 style={{ color: "var(--text-secondary)", marginBottom: "8px" }}>Metadata Information</h4>
                    <table className="metadata-table">
                      <tbody>
                        <tr>
                          <td className="label">Document ID</td>
                          <td className="value">{selectedItem.id}</td>
                        </tr>
                        <tr>
                          <td className="label">File Name</td>
                          <td className="value">{selectedItem.fileName}</td>
                        </tr>
                        <tr>
                          <td className="label">Uploader ID</td>
                          <td className="value">{selectedItem.userId || "Anonymous"}</td>
                        </tr>
                        <tr>
                          <td className="label">Reason Flagged</td>
                          <td className="value">{selectedItem.reason}</td>
                        </tr>
                        <tr>
                          <td className="label">Severity Score</td>
                          <td className="value">{selectedItem.score} / 5</td>
                        </tr>
                        <tr>
                          <td className="label">GCS Storage URL</td>
                          <td className="value">{selectedItem.filePath}</td>
                        </tr>
                      </tbody>
                    </table>
                  </div>

                  {selectedItem.status === "PENDING_REVIEW" && (
                    <div className="action-bar">
                      <button className="btn-approve" onClick={() => openConfirmModal("approve")}>
                        Approve Image
                      </button>
                      <button className="btn-reject" onClick={() => openConfirmModal("reject")}>
                        Reject Image
                      </button>
                    </div>
                  )}
                </div>
              )}
            </div>
          )}

          {/* TAB 4: AUDIT LOGS */}
          {currentTab === "logs" && (
            <div className="glass" style={{ padding: "24px", borderRadius: "16px" }}>
              <h3 style={{ marginBottom: "16px", fontFamily: "var(--font-display)" }}>Quarantined Resources History</h3>
              <div className="audit-table-wrapper">
                <table className="audit-table">
                  <thead>
                    <tr>
                      <th>Original Location</th>
                      <th>Quarantine Path</th>
                      <th>Reason Code</th>
                      <th>Owner ID</th>
                      <th>Rejection Date</th>
                    </tr>
                  </thead>
                  <tbody>
                    {auditLogs.length === 0 ? (
                      <tr>
                        <td colSpan="5" style={{ textPosition: "center", color: "var(--text-muted)", padding: "40px" }}>
                          No manual rejection logs recorded.
                        </td>
                      </tr>
                    ) : (
                      auditLogs.map(log => (
                        <tr key={log.id}>
                          <td>{log.originalPath}</td>
                          <td><span style={{ fontSize: "0.85rem", color: "var(--accent-purple)", fontFamily: "monospace" }}>{log.quarantinePath}</span></td>
                          <td>{log.reason}</td>
                          <td>{log.userId || "N/A"}</td>
                          <td>{formatDate(log.rejectedAt)}</td>
                        </tr>
                      ))
                    )}
                  </tbody>
                </table>
              </div>
            </div>
          )}
        </div>
      </main>

      {/* Confirmation Modal */}
      {isModalOpen && (
        <div className="modal-overlay">
          <div className="modal-content glass">
            <div className="modal-header">
              Confirm Manual {modalAction === "approve" ? "Approval" : "Rejection"}
            </div>
            <div className="modal-body">
              <p style={{ color: "var(--text-secondary)", fontSize: "0.95rem", lineHeight: "1.5" }}>
                Are you sure you want to manually <strong>{modalAction}</strong> this resource? 
                {modalAction === "reject" && " This will permanently quarantine files in storage and update user trust scores negatively."}
              </p>
              
              <div className="form-group" style={{ marginTop: "16px" }}>
                <label>Review Notes / Reason (Optional)</label>
                <textarea 
                  className="reason-textarea"
                  placeholder="Provide details about the decision for audit tracking..."
                  value={reasonText}
                  onChange={(e) => setReasonText(e.target.value)}
                />
              </div>
            </div>
            <div className="modal-actions">
              <button 
                className="btn-cancel"
                onClick={() => setIsModalOpen(false)}
                disabled={isSubmitting}
              >
                Cancel
              </button>
              <button 
                className={modalAction === "approve" ? "btn-approve" : "btn-reject"}
                onClick={submitModeration}
                disabled={isSubmitting}
              >
                {isSubmitting ? "Processing..." : `Confirm ${modalAction}`}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}

export default App;

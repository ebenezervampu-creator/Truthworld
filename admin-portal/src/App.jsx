import React, { useState, useEffect } from "react";
import { 
  GoogleAuthProvider,
  signInWithPopup, 
  signInWithRedirect,
  signInWithEmailAndPassword,
  getRedirectResult,
  signOut, 
  onAuthStateChanged 
} from "firebase/auth";
import { 
  collection, 
  doc,
  query, 
  orderBy, 
  limit, 
  onSnapshot,
  setDoc,
  updateDoc
} from "firebase/firestore";
import { auth, db } from "./firebase";

const OWNER_EMAIL = "ebenezervampu4@gmail.com";

const getFastDownloadUrl = (pathOrGsUrl) => {
  if (!pathOrGsUrl) return "";
  if (pathOrGsUrl.startsWith("http://") || pathOrGsUrl.startsWith("https://")) {
    if (pathOrGsUrl.includes("firebasestorage.googleapis.com") && !pathOrGsUrl.includes("alt=media")) {
      return pathOrGsUrl.includes("?") ? `${pathOrGsUrl}&alt=media` : `${pathOrGsUrl}?alt=media`;
    }
    return pathOrGsUrl;
  }
  const bucket = "truthworld-1.firebasestorage.app";
  let path = pathOrGsUrl.startsWith("gs://")
    ? pathOrGsUrl.replace(`gs://${bucket}/`, "").replace("gs://", "")
    : pathOrGsUrl;
  if (path.startsWith("/")) path = path.substring(1);
  const encodedPath = encodeURIComponent(path);
  return `https://firebasestorage.googleapis.com/v0/b/${bucket}/o/${encodedPath}?alt=media`;
};

function App() {
  const [user, setUser] = useState(null);
  const [isAdmin, setIsAdmin] = useState(false);
  const [authChecking, setAuthChecking] = useState(true);
  const [loginEmail, setLoginEmail] = useState("");
  const [loginPassword, setLoginPassword] = useState("");
  const [error, setError] = useState("");
  const [successMsg, setSuccessMsg] = useState("");
  const [isLoggingIn, setIsLoggingIn] = useState(false);

  // Tab State
  const [currentTab, setCurrentTab] = useState("dashboard");

  // Moderation Modes State (ON = Send to Admin Only / Bypass Gemini; OFF = Send to Gemini AI)
  const [moderationModes, setModerationModes] = useState({
    videos: false,       // Video content
    thumbnails: false,   // Video thumbnails
    channels: false,     // Channel details (name, desc, tags)
    avatar: false,       // Channel avatar
    banner: false,       // Channel banner
    topics: false,       // Topics
  });
  const [modeUpdatingKey, setModeUpdatingKey] = useState(null);

  // Real-time Data States
  const [videos, setVideos] = useState([]);
  const [images, setImages] = useState([]);
  const [channels, setChannels] = useState([]);
  const [topics, setTopics] = useState([]);
  const [auditLogs, setAuditLogs] = useState([]);
  const [reports, setReports] = useState([]);

  // Queue filter states
  const [videoFilter, setVideoFilter] = useState("pending");
  const [channelFilter, setChannelFilter] = useState("pending");
  const [topicFilter, setTopicFilter] = useState("pending");
  const [imageFilter, setImageFilter] = useState("pending");

  const [systemStats, setSystemStats] = useState({
    pendingVideos: 0,
    pendingImages: 0,
    pendingChannels: 0,
    pendingTopics: 0,
    pendingReports: 0,
    totalVideos: 0,
    totalImages: 0,
    totalChannels: 0,
    totalTopics: 0,
    totalReports: 0,
  });

  // Selection / Modal States
  const [selectedItem, setSelectedItem] = useState(null);
  const [selectedType, setSelectedType] = useState(null); // 'video' | 'image' | 'channel' | 'topic'
  const [isModalOpen, setIsModalOpen] = useState(false);
  const [modalAction, setModalAction] = useState(""); // 'approve' or 'reject'
  const [reasonText, setReasonText] = useState("");
  const [isSubmitting, setIsSubmitting] = useState(false);

  // Auth Listener
  useEffect(() => {
    getRedirectResult(auth).catch((err) => {
      console.warn("Redirect result handled/failed:", err);
    });

    const unsubscribe = onAuthStateChanged(auth, async (currentUser) => {
      if (currentUser) {
        try {
          const idTokenResult = await currentUser.getIdTokenResult(true);
          const isOwner = currentUser.email?.toLowerCase() === OWNER_EMAIL.toLowerCase();

          if (idTokenResult.claims.admin === true || isOwner) {
            setUser(currentUser);
            setIsAdmin(true);
            setError("");
          } else {
            setError(`Access Denied: Account (${currentUser.email}) does not have admin privileges.`);
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

    // 1. Listen to Moderation Modes configuration in real-time
    const modesDocRef = doc(db, "admin_settings", "moderation_modes");
    const unsubModes = onSnapshot(modesDocRef, (docSnap) => {
      if (docSnap.exists()) {
        const data = docSnap.data();
        setModerationModes({
          videos: data.videos === true,
          thumbnails: data.thumbnails === true || data.videos_thumbnails === true,
          channels: data.channels === true || data.channelDetails === true,
          avatar: data.avatar === true || data.channelAvatar === true,
          banner: data.banner === true || data.channelBanner === true,
          topics: data.topics === true,
        });
      }
    }, (err) => {
      console.warn("Moderation modes listener warning:", err);
    });

    // 2. Listen to Videos
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

      const isVideoPending = (v) => {
        const modStatus = (v.moderation?.status || v.status || '').toLowerCase();
        if (v.moderation?.violationCategories?.includes("timeout_passthrough")) return true;
        if (!modStatus) return v.isApproved === false;
        return ["pending", "processing", "error", "under_review", "underreview", "in_review", "pending_review", "manual_review", "flagged", "uploading", "unverified"].includes(modStatus);
      };
      const pendingCount = videoList.filter(isVideoPending).length;
      
      setSystemStats(prev => ({
        ...prev,
        pendingVideos: pendingCount,
        totalVideos: videoList.length
      }));
    }, (err) => {
      console.error("Videos subscription failed:", err);
    });

    // 3. Listen to Flagged Images
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

      const pendingCount = imageList.filter(img => img.status === "PENDING_REVIEW" || img.status === "FLAGGED").length;

      setSystemStats(prev => ({
        ...prev,
        pendingImages: pendingCount,
        totalImages: imageList.length
      }));
    }, (err) => {
      console.error("Flagged images subscription failed:", err);
    });

    // 4. Listen to Channels
    const channelsQuery = query(
      collection(db, "channels"),
      limit(100)
    );
    const unsubChannels = onSnapshot(channelsQuery, (snapshot) => {
      const channelList = snapshot.docs.map(doc => ({
        id: doc.id,
        ...doc.data()
      }));

      channelList.sort((a, b) => {
        const timeA = a.updatedAt || a.createdAt || 0;
        const timeB = b.updatedAt || b.createdAt || 0;
        return (timeB?.toMillis ? timeB.toMillis() : new Date(timeB).getTime()) - 
               (timeA?.toMillis ? timeA.toMillis() : new Date(timeA).getTime());
      });

      setChannels(channelList);

      const isChannelPending = (c) => {
        const status = (c.status || '').toLowerCase();
        return status === "underreview" || status === "under_review" || status === "pending" || c.geminiApproved === false;
      };
      const pendingCount = channelList.filter(isChannelPending).length;

      setSystemStats(prev => ({
        ...prev,
        pendingChannels: pendingCount,
        totalChannels: channelList.length
      }));
    }, (err) => {
      console.error("Channels subscription failed:", err);
    });

    // 5. Listen to Topics
    const topicsQuery = query(
      collection(db, "topics"),
      limit(100)
    );
    const unsubTopics = onSnapshot(topicsQuery, (snapshot) => {
      const topicList = snapshot.docs.map(doc => ({
        id: doc.id,
        ...doc.data()
      }));

      topicList.sort((a, b) => {
        const timeA = a.updatedAt || a.createdAt || 0;
        const timeB = b.updatedAt || b.createdAt || 0;
        return (timeB?.toMillis ? timeB.toMillis() : new Date(timeB).getTime()) - 
               (timeA?.toMillis ? timeA.toMillis() : new Date(timeA).getTime());
      });

      setTopics(topicList);

      const isTopicPending = (t) => {
        const status = (t.status || '').toLowerCase();
        return status === "underreview" || status === "under_review" || status === "pending" || t.geminiApproved === false;
      };
      const pendingCount = topicList.filter(isTopicPending).length;

      setSystemStats(prev => ({
        ...prev,
        pendingTopics: pendingCount,
        totalTopics: topicList.length
      }));
    }, (err) => {
      console.error("Topics subscription failed:", err);
    });

    // 6. Listen to Rejection logs
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

    // 7. Listen to Reports
    const reportsQuery = query(
      collection(db, "reports"),
      limit(100)
    );
    const unsubReports = onSnapshot(reportsQuery, (snapshot) => {
      const reportList = snapshot.docs.map(doc => ({
        id: doc.id,
        ...doc.data()
      }));

      reportList.sort((a, b) => {
        const timeA = a.createdAt || a.timestamp || a.reportedAt;
        const timeB = b.createdAt || b.timestamp || b.reportedAt;
        if (!timeA && !timeB) return 0;
        if (!timeA) return 1;
        if (!timeB) return -1;
        const dtA = timeA?.toDate ? timeA.toDate() : new Date(timeA);
        const dtB = timeB?.toDate ? timeB.toDate() : new Date(timeB);
        return dtB - dtA;
      });

      setReports(reportList);

      const pendingCount = reportList.filter(r => {
        const s = (r.status || 'pending').toLowerCase();
        return s === 'pending' || s === 'under_review' || (r.isResolved !== true && r.resolved !== true && s !== 'resolved' && s !== 'dismissed' && s !== 'resolved_rejected' && s !== 'resolved_dismissed');
      }).length;

      setSystemStats(prev => ({
        ...prev,
        pendingReports: pendingCount,
        totalReports: reportList.length
      }));
    }, (err) => {
      console.error("Reports subscription failed:", err);
    });

    return () => {
      unsubModes();
      unsubVideos();
      unsubImages();
      unsubChannels();
      unsubTopics();
      unsubLogs();
      unsubReports();
    };
  }, [user, isAdmin]);

  // Toggle Moderation Mode (Bypass Gemini AI vs Send to Gemini)
  const handleToggleMode = async (modeKey) => {
    setModeUpdatingKey(modeKey);
    setError("");
    setSuccessMsg("");
    const newValue = !moderationModes[modeKey];
    
    try {
      const updatedModes = {
        ...moderationModes,
        [modeKey]: newValue,
      };

      // Update both admin_settings and system_settings for full sync
      const modesRef = doc(db, "admin_settings", "moderation_modes");
      const fallbackRef = doc(db, "system_settings", "moderation_modes");

      const payload = {
        ...updatedModes,
        updatedAt: Date.now(),
        updatedBy: user?.email || "admin",
      };

      await setDoc(modesRef, payload, { merge: true });
      await setDoc(fallbackRef, payload, { merge: true }).catch(() => {});

      setModerationModes(updatedModes);
      setSuccessMsg(`Mode updated: ${modeKey.toUpperCase()} is now ${newValue ? "ON (Routed to Admin only, Gemini bypassed)" : "OFF (Sending to Gemini AI as normal)"}`);
      setTimeout(() => setSuccessMsg(""), 4500);
    } catch (err) {
      console.error("Failed to toggle mode:", err);
      setError(`Failed to update mode: ${err instanceof Error ? err.message : String(err)}`);
    } finally {
      setModeUpdatingKey(null);
    }
  };

  // Handle Email & Password Login
  const handleEmailLogin = async (e) => {
    e.preventDefault();
    if (!loginEmail.trim() || !loginPassword.trim()) {
      setError("Please enter both email and password.");
      return;
    }
    setError("");
    setIsLoggingIn(true);
    try {
      await signInWithEmailAndPassword(auth, loginEmail.trim(), loginPassword.trim());
    } catch (err) {
      console.error("Email login failed:", err);
      setError(err instanceof Error ? err.message : "Authentication failed.");
      setIsLoggingIn(false);
    }
  };

  // Handle Google Sign-In with Redirect Fallback
  const handleGoogleSignIn = async () => {
    setError("");
    setIsLoggingIn(true);
    try {
      const provider = new GoogleAuthProvider();
      provider.setCustomParameters({ prompt: "select_account" });
      try {
        await signInWithPopup(auth, provider);
      } catch (popupErr) {
        console.warn("Popup blocked or failed, redirecting:", popupErr);
        await signInWithRedirect(auth, provider);
      }
    } catch (err) {
      console.error("Google login failed:", err);
      setError(err instanceof Error ? err.message : "Google Authentication failed.");
      setIsLoggingIn(false);
    }
  };

  // Handle Sign Out
  const handleSignOut = async () => {
    try {
      await signOut(auth);
      setSelectedItem(null);
      setSelectedType(null);
    } catch (err) {
      console.error("Signout failed:", err);
    }
  };

  // Open confirmation modal for approval/rejection
  const openConfirmModal = (action, item, type) => {
    setModalAction(action);
    setSelectedItem(item);
    setSelectedType(type);
    setReasonText("");
    setIsModalOpen(true);
  };

  // Submit Moderation Action (Videos, Images, Channels, Topics)
  const submitModeration = async () => {
    if (!selectedItem || !selectedType) return;
    setIsSubmitting(true);
    setError("");

    try {
      const token = await auth.currentUser.getIdToken();

      if (selectedType === "video") {
        const response = await fetch(
          `https://asia-south1-truthworld-1.cloudfunctions.net/moderateVideoManual`,
          {
            method: "POST",
            headers: {
              "Content-Type": "application/json",
              "Authorization": `Bearer ${token}`
            },
            body: JSON.stringify({
              videoId: selectedItem.id,
              action: modalAction,
              reason: reasonText || `Manual ${modalAction} by Admin.`
            })
          }
        );
        const result = await response.json();
        if (!response.ok) throw new Error(result.error || "Failed to process video moderation.");

      } else if (selectedType === "image") {
        const response = await fetch(
          `https://asia-south1-truthworld-1.cloudfunctions.net/moderateImageManual`,
          {
            method: "POST",
            headers: {
              "Content-Type": "application/json",
              "Authorization": `Bearer ${token}`
            },
            body: JSON.stringify({
              verificationId: selectedItem.id,
              action: modalAction,
              reason: reasonText || `Manual ${modalAction} by Admin.`
            })
          }
        );
        const result = await response.json();
        if (!response.ok) throw new Error(result.error || "Failed to process image moderation.");

      } else if (selectedType === "channel") {
        const response = await fetch(
          `https://asia-south1-truthworld-1.cloudfunctions.net/moderateChannelManual`,
          {
            method: "POST",
            headers: {
              "Content-Type": "application/json",
              "Authorization": `Bearer ${token}`
            },
            body: JSON.stringify({
              channelId: selectedItem.id,
              action: modalAction,
              reason: reasonText || `Manual ${modalAction} by Admin.`
            })
          }
        );
        if (!response.ok) {
          // Direct fallback to Firestore update if function endpoint warming up
          const channelRef = doc(db, "channels", selectedItem.id);
          const approved = modalAction === "approve";
          await updateDoc(channelRef, {
            geminiApproved: approved,
            status: approved ? "active" : "verificationRejected",
            moderationReason: reasonText || `Manual ${modalAction} by Admin.`,
            manuallyVerified: true,
            verifiedBy: user.uid,
            updatedAt: Date.now(),
          });
        }

      } else if (selectedType === "topic") {
        const response = await fetch(
          `https://asia-south1-truthworld-1.cloudfunctions.net/moderateTopicManual`,
          {
            method: "POST",
            headers: {
              "Content-Type": "application/json",
              "Authorization": `Bearer ${token}`
            },
            body: JSON.stringify({
              topicId: selectedItem.id,
              action: modalAction,
              reason: reasonText || `Manual ${modalAction} by Admin.`
            })
          }
        );
        if (!response.ok) {
          // Direct fallback to Firestore update
          const topicRef = doc(db, "topics", selectedItem.id);
          const approved = modalAction === "approve";
          await updateDoc(topicRef, {
            geminiApproved: approved,
            status: approved ? "active" : "verificationRejected",
            moderationReason: reasonText || `Manual ${modalAction} by Admin.`,
            manuallyVerified: true,
            verifiedBy: user.uid,
            updatedAt: Date.now(),
          });
        }
      }

      // Success
      setIsModalOpen(false);
      setSelectedItem(null);
      setSelectedType(null);
      setReasonText("");
      setSuccessMsg(`Successfully ${modalAction}d ${selectedType}.`);
      setTimeout(() => setSuccessMsg(""), 4000);
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
            <p>Admin Moderation Console</p>
          </div>
          <div className="auth-form-container">
            <form className="auth-form" onSubmit={handleEmailLogin}>
              <div className="form-group">
                <label>Admin Email</label>
                <input 
                  type="email" 
                  placeholder="ebenezervampu4@gmail.com" 
                  value={loginEmail}
                  onChange={(e) => setLoginEmail(e.target.value)}
                  disabled={isLoggingIn}
                  required
                />
              </div>
              <div className="form-group">
                <label>Admin Password</label>
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
                {isLoggingIn ? "Authenticating..." : "Sign In with Email & Password"}
              </button>
            </form>

            <div className="auth-divider">
              <span>OR</span>
            </div>

            <button 
              type="button" 
              className="btn-google" 
              onClick={handleGoogleSignIn}
              disabled={isLoggingIn}
            >
              <svg className="google-icon" viewBox="0 0 24 24" width="20" height="20">
                <path fill="#ffffff" d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92c-.26 1.37-1.04 2.53-2.21 3.31v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.09z"/>
                <path fill="#ffffff" d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23z"/>
                <path fill="#ffffff" d="M5.84 14.09c-.22-.66-.35-1.36-.35-2.09s.13-1.43.35-2.09V7.06H2.18C1.43 8.55 1 10.22 1 12s.43 3.45 1.18 4.94l2.85-2.22.81-.63z"/>
                <path fill="#ffffff" d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.99 3.47 2.18 7.06l3.66 2.84c.87-2.6 3.3-4.52 6.16-4.52z"/>
              </svg>
              <span>{isLoggingIn ? "Authenticating..." : "Sign in with Google"}</span>
            </button>

            <div className="auth-owner-badge">
              Authorized Owner: <strong>ebenezervampu4@gmail.com</strong>
            </div>
          </div>
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

  // Reusable Mode Toggle Switch Component
  const ModeToggleSwitch = ({ label, sublabel, modeKey, isSmall = false }) => {
    const isBypassed = moderationModes[modeKey] === true;
    const isLoading = modeUpdatingKey === modeKey;

    return (
      <div className={`mode-toggle-card glass ${isBypassed ? "mode-admin-only" : "mode-gemini-ai"} ${isSmall ? "small" : ""}`}>
        <div className="mode-toggle-header">
          <div className="mode-toggle-title">
            <span className="mode-name">{label}</span>
            {sublabel && <span className="mode-sublabel">{sublabel}</span>}
          </div>
          <div className="mode-switch-wrapper">
            <label className="switch">
              <input 
                type="checkbox" 
                checked={isBypassed}
                disabled={isLoading}
                onChange={() => handleToggleMode(modeKey)}
              />
              <span className="slider round"></span>
            </label>
          </div>
        </div>
        <div className="mode-status-indicator">
          {isBypassed ? (
            <span className="badge-mode mode-on">
              <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="#ffffff" strokeWidth="2.5">
                <path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z"/>
              </svg>
              ON: Send to Admin Only (Gemini Bypassed)
            </span>
          ) : (
            <span className="badge-mode mode-off">
              <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="#ffffff" strokeWidth="2">
                <polygon points="13 2 3 14 12 14 11 22 21 10 12 10 13 2"/>
              </svg>
              OFF: Send to Gemini AI Auto
            </span>
          )}
        </div>
      </div>
    );
  };

  // Filtered lists
  const filteredVideos = videos.filter(v => {
    const s = (v.moderation?.status || v.status || '').toLowerCase();
    const isPending = ["pending", "processing", "error", "under_review", "underreview", "in_review", "pending_review", "manual_review", "flagged", "uploading"].includes(s);
    if (videoFilter === "pending") return isPending;
    if (videoFilter === "approved") return s === "approved" || s === "published";
    if (videoFilter === "rejected") return s === "rejected";
    return true;
  });

  const filteredChannels = channels.filter(c => {
    const s = (c.status || '').toLowerCase();
    const isPending = s === "underreview" || s === "under_review" || s === "pending" || c.geminiApproved === false;
    if (channelFilter === "pending") return isPending;
    if (channelFilter === "active") return s === "active" && c.geminiApproved === true;
    if (channelFilter === "rejected") return s === "verificationrejected" || s === "rejected";
    return true;
  });

  const filteredTopics = topics.filter(t => {
    const s = (t.status || '').toLowerCase();
    const isPending = s === "underreview" || s === "under_review" || s === "pending" || t.geminiApproved === false;
    if (topicFilter === "pending") return isPending;
    if (topicFilter === "active") return s === "active" && t.geminiApproved === true;
    if (topicFilter === "rejected") return s === "verificationrejected" || s === "rejected";
    return true;
  });

  const filteredImages = images.filter(img => {
    const s = (img.status || '').toLowerCase();
    if (imageFilter === "pending") return s === "pending_review" || s === "flagged" || s === "pending";
    if (imageFilter === "approved") return s === "approved";
    if (imageFilter === "rejected") return s === "rejected";
    return true;
  });

  return (
    <div className="app-container">
      {/* Sidebar */}
      <aside className="sidebar">
        <div className="logo-section">
          <h2 className="gradient-text">TruthWorld</h2>
          <p>Admin Moderation Portal</p>
        </div>
        <nav style={{ flex: 1 }}>
          <ul className="nav-links">
            <li>
              <button 
                className={`nav-item ${currentTab === "dashboard" ? "active" : ""}`}
                onClick={() => { setCurrentTab("dashboard"); setSelectedItem(null); setSelectedType(null); }}
              >
                <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="#ffffff" strokeWidth="2">
                  <rect x="3" y="3" width="7" height="9"/>
                  <rect x="14" y="3" width="7" height="5"/>
                  <rect x="14" y="12" width="7" height="9"/>
                  <rect x="3" y="16" width="7" height="5"/>
                </svg>
                <span>Dashboard</span>
              </button>
            </li>
            <li>
              <button 
                className={`nav-item ${currentTab === "videos" ? "active" : ""}`}
                onClick={() => { setCurrentTab("videos"); setSelectedItem(null); setSelectedType(null); }}
              >
                <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="#ffffff" strokeWidth="2">
                  <polygon points="23 7 16 12 23 17 23 7"/>
                  <rect x="1" y="5" width="15" height="14" rx="2" ry="2"/>
                </svg>
                <span>Videos ({systemStats.pendingVideos})</span>
              </button>
            </li>
            <li>
              <button 
                className={`nav-item ${currentTab === "channels" ? "active" : ""}`}
                onClick={() => { setCurrentTab("channels"); setSelectedItem(null); setSelectedType(null); }}
              >
                <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="#ffffff" strokeWidth="2">
                  <path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"/>
                  <circle cx="9" cy="7" r="4"/>
                  <path d="M23 21v-2a4 4 0 0 0-3-3.87"/>
                  <path d="M16 3.13a4 4 0 0 1 0 7.75"/>
                </svg>
                <span>Channels ({systemStats.pendingChannels})</span>
              </button>
            </li>
            <li>
              <button 
                className={`nav-item ${currentTab === "topics" ? "active" : ""}`}
                onClick={() => { setCurrentTab("topics"); setSelectedItem(null); setSelectedType(null); }}
              >
                <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="#ffffff" strokeWidth="2">
                  <line x1="4" y1="9" x2="20" y2="9"/>
                  <line x1="4" y1="15" x2="20" y2="15"/>
                  <line x1="10" y1="3" x2="8" y2="21"/>
                  <line x1="16" y1="3" x2="14" y2="21"/>
                </svg>
                <span>Topics ({systemStats.pendingTopics})</span>
              </button>
            </li>
            <li>
              <button 
                className={`nav-item ${currentTab === "images" ? "active" : ""}`}
                onClick={() => { setCurrentTab("images"); setSelectedItem(null); setSelectedType(null); }}
              >
                <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="#ffffff" strokeWidth="2">
                  <rect x="3" y="3" width="18" height="18" rx="2" ry="2"/>
                  <circle cx="8.5" cy="8.5" r="1.5"/>
                  <polyline points="21 15 16 10 5 21"/>
                </svg>
                <span>Image Queue ({systemStats.pendingImages})</span>
              </button>
            </li>
            <li>
              <button 
                className={`nav-item ${currentTab === "reports" ? "active" : ""}`}
                onClick={() => { setCurrentTab("reports"); setSelectedItem(null); setSelectedType(null); }}
              >
                <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="#ffffff" strokeWidth="2">
                  <path d="M4 15s1-1 4-1 5 2 8 2 4-1 4-1V3s-1 1-4 1-5-2-8-2-4 1-4 1z"/>
                  <line x1="4" y1="22" x2="4" y2="15"/>
                </svg>
                <span>Reports ({systemStats.pendingReports})</span>
              </button>
            </li>
            <li>
              <button 
                className={`nav-item ${currentTab === "logs" ? "active" : ""}`}
                onClick={() => { setCurrentTab("logs"); setSelectedItem(null); setSelectedType(null); }}
              >
                <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="#ffffff" strokeWidth="2">
                  <path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"/>
                  <polyline points="14 2 14 8 20 8"/>
                  <line x1="16" y1="13" x2="8" y2="13"/>
                  <line x1="16" y1="17" x2="8" y2="17"/>
                  <polyline points="10 9 9 9 8 9"/>
                </svg>
                <span>Audit Logs</span>
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
              {currentTab === "dashboard" && "Dashboard & Pipeline Control"}
              {currentTab === "videos" && "Videos & Thumbnails Moderation"}
              {currentTab === "channels" && "Channels Moderation (Avatar & Banner)"}
              {currentTab === "topics" && "Topics Moderation & Verifications"}
              {currentTab === "images" && "Image Moderation Queue"}
              {currentTab === "reports" && "Video & Content Reports"}
              {currentTab === "logs" && "Audit Logs & Actions History"}
            </h1>
            <p>
              {currentTab === "dashboard" && "Toggle moderation routing modes (Gemini AI vs Admin Only) and monitor platform health."}
              {currentTab === "videos" && "Manage video and thumbnail review pipelines with On/Off Gemini bypass buttons."}
              {currentTab === "channels" && "Manage channel details, avatar, and banner review pipelines with On/Off Gemini bypass buttons."}
              {currentTab === "topics" && "Manage topic details and thumbnails with On/Off Gemini bypass button."}
              {currentTab === "images" && "Inspect flagged thumbnails, avatars, and community posts."}
              {currentTab === "reports" && "User-submitted reports for videos, comments, and channels."}
              {currentTab === "logs" && "History of quarantined resources and manual administrator decisions."}
            </p>
          </div>
        </header>

        <div className="content-body">
          {error && <div className="error-banner" style={{ marginBottom: "20px" }}>{error}</div>}
          {successMsg && <div className="success-banner" style={{ marginBottom: "20px" }}>{successMsg}</div>}

          {/* TAB 1: DASHBOARD */}
          {currentTab === "dashboard" && (
            <div>
              {/* Overall Pipeline Control Switchboard */}
              <div className="glass section-card" style={{ marginBottom: "30px" }}>
                <div className="section-header">
                  <div className="section-title">
                    <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="#ffffff" strokeWidth="2">
                      <circle cx="12" cy="12" r="3"/>
                      <path d="M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 0 1 0 2.83 2 2 0 0 1-2.83 0l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2 2 0 0 1-2 2 2 2 0 0 1-2-2v-.09A1.65 1.65 0 0 0 9 19.4a1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 0 1-2.83 0 2 2 0 0 1 0-2.83l.06-.06a1.65 1.65 0 0 0 .33-1.82 1.65 1.65 0 0 0-1.51-1H3a2 2 0 0 1-2-2 2 2 0 0 1 2-2h.09A1.65 1.65 0 0 0 4.6 9a1.65 1.65 0 0 0-.33-1.82l-.06-.06a2 2 0 0 1 0-2.83 2 2 0 0 1 2.83 0l.06.06a1.65 1.65 0 0 0 1.82.33H9a1.65 1.65 0 0 0 1-1.51V3a2 2 0 0 1 2-2 2 2 0 0 1 2 2v.09a1.65 1.65 0 0 0 1 1.51 1.65 1.65 0 0 0 1.82-.33l.06-.06a2 2 0 0 1 2.83 0 2 2 0 0 1 0 2.83l-.06.06a1.65 1.65 0 0 0-.33 1.82V9a1.65 1.65 0 0 0 1.51 1H21a2 2 0 0 1 2 2 2 2 0 0 1-2 2h-.09a1.65 1.65 0 0 0-1.51 1z"/>
                    </svg>
                    <h3>Moderation Routing Control Switchboard</h3>
                  </div>
                  <span className="section-badge">Live Real-time Config</span>
                </div>
                <p style={{ color: "var(--text-secondary)", fontSize: "0.9rem", marginBottom: "20px" }}>
                  Toggle ON to bypass Gemini AI and send items <strong>directly to Admin only</strong> for manual review. When OFF, items are sent to <strong>Gemini AI automatically</strong>.
                </p>

                <div className="switchboard-grid">
                  <ModeToggleSwitch 
                    label="Videos Content" 
                    sublabel="Uploaded video media stream"
                    modeKey="videos"
                  />
                  <ModeToggleSwitch 
                    label="Video Thumbnails" 
                    sublabel="Video cover images"
                    modeKey="thumbnails"
                  />
                  <ModeToggleSwitch 
                    label="Channel Details" 
                    sublabel="Name, description, tags"
                    modeKey="channels"
                  />
                  <ModeToggleSwitch 
                    label="Channel Avatar" 
                    sublabel="Profile avatar image"
                    modeKey="avatar"
                  />
                  <ModeToggleSwitch 
                    label="Channel Banner" 
                    sublabel="Channel header banner"
                    modeKey="banner"
                  />
                  <ModeToggleSwitch 
                    label="Topics" 
                    sublabel="Topic title, description & thumb"
                    modeKey="topics"
                  />
                </div>
              </div>

              {/* Stats Grid */}
              <div className="stats-grid">
                <div className="stat-card glass video" onClick={() => setCurrentTab("videos")} style={{ cursor: "pointer" }}>
                  <div className="stat-label">Pending Videos</div>
                  <div className="stat-value">{systemStats.pendingVideos}</div>
                  <div className="stat-sub">
                    Mode: {moderationModes.videos ? "🛡️ Admin Only" : "🤖 Gemini AI"}
                  </div>
                </div>
                <div className="stat-card glass" onClick={() => setCurrentTab("channels")} style={{ cursor: "pointer", borderLeft: "4px solid #ec4899" }}>
                  <div className="stat-label">Pending Channels</div>
                  <div className="stat-value">{systemStats.pendingChannels}</div>
                  <div className="stat-sub">
                    Mode: {moderationModes.channels ? "🛡️ Admin Only" : "🤖 Gemini AI"}
                  </div>
                </div>
                <div className="stat-card glass" onClick={() => setCurrentTab("topics")} style={{ cursor: "pointer", borderLeft: "4px solid #eab308" }}>
                  <div className="stat-label">Pending Topics</div>
                  <div className="stat-value">{systemStats.pendingTopics}</div>
                  <div className="stat-sub">
                    Mode: {moderationModes.topics ? "🛡️ Admin Only" : "🤖 Gemini AI"}
                  </div>
                </div>
                <div className="stat-card glass image" onClick={() => setCurrentTab("images")} style={{ cursor: "pointer" }}>
                  <div className="stat-label">Pending Images</div>
                  <div className="stat-value">{systemStats.pendingImages}</div>
                  <div className="stat-sub">Thumbnails, Avatars & Banners</div>
                </div>
              </div>

              {/* Recent Activity Table */}
              <div className="glass" style={{ padding: "24px", borderRadius: "16px" }}>
                <h3 style={{ marginBottom: "16px", fontFamily: "var(--font-display)" }}>Recent System Moderation Activity</h3>
                <div className="audit-table-wrapper">
                  <table className="audit-table">
                    <thead>
                      <tr>
                        <th>Resource ID / Name</th>
                        <th>Type</th>
                        <th>Status</th>
                        <th>Reason / Action</th>
                        <th>Timestamp</th>
                      </tr>
                    </thead>
                    <tbody>
                      {videos.slice(0, 3).map(v => (
                        <tr key={v.id}>
                          <td>{v.title || v.id}</td>
                          <td><span className="badge" style={{ background: "rgba(139, 92, 246, 0.1)", color: "var(--accent-purple)" }}>Video</span></td>
                          <td>
                            <span className={`badge ${v.moderation?.status || "pending"}`}>
                              {v.moderation?.status || "pending"}
                            </span>
                          </td>
                          <td>{v.moderation?.reason || "Awaiting moderation decision"}</td>
                          <td>{formatDate(v.createdAt)}</td>
                        </tr>
                      ))}
                      {channels.slice(0, 3).map(c => (
                        <tr key={c.id}>
                          <td>{c.displayName || c.channelName || c.id}</td>
                          <td><span className="badge" style={{ background: "rgba(236, 72, 153, 0.1)", color: "#ec4899" }}>Channel</span></td>
                          <td>
                            <span className={`badge ${c.status || "underReview"}`}>
                              {c.status || "underReview"}
                            </span>
                          </td>
                          <td>{c.moderationReason || "Channel registration review"}</td>
                          <td>{formatDate(c.updatedAt || c.createdAt)}</td>
                        </tr>
                      ))}
                      {topics.slice(0, 3).map(t => (
                        <tr key={t.id}>
                          <td>{t.title || t.id}</td>
                          <td><span className="badge" style={{ background: "rgba(234, 179, 8, 0.1)", color: "#eab308" }}>Topic</span></td>
                          <td>
                            <span className={`badge ${t.status || "underReview"}`}>
                              {t.status || "underReview"}
                            </span>
                          </td>
                          <td>{t.moderationReason || "Topic creation review"}</td>
                          <td>{formatDate(t.updatedAt || t.createdAt)}</td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
              </div>
            </div>
          )}

          {/* TAB 2: VIDEOS QUEUE & CONTROLS */}
          {currentTab === "videos" && (
            <div>
              {/* On/Off Switches Header for Videos and Thumbnails */}
              <div className="page-controls-banner glass">
                <div className="banner-left">
                  <div className="banner-title">
                    <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="#ffffff" strokeWidth="2">
                      <polygon points="23 7 16 12 23 17 23 7"/>
                      <rect x="1" y="5" width="15" height="14" rx="2" ry="2"/>
                    </svg>
                    <h2>Video & Thumbnail Moderation Controls</h2>
                  </div>
                  <p>Configure whether uploaded videos and thumbnails are sent to Gemini AI or routed exclusively to Admin.</p>
                </div>
                <div className="banner-toggles">
                  <ModeToggleSwitch 
                    label="Videos Mode" 
                    sublabel="Video content stream"
                    modeKey="videos"
                    isSmall={true}
                  />
                  <ModeToggleSwitch 
                    label="Thumbnails Mode" 
                    sublabel="Video thumbnails"
                    modeKey="thumbnails"
                    isSmall={true}
                  />
                </div>
              </div>

              {/* Filter Pills */}
              <div className="filter-bar">
                <button 
                  className={`filter-pill ${videoFilter === "pending" ? "active" : ""}`}
                  onClick={() => setVideoFilter("pending")}
                >
                  Pending Review ({systemStats.pendingVideos})
                </button>
                <button 
                  className={`filter-pill ${videoFilter === "all" ? "active" : ""}`}
                  onClick={() => setVideoFilter("all")}
                >
                  All Videos ({videos.length})
                </button>
                <button 
                  className={`filter-pill ${videoFilter === "approved" ? "active" : ""}`}
                  onClick={() => setVideoFilter("approved")}
                >
                  Approved
                </button>
                <button 
                  className={`filter-pill ${videoFilter === "rejected" ? "active" : ""}`}
                  onClick={() => setVideoFilter("rejected")}
                >
                  Rejected
                </button>
              </div>

              {/* Queue Layout */}
              <div className={`queue-layout ${selectedItem && selectedType === "video" ? "split" : ""}`}>
                <div className="list-pane">
                  {filteredVideos.length === 0 ? (
                    <div className="empty-state glass">
                      <p>No videos found matching current filter ({videoFilter}).</p>
                    </div>
                  ) : (
                    filteredVideos.map(v => (
                      <div 
                        key={v.id} 
                        className={`item-card glass ${selectedItem?.id === v.id ? "selected" : ""}`}
                        onClick={() => { setSelectedItem(v); setSelectedType("video"); }}
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
                            <span className={`badge ${v.moderation?.status || v.status || "pending"}`}>
                              {(v.moderation?.status || v.status || "PENDING").toUpperCase()}
                            </span>
                            {v.moderation?.bypassGemini && (
                              <span className="badge priority-high">ADMIN ONLY</span>
                            )}
                          </div>
                        </div>
                      </div>
                    ))
                  )}
                </div>

                {/* Detail Pane */}
                {selectedItem && selectedType === "video" && (
                  <div className="detail-pane glass">
                    <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center" }}>
                      <h3 style={{ fontFamily: "var(--font-display)" }}>Inspect Video</h3>
                      <button className="btn-close-pane" onClick={() => { setSelectedItem(null); setSelectedType(null); }}>✕</button>
                    </div>
                    
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
                            <td className="label">Category</td>
                            <td className="value">{selectedItem.category || "Other"}</td>
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
                            <td className="label">Routing Mode</td>
                            <td className="value">
                              {selectedItem.moderation?.bypassGemini ? "🛡️ Routed to Admin (Gemini Bypassed)" : "🤖 Automatic Gemini AI"}
                            </td>
                          </tr>
                          <tr>
                            <td className="label">Trigger Reason</td>
                            <td className="value">{selectedItem.moderation?.reason || selectedItem.moderation?.policyReason || "System pipeline log."}</td>
                          </tr>
                          <tr>
                            <td className="label">GCS Path</td>
                            <td className="value">{selectedItem.storage?.videoPath || selectedItem.videoPath || "N/A"}</td>
                          </tr>
                        </tbody>
                      </table>
                    </div>

                    <div className="action-bar">
                      <button className="btn-approve" onClick={() => openConfirmModal("approve", selectedItem, "video")}>
                        Approve Video
                      </button>
                      <button className="btn-reject" onClick={() => openConfirmModal("reject", selectedItem, "video")}>
                        Reject Video
                      </button>
                    </div>
                  </div>
                )}
              </div>
            </div>
          )}

          {/* TAB 3: CHANNELS QUEUE & CONTROLS */}
          {currentTab === "channels" && (
            <div>
              {/* On/Off Switches Header for Channels, Avatar, and Banner */}
              <div className="page-controls-banner glass">
                <div className="banner-left">
                  <div className="banner-title">
                    <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="#ffffff" strokeWidth="2">
                      <path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"/>
                      <circle cx="9" cy="7" r="4"/>
                    </svg>
                    <h2>Channels Moderation Controls (Avatar & Banner)</h2>
                  </div>
                  <p>Toggle ON to bypass Gemini AI and send channel details, avatar, or banner directly to Admin.</p>
                </div>
                <div className="banner-toggles-3">
                  <ModeToggleSwitch 
                    label="Channel Details" 
                    sublabel="Name, desc, tags"
                    modeKey="channels"
                    isSmall={true}
                  />
                  <ModeToggleSwitch 
                    label="Avatar Mode" 
                    sublabel="Profile icon"
                    modeKey="avatar"
                    isSmall={true}
                  />
                  <ModeToggleSwitch 
                    label="Banner Mode" 
                    sublabel="Channel header"
                    modeKey="banner"
                    isSmall={true}
                  />
                </div>
              </div>

              {/* Filter Pills */}
              <div className="filter-bar">
                <button 
                  className={`filter-pill ${channelFilter === "pending" ? "active" : ""}`}
                  onClick={() => setChannelFilter("pending")}
                >
                  Under Review ({systemStats.pendingChannels})
                </button>
                <button 
                  className={`filter-pill ${channelFilter === "all" ? "active" : ""}`}
                  onClick={() => setChannelFilter("all")}
                >
                  All Channels ({channels.length})
                </button>
                <button 
                  className={`filter-pill ${channelFilter === "active" ? "active" : ""}`}
                  onClick={() => setChannelFilter("active")}
                >
                  Active / Approved
                </button>
                <button 
                  className={`filter-pill ${channelFilter === "rejected" ? "active" : ""}`}
                  onClick={() => setChannelFilter("rejected")}
                >
                  Rejected
                </button>
              </div>

              {/* Queue Layout */}
              <div className={`queue-layout ${selectedItem && selectedType === "channel" ? "split" : ""}`}>
                <div className="list-pane">
                  {filteredChannels.length === 0 ? (
                    <div className="empty-state glass">
                      <p>No channels found matching current filter ({channelFilter}).</p>
                    </div>
                  ) : (
                    filteredChannels.map(c => (
                      <div 
                        key={c.id} 
                        className={`item-card glass ${selectedItem?.id === c.id ? "selected" : ""}`}
                        onClick={() => { setSelectedItem(c); setSelectedType("channel"); }}
                      >
                        <div className="channel-avatar-thumb">
                          {c.avatarUrl || c.photoURL ? (
                            <img src={getFastDownloadUrl(c.avatarUrl || c.photoURL)} alt="Avatar" />
                          ) : (
                            <div className="avatar-placeholder">{(c.displayName || c.channelName || "C")[0]}</div>
                          )}
                        </div>
                        <div className="item-info">
                          <div className="item-title">{c.displayName || c.channelName || "Unnamed Channel"}</div>
                          <div className="item-meta">
                            <span>Handle: @{c.handle || c.customUrl || "none"}</span>
                            <span>•</span>
                            <span>{formatDate(c.updatedAt || c.createdAt)}</span>
                          </div>
                          <div style={{ display: "flex", gap: "8px", marginTop: "4px" }}>
                            <span className={`badge ${c.status || "underReview"}`}>
                              {(c.status || "underReview").toUpperCase()}
                            </span>
                            {c.bypassGemini && (
                              <span className="badge priority-high">ADMIN ONLY</span>
                            )}
                          </div>
                        </div>
                      </div>
                    ))
                  )}
                </div>

                {/* Detail Pane */}
                {selectedItem && selectedType === "channel" && (
                  <div className="detail-pane glass">
                    <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center" }}>
                      <h3 style={{ fontFamily: "var(--font-display)" }}>Inspect Channel</h3>
                      <button className="btn-close-pane" onClick={() => { setSelectedItem(null); setSelectedType(null); }}>✕</button>
                    </div>

                    {/* Banner and Avatar visual preview */}
                    <div className="channel-preview-banner-box">
                      {selectedItem.bannerUrl || selectedItem.headerUrl ? (
                        <img 
                          src={getFastDownloadUrl(selectedItem.bannerUrl || selectedItem.headerUrl)} 
                          alt="Banner" 
                          className="channel-preview-banner-img"
                        />
                      ) : (
                        <div className="channel-preview-banner-empty">No Banner Uploaded</div>
                      )}
                      <div className="channel-preview-avatar-overlay">
                        {selectedItem.avatarUrl || selectedItem.photoURL ? (
                          <img src={getFastDownloadUrl(selectedItem.avatarUrl || selectedItem.photoURL)} alt="Avatar" />
                        ) : (
                          <div className="avatar-placeholder-large">{(selectedItem.displayName || selectedItem.channelName || "C")[0]}</div>
                        )}
                      </div>
                    </div>

                    <div>
                      <h4 style={{ color: "var(--text-secondary)", marginBottom: "8px" }}>Channel Details</h4>
                      <table className="metadata-table">
                        <tbody>
                          <tr>
                            <td className="label">Channel ID</td>
                            <td className="value">{selectedItem.id}</td>
                          </tr>
                          <tr>
                            <td className="label">Display Name</td>
                            <td className="value">{selectedItem.displayName || selectedItem.channelName || "Unnamed"}</td>
                          </tr>
                          <tr>
                            <td className="label">Handle</td>
                            <td className="value">@{selectedItem.handle || selectedItem.customUrl || "none"}</td>
                          </tr>
                          <tr>
                            <td className="label">Description / About</td>
                            <td className="value">{selectedItem.about || selectedItem.description || "No description provided."}</td>
                          </tr>
                          <tr>
                            <td className="label">Tags</td>
                            <td className="value">{Array.isArray(selectedItem.tags) ? selectedItem.tags.join(", ") : (selectedItem.tags || "None")}</td>
                          </tr>
                          <tr>
                            <td className="label">Owner / Creator UID</td>
                            <td className="value">{selectedItem.ownerId || selectedItem.userId || "Unknown"}</td>
                          </tr>
                          <tr>
                            <td className="label">Status</td>
                            <td className="value">
                              <span className={`badge ${selectedItem.status || "underReview"}`}>
                                {(selectedItem.status || "underReview").toUpperCase()}
                              </span>
                            </td>
                          </tr>
                          <tr>
                            <td className="label">Moderation Reason</td>
                            <td className="value">{selectedItem.moderationReason || "Awaiting moderation decision."}</td>
                          </tr>
                        </tbody>
                      </table>
                    </div>

                    <div className="action-bar">
                      <button className="btn-approve" onClick={() => openConfirmModal("approve", selectedItem, "channel")}>
                        Approve Channel
                      </button>
                      <button className="btn-reject" onClick={() => openConfirmModal("reject", selectedItem, "channel")}>
                        Reject Channel
                      </button>
                    </div>
                  </div>
                )}
              </div>
            </div>
          )}

          {/* TAB 4: TOPICS QUEUE & CONTROLS */}
          {currentTab === "topics" && (
            <div>
              {/* On/Off Switch Header for Topics */}
              <div className="page-controls-banner glass">
                <div className="banner-left">
                  <div className="banner-title">
                    <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="#ffffff" strokeWidth="2">
                      <line x1="4" y1="9" x2="20" y2="9"/>
                      <line x1="4" y1="15" x2="20" y2="15"/>
                      <line x1="10" y1="3" x2="8" y2="21"/>
                      <line x1="16" y1="3" x2="14" y2="21"/>
                    </svg>
                    <h2>Topics Moderation Controls</h2>
                  </div>
                  <p>Configure whether created/updated topics are sent to Gemini AI or routed exclusively to Admin.</p>
                </div>
                <div className="banner-toggles">
                  <ModeToggleSwitch 
                    label="Topics Moderation Mode" 
                    sublabel="Topic title, description & thumb"
                    modeKey="topics"
                    isSmall={true}
                  />
                </div>
              </div>

              {/* Filter Pills */}
              <div className="filter-bar">
                <button 
                  className={`filter-pill ${topicFilter === "pending" ? "active" : ""}`}
                  onClick={() => setTopicFilter("pending")}
                >
                  Under Review ({systemStats.pendingTopics})
                </button>
                <button 
                  className={`filter-pill ${topicFilter === "all" ? "active" : ""}`}
                  onClick={() => setTopicFilter("all")}
                >
                  All Topics ({topics.length})
                </button>
                <button 
                  className={`filter-pill ${topicFilter === "active" ? "active" : ""}`}
                  onClick={() => setTopicFilter("active")}
                >
                  Active / Approved
                </button>
                <button 
                  className={`filter-pill ${topicFilter === "rejected" ? "active" : ""}`}
                  onClick={() => setTopicFilter("rejected")}
                >
                  Rejected
                </button>
              </div>

              {/* Queue Layout */}
              <div className={`queue-layout ${selectedItem && selectedType === "topic" ? "split" : ""}`}>
                <div className="list-pane">
                  {filteredTopics.length === 0 ? (
                    <div className="empty-state glass">
                      <p>No topics found matching current filter ({topicFilter}).</p>
                    </div>
                  ) : (
                    filteredTopics.map(t => (
                      <div 
                        key={t.id} 
                        className={`item-card glass ${selectedItem?.id === t.id ? "selected" : ""}`}
                        onClick={() => { setSelectedItem(t); setSelectedType("topic"); }}
                      >
                        <div className="item-thumb">
                          {t.thumbnailUrl ? <img src={t.thumbnailUrl} alt="Thumbnail" /> : <div style={{ fontSize: "1.8rem" }}>#️⃣</div>}
                        </div>
                        <div className="item-info">
                          <div className="item-title">#{t.title || t.name || "Untitled Topic"}</div>
                          <div className="item-meta">
                            <span>Handle: @{t.handle || "none"}</span>
                            <span>•</span>
                            <span>{formatDate(t.updatedAt || t.createdAt)}</span>
                          </div>
                          <div style={{ display: "flex", gap: "8px", marginTop: "4px" }}>
                            <span className={`badge ${t.status || "underReview"}`}>
                              {(t.status || "underReview").toUpperCase()}
                            </span>
                            {t.bypassGemini && (
                              <span className="badge priority-high">ADMIN ONLY</span>
                            )}
                          </div>
                        </div>
                      </div>
                    ))
                  )}
                </div>

                {/* Detail Pane */}
                {selectedItem && selectedType === "topic" && (
                  <div className="detail-pane glass">
                    <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center" }}>
                      <h3 style={{ fontFamily: "var(--font-display)" }}>Inspect Topic</h3>
                      <button className="btn-close-pane" onClick={() => { setSelectedItem(null); setSelectedType(null); }}>✕</button>
                    </div>

                    {selectedItem.thumbnailUrl && (
                      <div className="media-preview-container" style={{ maxHeight: "200px" }}>
                        <img src={getFastDownloadUrl(selectedItem.thumbnailUrl)} alt="Topic Thumbnail" />
                      </div>
                    )}

                    <div>
                      <h4 style={{ color: "var(--text-secondary)", marginBottom: "8px" }}>Topic Metadata</h4>
                      <table className="metadata-table">
                        <tbody>
                          <tr>
                            <td className="label">Topic ID</td>
                            <td className="value">{selectedItem.id}</td>
                          </tr>
                          <tr>
                            <td className="label">Topic Title</td>
                            <td className="value">{selectedItem.title || selectedItem.name || "Untitled"}</td>
                          </tr>
                          <tr>
                            <td className="label">Handle</td>
                            <td className="value">@{selectedItem.handle || "none"}</td>
                          </tr>
                          <tr>
                            <td className="label">Description</td>
                            <td className="value">{selectedItem.description || "No description provided."}</td>
                          </tr>
                          <tr>
                            <td className="label">Category</td>
                            <td className="value">{selectedItem.category || "General"}</td>
                          </tr>
                          <tr>
                            <td className="label">Status</td>
                            <td className="value">
                              <span className={`badge ${selectedItem.status || "underReview"}`}>
                                {(selectedItem.status || "underReview").toUpperCase()}
                              </span>
                            </td>
                          </tr>
                          <tr>
                            <td className="label">Moderation Reason</td>
                            <td className="value">{selectedItem.moderationReason || "Awaiting moderation decision."}</td>
                          </tr>
                        </tbody>
                      </table>
                    </div>

                    <div className="action-bar">
                      <button className="btn-approve" onClick={() => openConfirmModal("approve", selectedItem, "topic")}>
                        Approve Topic
                      </button>
                      <button className="btn-reject" onClick={() => openConfirmModal("reject", selectedItem, "topic")}>
                        Reject Topic
                      </button>
                    </div>
                  </div>
                )}
              </div>
            </div>
          )}

          {/* TAB 5: IMAGE MODERATION GRID */}
          {currentTab === "images" && (
            <div>
              {/* Filter Bar */}
              <div className="filter-bar">
                <button 
                  className={`filter-pill ${imageFilter === "pending" ? "active" : ""}`}
                  onClick={() => setImageFilter("pending")}
                >
                  Pending Review ({systemStats.pendingImages})
                </button>
                <button 
                  className={`filter-pill ${imageFilter === "all" ? "active" : ""}`}
                  onClick={() => setImageFilter("all")}
                >
                  All Images ({images.length})
                </button>
                <button 
                  className={`filter-pill ${imageFilter === "approved" ? "active" : ""}`}
                  onClick={() => setImageFilter("approved")}
                >
                  Approved
                </button>
                <button 
                  className={`filter-pill ${imageFilter === "rejected" ? "active" : ""}`}
                  onClick={() => setImageFilter("rejected")}
                >
                  Rejected
                </button>
              </div>

              <div className={`queue-layout ${selectedItem && selectedType === "image" ? "split" : ""}`}>
                <div className="list-pane">
                  {filteredImages.length === 0 ? (
                    <div className="empty-state glass">
                      <p>No images in the moderation queue matching filter ({imageFilter}).</p>
                    </div>
                  ) : (
                    <div className="image-grid">
                      {filteredImages.map(img => (
                        <div 
                          key={img.id} 
                          className={`grid-item-card glass ${selectedItem?.id === img.id ? "selected" : ""}`}
                          onClick={() => { setSelectedItem(img); setSelectedType("image"); }}
                        >
                          <div className="grid-item-image">
                            <img src={getFastDownloadUrl(img.gcsUri || img.filePath)} alt="Flagged" />
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
                {selectedItem && selectedType === "image" && (
                  <div className="detail-pane glass">
                    <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center" }}>
                      <h3 style={{ fontFamily: "var(--font-display)" }}>Inspect Image</h3>
                      <button className="btn-close-pane" onClick={() => { setSelectedItem(null); setSelectedType(null); }}>✕</button>
                    </div>

                    <div className="media-preview-container" style={{ aspectRatio: "1" }}>
                      <img src={getFastDownloadUrl(selectedItem.gcsUri || selectedItem.filePath)} alt="Inspection" />
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
                            <td className="label">Category</td>
                            <td className="value">{selectedItem.category}</td>
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
                        </tbody>
                      </table>
                    </div>

                    <div className="action-bar">
                      <button className="btn-approve" onClick={() => openConfirmModal("approve", selectedItem, "image")}>
                        Approve Image
                      </button>
                      <button className="btn-reject" onClick={() => openConfirmModal("reject", selectedItem, "image")}>
                        Reject Image
                      </button>
                    </div>
                  </div>
                )}
              </div>
            </div>
          )}

          {/* TAB 6: REPORTS QUEUE */}
          {currentTab === "reports" && (
            <div className={`queue-layout ${selectedItem ? "split" : ""}`}>
              <div className="list-pane">
                {reports.length === 0 ? (
                  <div className="empty-state glass">
                    <p>No reports in the database.</p>
                  </div>
                ) : (
                  reports.map(r => (
                    <div 
                      key={r.id} 
                      className={`item-card glass ${selectedItem?.id === r.id ? "selected" : ""}`}
                      onClick={() => { setSelectedItem(r); setSelectedType("report"); }}
                    >
                      <div className="item-info">
                        <div className="item-title">
                          Report: {typeof r.reason === 'object' ? (r.reason?.label || 'General') : (r.reason || 'General')}
                        </div>
                        <div className="item-meta">
                          <span>Video ID: {r.videoId || "N/A"}</span>
                          <span>•</span>
                          <span>{formatDate(r.createdAt)}</span>
                        </div>
                        <div style={{ display: "flex", gap: "8px", marginTop: "4px" }}>
                          <span className={`badge ${(r.status || "pending").toLowerCase()}`}>
                            {(r.status || "PENDING").toUpperCase()}
                          </span>
                        </div>
                      </div>
                    </div>
                  ))
                )}
              </div>

              {selectedItem && selectedType === "report" && (
                <div className="detail-pane glass">
                  <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center" }}>
                    <h3 style={{ fontFamily: "var(--font-display)" }}>Inspect Content Report</h3>
                    <button className="btn-close-pane" onClick={() => { setSelectedItem(null); setSelectedType(null); }}>✕</button>
                  </div>
                  <div>
                    <h4 style={{ color: "var(--text-secondary)", marginBottom: "8px" }}>Report Details</h4>
                    <table className="metadata-table">
                      <tbody>
                        <tr>
                          <td className="label">Report ID</td>
                          <td className="value">{selectedItem.id}</td>
                        </tr>
                        <tr>
                          <td className="label">Video ID</td>
                          <td className="value">{selectedItem.videoId || "N/A"}</td>
                        </tr>
                        <tr>
                          <td className="label">Channel ID</td>
                          <td className="value">{selectedItem.channelId || "N/A"}</td>
                        </tr>
                        <tr>
                          <td className="label">Reported By User</td>
                          <td className="value">{selectedItem.userEmail || selectedItem.userId || "Anonymous"}</td>
                        </tr>
                        <tr>
                          <td className="label">Reason Label</td>
                          <td className="value">{typeof selectedItem.reason === 'object' ? selectedItem.reason?.label : selectedItem.reason}</td>
                        </tr>
                        <tr>
                          <td className="label">Status</td>
                          <td className="value">
                            <span className={`badge ${(selectedItem.status || "pending").toLowerCase()}`}>
                              {(selectedItem.status || "PENDING").toUpperCase()}
                            </span>
                          </td>
                        </tr>
                      </tbody>
                    </table>
                  </div>
                </div>
              )}
            </div>
          )}

          {/* TAB 7: AUDIT LOGS */}
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
                        <td colSpan="5" style={{ textAlign: "center", color: "var(--text-muted)", padding: "40px" }}>
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
                Are you sure you want to manually <strong>{modalAction}</strong> this {selectedType}? 
                {modalAction === "reject" && " This will update resource status and restrict its availability across the platform."}
              </p>
              
              <div className="form-group" style={{ marginTop: "16px" }}>
                <label>Review Notes / Reason (Optional)</label>
                <textarea 
                  className="reason-textarea"
                  placeholder="Provide decision notes for audit logs..."
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

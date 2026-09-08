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
  updateDoc,
  deleteDoc,
  getDoc
} from "firebase/firestore";
import { auth, db } from "./firebase";

const OWNER_EMAIL = "ebenezervampy@towervsp.com";
const AUTHORIZED_ADMIN_EMAILS = [
  "ebenezervampy@towervsp.com",
  "ebenezervampu@towervsp.com",
  "ebenezervampu4@gmail.com",
  "admin@truthworld.com"
];

const ROLES_DEFINITION = [
  {
    name: "Super Admin",
    description: "Full uninhibited access to all moderation queues, pipelines, settings, and team access.",
    tabs: ["dashboard", "videos", "topics", "channels", "images", "reports", "logs", "team", "users", "ads", "analytics", "appeals", "feedbacks", "alerts", "security", "help"]
  },
  {
    name: "Content Moderator",
    description: "Review, approve, and reject videos, topics, images, and channels.",
    tabs: ["dashboard", "videos", "topics", "channels", "images"]
  },
  {
    name: "Trust & Safety Reviewer",
    description: "Manage user-flagged reports, appeals, and platform feedback.",
    tabs: ["reports", "appeals", "feedbacks"]
  },
  {
    name: "User Manager",
    description: "View, inspect, ban, and moderate registered user accounts.",
    tabs: ["users"]
  },
  {
    name: "Advertising Manager",
    description: "Audit sponsored ad campaigns and resolve advertiser reports.",
    tabs: ["ads", "ad_reports"]
  },
  {
    name: "Audit & Compliance Officer",
    description: "Review historical audit action logs, security settings, and platform alert rules.",
    tabs: ["logs", "security", "alerts"]
  },
  {
    name: "Analytics & Performance",
    description: "Examine platform metrics, retention analytics, and performance KPIs.",
    tabs: ["dashboard", "analytics"]
  },
  {
    name: "Team Manager",
    description: "Manage portal administrators, provision accounts, and configure permissions.",
    tabs: ["team"]
  }
];

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
    ads: false,          // Advertiser campaigns
  });
  const [modeUpdatingKey, setModeUpdatingKey] = useState(null);

  // Real-time Data States
  const [videos, setVideos] = useState([]);
  const [images, setImages] = useState([]);
  const [channels, setChannels] = useState([]);
  const [topics, setTopics] = useState([]);
  const [auditLogs, setAuditLogs] = useState([]);
  const [reports, setReports] = useState([]);
  const [adminMembers, setAdminMembers] = useState([]);
  const [showAddMemberModal, setShowAddMemberModal] = useState(false);
  const [showChangePasswordModal, setShowChangePasswordModal] = useState(false);
  const [newMemberEmail, setNewMemberEmail] = useState("");
  const [newMemberName, setNewMemberName] = useState("");
  const [newMemberPassword, setNewMemberPassword] = useState("");
  const [selectedMemberRoles, setSelectedMemberRoles] = useState(["Content Moderator"]);
  const [currentPasswordInput, setCurrentPasswordInput] = useState("");
  const [newPasswordInput, setNewPasswordInput] = useState("");
  const [confirmPasswordInput, setConfirmPasswordInput] = useState("");
  const [revealedPasswords, setRevealedPasswords] = useState({});

  // Tab Permission Evaluation
  const isTabAllowed = (tabId) => {
    if (!user) return false;
    const email = user.email?.toLowerCase();
    if (email === OWNER_EMAIL || AUTHORIZED_ADMIN_EMAILS.includes(email)) return true;

    // Get active roles
    let userRoles = user.roles || [];
    if (userRoles.length === 0 && user.role) {
      userRoles = user.role.split(",").map(r => r.trim()).filter(Boolean);
    }
    if (userRoles.length === 0) userRoles = ["Super Admin"];

    if (userRoles.some(r => r.toLowerCase().includes("super admin") || r.toLowerCase().includes("owner"))) {
      return true;
    }

    if (tabId === "help") return true;

    for (const rName of userRoles) {
      const roleDef = ROLES_DEFINITION.find(def => def.name.toLowerCase() === rName.toLowerCase());
      if (roleDef && roleDef.tabs.includes(tabId)) {
        return true;
      }
    }
    return false;
  };

  const getAllowedTabs = () => {
    const allTabs = ["dashboard", "videos", "topics", "channels", "images", "reports", "logs", "team"];
    const allowed = allTabs.filter(t => isTabAllowed(t));
    return allowed.length > 0 ? allowed : ["team"];
  };

  // Auto-redirect if current tab is not allowed
  useEffect(() => {
    if (user && isAdmin && !isTabAllowed(currentTab)) {
      const allowed = getAllowedTabs();
      if (allowed.length > 0 && !allowed.includes(currentTab)) {
        setCurrentTab(allowed[0]);
      }
    }
  }, [user, isAdmin, currentTab]);

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
    // Check saved session in localStorage
    try {
      const saved = localStorage.getItem("truthworld_admin_session");
      if (saved) {
        const parsed = JSON.parse(saved);
        if (parsed?.email) {
          const roles = parsed.roles || (parsed.role ? [parsed.role] : ["Super Admin"]);
          setUser({ 
            email: parsed.email, 
            role: parsed.role || "Super Admin", 
            roles: roles, 
            name: parsed.name || "" 
          });
          setIsAdmin(true);
        }
      }
    } catch (_) {}

    getRedirectResult(auth).catch((err) => {
      console.warn("Redirect result handled/failed:", err);
    });

    const unsubscribe = onAuthStateChanged(auth, async (currentUser) => {
      if (currentUser) {
        try {
          const idTokenResult = await currentUser.getIdTokenResult(true);
          const email = currentUser.email?.toLowerCase();
          const isOwner = email && AUTHORIZED_ADMIN_EMAILS.includes(email);

          if (idTokenResult.claims.admin === true || isOwner) {
            setUser({
              ...currentUser,
              role: isOwner ? "Owner / Super Admin" : "Super Admin",
              roles: ["Super Admin"],
            });
            setIsAdmin(true);
            setError("");
          } else {
            const saved = localStorage.getItem("truthworld_admin_session");
            if (!saved) {
              setError(`Access Denied: Account (${currentUser.email}) does not have admin privileges.`);
              await signOut(auth);
              setUser(null);
              setIsAdmin(false);
            }
          }
        } catch (err) {
          console.error("Auth claim validation failed:", err);
          const saved = localStorage.getItem("truthworld_admin_session");
          if (!saved) {
            setError("Authentication error. Please try again.");
            setUser(null);
            setIsAdmin(false);
          }
        }
      } else {
        const saved = localStorage.getItem("truthworld_admin_session");
        if (!saved) {
          setUser(null);
          setIsAdmin(false);
        }
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
          ads: data.ads === true || data.campaigns === true || data.adCampaigns === true || data.advertiser_campaigns === true,
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

    // 8. Listen to Admin Team Members
    const membersQuery = collection(db, "admin_members");
    const unsubMembers = onSnapshot(membersQuery, (snapshot) => {
      const list = snapshot.docs.map(doc => ({
        id: doc.id,
        ...doc.data()
      }));
      setAdminMembers(list);

      // Sync current logged-in user's roles and role in real time
      if (user?.email) {
        const myDoc = list.find(m => m.email?.toLowerCase() === user.email.toLowerCase());
        if (myDoc) {
          const rawRoles = Array.isArray(myDoc.roles)
            ? myDoc.roles
            : (myDoc.role ? myDoc.role.split(',').map(r => r.trim()).filter(Boolean) : []);
          const activeRoles = rawRoles.length > 0 ? rawRoles : ["Super Admin"];
          setUser(prev => ({
            ...prev,
            role: myDoc.role || prev?.role || "Super Admin",
            roles: activeRoles,
            name: myDoc.name || prev?.name || ""
          }));
        }
      }
    }, (err) => {
      console.warn("admin_members subscription warning:", err);
    });

    return () => {
      unsubModes();
      unsubVideos();
      unsubImages();
      unsubChannels();
      unsubTopics();
      unsubLogs();
      unsubReports();
      unsubMembers();
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

  // Handle Email & Password Login with Admin Protocol
  const handleEmailLogin = async (e) => {
    e.preventDefault();
    const cleanEmail = loginEmail.trim().toLowerCase();
    const cleanPassword = loginPassword.trim();

    if (!cleanEmail || !cleanPassword) {
      setError("Please enter both email and password.");
      return;
    }
    setError("");
    setIsLoggingIn(true);

    try {
      const isDefaultCreds = (cleanEmail === "ebenezervampy@towervsp.com" || cleanEmail === "ebenezervampu@towervsp.com") && cleanPassword === "12345";

      // 1. Check admin_members in Firestore
      let matchedMember = null;
      try {
        const memberRef = doc(db, "admin_members", cleanEmail);
        const memberSnap = await getDoc(memberRef);
        if (memberSnap.exists()) {
          matchedMember = memberSnap.data();
        }
      } catch (fErr) {
        console.warn("admin_members check notice:", fErr);
      }

      if (matchedMember && matchedMember.status === "suspended") {
        setError("This administrator account has been suspended.");
        setIsLoggingIn(false);
        return;
      }

      if ((matchedMember && matchedMember.password === cleanPassword) || isDefaultCreds) {
        const role = matchedMember?.role || (isDefaultCreds ? "Owner / Super Admin" : "Super Admin");
        let roles = Array.isArray(matchedMember?.roles) ? matchedMember.roles : [];
        if (roles.length === 0 && matchedMember?.role) {
          roles = matchedMember.role.split(",").map(r => r.trim()).filter(Boolean);
        }
        if (roles.length === 0) {
          roles = ["Super Admin"];
        }
        const adminUser = { 
          email: cleanEmail, 
          role, 
          roles, 
          name: matchedMember?.name || cleanEmail.split("@")[0] 
        };
        setUser(adminUser);
        setIsAdmin(true);

        try {
          localStorage.setItem("truthworld_admin_session", JSON.stringify(adminUser));
        } catch (_) {}

        // Ensure default admin is seeded in Firestore
        if (isDefaultCreds && !matchedMember) {
          try {
            await setDoc(doc(db, "admin_members", "ebenezervampy@towervsp.com"), {
              email: "ebenezervampy@towervsp.com",
              password: "12345",
              role: "Owner / Super Admin",
              roles: ROLES_DEFINITION.map(r => r.name),
              name: "Ebenezer Vampu",
              status: "active",
              createdAt: Date.now(),
            }, { merge: true });
          } catch (_) {}
        }

        setSuccessMsg(`Welcome to Admin Portal (${cleanEmail})`);
        setTimeout(() => setSuccessMsg(""), 4000);
        setIsLoggingIn(false);
        return;
      }

      // 2. Fallback to Firebase Auth
      if (cleanPassword.length >= 6) {
        await signInWithEmailAndPassword(auth, cleanEmail, cleanPassword);
      } else {
        throw new Error("Invalid administrator email or password.");
      }
    } catch (err) {
      console.error("Email login failed:", err);
      setError(err instanceof Error ? err.message : "Authentication failed.");
      setIsLoggingIn(false);
    }
  };

  // Handle Add Member
  const handleAddMember = async (e) => {
    e.preventDefault();
    if (!newMemberEmail.trim() || !newMemberPassword.trim()) {
      setError("Please provide member email and password.");
      return;
    }
    if (selectedMemberRoles.length === 0) {
      setError("Please select at least one role for this team member.");
      return;
    }
    const cleanEmail = newMemberEmail.trim().toLowerCase();
    const primaryRole = selectedMemberRoles.length === ROLES_DEFINITION.length
      ? "Super Admin (All Tabs)"
      : selectedMemberRoles.join(", ");

    try {
      await setDoc(doc(db, "admin_members", cleanEmail), {
        email: cleanEmail,
        password: newMemberPassword.trim(),
        name: newMemberName.trim() || cleanEmail.split("@")[0],
        role: primaryRole,
        roles: selectedMemberRoles,
        status: "active",
        createdAt: Date.now(),
        createdBy: user?.email || "Admin",
      }, { merge: true });

      setSuccessMsg(`Member ${cleanEmail} added with ${selectedMemberRoles.length} role(s)!`);
      setShowAddMemberModal(false);
      setNewMemberEmail("");
      setNewMemberName("");
      setNewMemberPassword("");
      setSelectedMemberRoles(["Content Moderator"]);
      setTimeout(() => setSuccessMsg(""), 4000);
    } catch (err) {
      setError(`Failed to add member: ${err.message}`);
    }
  };

  // Handle Delete Member
  const handleDeleteMember = async (email) => {
    if (email === "ebenezervampy@towervsp.com" || email === "ebenezervampu@towervsp.com") {
      alert("Primary Owner account cannot be removed.");
      return;
    }
    if (!window.confirm(`Revoke administrator access for ${email}?`)) return;
    try {
      await deleteDoc(doc(db, "admin_members", email.toLowerCase()));
      setSuccessMsg(`Member ${email} removed.`);
      setTimeout(() => setSuccessMsg(""), 4000);
    } catch (err) {
      setError(`Failed to remove member: ${err.message}`);
    }
  };

  // Handle Change Password
  const handleChangePassword = async (e) => {
    e.preventDefault();
    if (!newPasswordInput.trim()) {
      setError("New password cannot be empty.");
      return;
    }
    if (newPasswordInput !== confirmPasswordInput) {
      setError("New passwords do not match.");
      return;
    }
    try {
      const email = user?.email || "ebenezervampy@towervsp.com";
      await setDoc(doc(db, "admin_members", email.toLowerCase()), {
        password: newPasswordInput.trim(),
        updatedAt: Date.now(),
      }, { merge: true });

      setSuccessMsg("Password updated successfully!");
      setShowChangePasswordModal(false);
      setCurrentPasswordInput("");
      setNewPasswordInput("");
      setConfirmPasswordInput("");
      setTimeout(() => setSuccessMsg(""), 4000);
    } catch (err) {
      setError(`Failed to change password: ${err.message}`);
    }
  };

  // Copy Member Credentials
  const copyCredentials = (email, password, role) => {
    const text = `TruthWorld Admin Portal Login Credentials\nEmail: ${email}\nPassword: ${password}\nRole: ${role || "Admin"}\nPortal URL: https://truthworld.in/admin`;
    navigator.clipboard.writeText(text);
    setSuccessMsg(`Credentials for ${email} copied to clipboard! Ready to share.`);
    setTimeout(() => setSuccessMsg(""), 4000);
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
      localStorage.removeItem("truthworld_admin_session");
      setUser(null);
      setIsAdmin(false);
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
                  placeholder="ebenezervampy@towervsp.com" 
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
              Authorized Owner: <strong>ebenezervampy@towervsp.com</strong>
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
    const cat = (img.category || img.targetType || img.type || img.itemType || '').toLowerCase();
    const path = (img.gcsPath || img.filePath || img.originalUrl || img.imageUrl || '').toLowerCase();
    const id = (img.id || img.docId || '').toLowerCase();
    if (cat.includes('topic') || path.includes('topic') || id.includes('topic')) return false;
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
            {isTabAllowed("dashboard") && (
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
            )}
            {isTabAllowed("videos") && (
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
            )}
            {isTabAllowed("topics") && (
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
            )}
            {isTabAllowed("channels") && (
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
            )}
            {isTabAllowed("images") && (
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
            )}
            {isTabAllowed("reports") && (
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
            )}
            {isTabAllowed("logs") && (
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
            )}
            {isTabAllowed("team") && (
              <li>
                <button 
                  className={`nav-item ${currentTab === "team" ? "active" : ""}`}
                  onClick={() => { setCurrentTab("team"); setSelectedItem(null); setSelectedType(null); }}
                >
                  <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="#ffffff" strokeWidth="2">
                    <path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"/>
                    <circle cx="9" cy="7" r="4"/>
                    <path d="M23 21v-2a4 4 0 0 0-3-3.87"/>
                    <path d="M16 3.13a4 4 0 0 1 0 7.75"/>
                  </svg>
                  <span>Team Members ({adminMembers.length})</span>
                </button>
              </li>
            )}
          </ul>
        </nav>
        <div className="sidebar-footer">
          <div className="admin-profile">
            <div className="admin-name">{user.email}</div>
            <div className="admin-role" style={{ whiteSpace: "normal", wordBreak: "break-word" }}>
              {Array.isArray(user.roles) && user.roles.length > 0 ? user.roles.join(", ") : (user.role || "System Administrator")}
            </div>
          </div>
          <button 
            type="button"
            className="btn-secondary" 
            style={{ 
              width: "100%", 
              marginBottom: "8px", 
              padding: "8px 12px", 
              fontSize: "0.85rem", 
              display: "flex", 
              alignItems: "center", 
              justifyContent: "center", 
              gap: "8px",
              background: "rgba(255, 255, 255, 0.08)",
              border: "1px solid rgba(255, 255, 255, 0.15)",
              color: "#ffffff",
              borderRadius: "8px",
              cursor: "pointer"
            }}
            onClick={() => {
              setCurrentPasswordInput("");
              setNewPasswordInput("");
              setConfirmPasswordInput("");
              setShowChangePasswordModal(true);
            }}
          >
            <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="#ffffff" strokeWidth="2">
              <rect x="3" y="11" width="18" height="11" rx="2" ry="2"/>
              <path d="M7 11V7a5 5 0 0 1 10 0v4"/>
            </svg>
            <span>Change Password</span>
          </button>
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
              {currentTab === "team" && "Team Access & Member Management"}
            </h1>
            <p>
              {currentTab === "dashboard" && "Toggle moderation routing modes (Gemini AI vs Admin Only) and monitor platform health."}
              {currentTab === "videos" && "Manage video and thumbnail review pipelines with On/Off Gemini bypass buttons."}
              {currentTab === "channels" && "Manage channel details, avatar, and banner review pipelines with On/Off Gemini bypass buttons."}
              {currentTab === "topics" && "Manage topic details and thumbnails with On/Off Gemini bypass button."}
              {currentTab === "images" && "Inspect flagged thumbnails, avatars, and community posts."}
              {currentTab === "reports" && "User-submitted reports for videos, comments, and channels."}
              {currentTab === "logs" && "History of quarantined resources and manual administrator decisions."}
              {currentTab === "team" && "Add members with custom credentials, copy/share login access, and change passwords."}
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
                  <ModeToggleSwitch 
                    label="Advertiser Campaigns" 
                    sublabel="Ad creative, text & CTA links"
                    modeKey="ads"
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

          {/* TAB 8: TEAM MEMBERS MANAGEMENT */}
          {currentTab === "team" && (
            <div>
              {/* Security Banner */}
              <div 
                className="glass" 
                style={{ 
                  padding: "18px 24px", 
                  borderRadius: "14px", 
                  marginBottom: "24px", 
                  display: "flex", 
                  alignItems: "center", 
                  justifyContent: "space-between",
                  background: "rgba(255, 255, 255, 0.03)",
                  border: "1px solid rgba(255, 255, 255, 0.1)"
                }}
              >
                <div style={{ display: "flex", alignItems: "center", gap: "14px" }}>
                  <div style={{ padding: "10px", borderRadius: "10px", background: "rgba(255, 255, 255, 0.08)", display: "flex" }}>
                    <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="#ffffff" strokeWidth="2">
                      <path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z"/>
                    </svg>
                  </div>
                  <div>
                    <h4 style={{ margin: 0, fontSize: "1rem", color: "#ffffff", fontWeight: 600 }}>Strict Protocol Enforcement</h4>
                    <p style={{ margin: "4px 0 0 0", color: "var(--text-secondary)", fontSize: "0.85rem" }}>
                      No one can enter without authentication. Add team members with specific email & password credentials, copy and share with them directly.
                    </p>
                  </div>
                </div>
                <button 
                  className="btn-primary"
                  style={{ whiteSpace: "nowrap", padding: "10px 18px", display: "flex", alignItems: "center", gap: "8px" }}
                  onClick={() => {
                    setNewMemberEmail("");
                    setNewMemberName("");
                    setNewMemberPassword("");
                    setSelectedMemberRoles(["Content Moderator"]);
                    setShowAddMemberModal(true);
                  }}
                >
                  <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="#ffffff" strokeWidth="2">
                    <line x1="12" y1="5" x2="12" y2="19"/>
                    <line x1="5" y1="12" x2="19" y2="12"/>
                  </svg>
                  <span>Add Team Member</span>
                </button>
              </div>

              {/* Members Table */}
              <div className="glass" style={{ padding: "24px", borderRadius: "16px" }}>
                <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: "16px" }}>
                  <h3 style={{ margin: 0, fontFamily: "var(--font-display)" }}>
                    Authorized Team Members ({adminMembers.length})
                  </h3>
                  <span style={{ fontSize: "0.85rem", color: "var(--text-muted)" }}>
                    Collection: <code>admin_members</code>
                  </span>
                </div>

                <div className="audit-table-wrapper">
                  <table className="audit-table">
                    <thead>
                      <tr>
                        <th>Administrator</th>
                        <th>Role</th>
                        <th>Status</th>
                        <th>Credentials Password</th>
                        <th>Created Date</th>
                        <th style={{ textAlign: "right" }}>Actions</th>
                      </tr>
                    </thead>
                    <tbody>
                      {adminMembers.length === 0 ? (
                        <tr>
                          <td colSpan="6" style={{ textAlign: "center", color: "var(--text-muted)", padding: "40px" }}>
                            No team members configured yet. Click "Add Team Member" above to invite members.
                          </td>
                        </tr>
                      ) : (
                        adminMembers.map((member) => {
                          const isOwner = member.email === "ebenezervampy@towervsp.com" || member.email === "ebenezervampu@towervsp.com";
                          const isRevealed = revealedPasswords[member.email] === true;
                          const pwd = member.password || "••••••";

                          return (
                            <tr key={member.id || member.email}>
                              <td>
                                <div style={{ display: "flex", flexDirection: "column" }}>
                                  <div style={{ fontWeight: 600, color: "#ffffff", display: "flex", alignItems: "center", gap: "6px" }}>
                                    <span>{member.name || member.email.split("@")[0]}</span>
                                    {isOwner && (
                                      <span className="badge" style={{ background: "rgba(255, 255, 255, 0.15)", color: "#ffffff", fontSize: "0.7rem", padding: "2px 6px" }}>
                                        Primary Owner
                                      </span>
                                    )}
                                  </div>
                                  <span style={{ fontSize: "0.82rem", color: "var(--text-secondary)" }}>{member.email}</span>
                                </div>
                              </td>
                              <td>
                                <div style={{ display: "flex", flexWrap: "wrap", gap: "4px" }}>
                                  {(Array.isArray(member.roles) && member.roles.length > 0 
                                      ? member.roles 
                                      : (member.role ? member.role.split(",").map(r => r.trim()).filter(Boolean) : ["Admin"])
                                  ).map((r, idx) => (
                                    <span key={idx} className="badge" style={{ background: "rgba(255, 255, 255, 0.08)", color: "#ffffff", fontSize: "0.75rem" }}>
                                      {r}
                                    </span>
                                  ))}
                                </div>
                              </td>
                              <td>
                                <span className={`badge ${member.status === "active" || !member.status ? "active" : "rejected"}`}>
                                  {(member.status || "active").toUpperCase()}
                                </span>
                              </td>
                              <td>
                                <div style={{ display: "flex", alignItems: "center", gap: "8px" }}>
                                  <code style={{ fontSize: "0.9rem", letterSpacing: isRevealed ? "normal" : "2px" }}>
                                    {isRevealed ? member.password : "••••••••"}
                                  </code>
                                  {member.password && (
                                    <button 
                                      type="button"
                                      title={isRevealed ? "Hide Password" : "Show Password"}
                                      style={{ background: "none", border: "none", cursor: "pointer", padding: "4px", display: "flex" }}
                                      onClick={() => {
                                        setRevealedPasswords(prev => ({
                                          ...prev,
                                          [member.email]: !prev[member.email]
                                        }));
                                      }}
                                    >
                                      <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="#ffffff" strokeWidth="2">
                                        <path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z"/>
                                        <circle cx="12" cy="12" r="3"/>
                                      </svg>
                                    </button>
                                  )}
                                </div>
                              </td>
                              <td>
                                <span style={{ fontSize: "0.85rem", color: "var(--text-secondary)" }}>
                                  {formatDate(member.createdAt)}
                                </span>
                              </td>
                              <td style={{ textAlign: "right" }}>
                                <div style={{ display: "inline-flex", alignItems: "center", gap: "8px" }}>
                                  <button 
                                    type="button"
                                    className="btn-secondary"
                                    style={{ padding: "6px 12px", fontSize: "0.8rem", display: "inline-flex", alignItems: "center", gap: "6px", background: "rgba(255, 255, 255, 0.08)", border: "1px solid rgba(255, 255, 255, 0.15)", color: "#ffffff", borderRadius: "6px", cursor: "pointer" }}
                                    title="Copy login details to clipboard"
                                    onClick={() => copyCredentials(member.email, member.password || "12345", member.role)}
                                  >
                                    <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="#ffffff" strokeWidth="2">
                                      <rect x="9" y="9" width="13" height="13" rx="2" ry="2"/>
                                      <path d="M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1"/>
                                    </svg>
                                    <span>Copy & Share</span>
                                  </button>
                                  {!isOwner && (
                                    <button 
                                      type="button"
                                      style={{ padding: "6px 10px", fontSize: "0.8rem", display: "inline-flex", alignItems: "center", gap: "4px", background: "rgba(239, 68, 68, 0.15)", border: "1px solid rgba(239, 68, 68, 0.3)", color: "#ef4444", borderRadius: "6px", cursor: "pointer" }}
                                      title="Revoke administrator access"
                                      onClick={() => handleDeleteMember(member.email)}
                                    >
                                      <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="#ffffff" strokeWidth="2">
                                        <polyline points="3 6 5 6 21 6"/>
                                        <path d="M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6m3 0V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2"/>
                                      </svg>
                                      <span>Remove</span>
                                    </button>
                                  )}
                                </div>
                              </td>
                            </tr>
                          );
                        })
                      )}
                    </tbody>
                  </table>
                </div>
              </div>
            </div>
          )}
        </div>
      </main>

      {/* Add Team Member Modal */}
      {showAddMemberModal && (
        <div className="modal-overlay">
          <div className="modal-content glass" style={{ maxWidth: "480px" }}>
            <div className="modal-header">
              Add New Team Member
            </div>
            <form onSubmit={handleAddMember}>
              <div className="modal-body">
                <p style={{ color: "var(--text-secondary)", fontSize: "0.9rem", marginBottom: "16px" }}>
                  Create an administrator credential. The member will use this email and password to log in directly to the TruthWorld Admin Portal.
                </p>

                <div className="form-group" style={{ marginBottom: "14px" }}>
                  <label>Member Email</label>
                  <input 
                    type="email" 
                    placeholder="teammate@towervsp.com" 
                    value={newMemberEmail}
                    onChange={(e) => setNewMemberEmail(e.target.value)}
                    required
                  />
                </div>

                <div className="form-group" style={{ marginBottom: "14px" }}>
                  <label>Full Name</label>
                  <input 
                    type="text" 
                    placeholder="John Doe" 
                    value={newMemberName}
                    onChange={(e) => setNewMemberName(e.target.value)}
                  />
                </div>

                <div className="form-group" style={{ marginBottom: "16px" }}>
                  <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: "8px" }}>
                    <label style={{ margin: 0, fontWeight: 600 }}>
                      Assigned Roles & Tab Permissions ({selectedMemberRoles.length}/{ROLES_DEFINITION.length})
                    </label>
                    <button 
                      type="button"
                      onClick={() => {
                        if (selectedMemberRoles.length === ROLES_DEFINITION.length) {
                          setSelectedMemberRoles([]);
                        } else {
                          setSelectedMemberRoles(ROLES_DEFINITION.map(r => r.name));
                        }
                      }}
                      style={{
                        background: "rgba(255, 255, 255, 0.1)",
                        border: "1px solid rgba(255, 255, 255, 0.2)",
                        borderRadius: "6px",
                        padding: "4px 10px",
                        color: "#ffffff",
                        fontSize: "0.75rem",
                        cursor: "pointer"
                      }}
                    >
                      {selectedMemberRoles.length === ROLES_DEFINITION.length ? "Deselect All" : "Select All Roles"}
                    </button>
                  </div>
                  <div style={{
                    display: "flex",
                    flexDirection: "column",
                    gap: "6px",
                    maxHeight: "220px",
                    overflowY: "auto",
                    padding: "8px",
                    background: "rgba(255, 255, 255, 0.03)",
                    border: "1px solid var(--border-glass)",
                    borderRadius: "8px"
                  }}>
                    {ROLES_DEFINITION.map((roleDef) => {
                      const isChecked = selectedMemberRoles.includes(roleDef.name);
                      return (
                        <label 
                          key={roleDef.name}
                          style={{
                            display: "flex",
                            alignItems: "flex-start",
                            gap: "10px",
                            padding: "6px 8px",
                            borderRadius: "6px",
                            background: isChecked ? "rgba(255, 255, 255, 0.08)" : "transparent",
                            cursor: "pointer",
                            userSelect: "none"
                          }}
                        >
                          <input 
                            type="checkbox"
                            checked={isChecked}
                            onChange={(e) => {
                              if (e.target.checked) {
                                setSelectedMemberRoles(prev => [...prev, roleDef.name]);
                              } else {
                                setSelectedMemberRoles(prev => prev.filter(r => r !== roleDef.name));
                              }
                            }}
                            style={{ marginTop: "3px", accentColor: "#ffffff" }}
                          />
                          <div style={{ flex: 1 }}>
                            <div style={{ fontWeight: 600, fontSize: "0.85rem", color: "#ffffff" }}>
                              {roleDef.name}
                            </div>
                            <div style={{ fontSize: "0.72rem", color: "var(--text-secondary)", marginTop: "1px" }}>
                              {roleDef.description}
                            </div>
                          </div>
                        </label>
                      );
                    })}
                  </div>
                </div>

                <div className="form-group" style={{ marginBottom: "8px" }}>
                  <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: "6px" }}>
                    <label style={{ margin: 0 }}>Password</label>
                    <button 
                      type="button" 
                      style={{ background: "none", border: "none", color: "#ffffff", fontSize: "0.8rem", cursor: "pointer", textDecoration: "underline" }}
                      onClick={() => {
                        const randomPwd = Math.random().toString(36).slice(-8) + "!TW";
                        setNewMemberPassword(randomPwd);
                      }}
                    >
                      Generate Secure Password
                    </button>
                  </div>
                  <input 
                    type="text" 
                    placeholder="Enter or generate password" 
                    value={newMemberPassword}
                    onChange={(e) => setNewMemberPassword(e.target.value)}
                    required
                  />
                </div>
              </div>

              <div className="modal-actions">
                <button 
                  type="button"
                  className="btn-cancel"
                  onClick={() => setShowAddMemberModal(false)}
                >
                  Cancel
                </button>
                <button 
                  type="submit" 
                  className="btn-primary"
                  style={{ display: "inline-flex", alignItems: "center", gap: "6px" }}
                >
                  <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="#ffffff" strokeWidth="2">
                    <polyline points="20 6 9 17 4 12"/>
                  </svg>
                  <span>Create & Save Member</span>
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* Change Password Modal */}
      {showChangePasswordModal && (
        <div className="modal-overlay">
          <div className="modal-content glass" style={{ maxWidth: "420px" }}>
            <div className="modal-header">
              Change Administrator Password
            </div>
            <form onSubmit={handleChangePassword}>
              <div className="modal-body">
                <p style={{ color: "var(--text-secondary)", fontSize: "0.9rem", marginBottom: "16px" }}>
                  Updating password for <strong>{user?.email}</strong>.
                </p>

                <div className="form-group" style={{ marginBottom: "14px" }}>
                  <label>New Password</label>
                  <input 
                    type="password" 
                    placeholder="Enter new password" 
                    value={newPasswordInput}
                    onChange={(e) => setNewPasswordInput(e.target.value)}
                    required
                  />
                </div>

                <div className="form-group" style={{ marginBottom: "14px" }}>
                  <label>Confirm New Password</label>
                  <input 
                    type="password" 
                    placeholder="Re-enter new password" 
                    value={confirmPasswordInput}
                    onChange={(e) => setConfirmPasswordInput(e.target.value)}
                    required
                  />
                </div>
              </div>

              <div className="modal-actions">
                <button 
                  type="button"
                  className="btn-cancel"
                  onClick={() => setShowChangePasswordModal(false)}
                >
                  Cancel
                </button>
                <button 
                  type="submit" 
                  className="btn-primary"
                  style={{ display: "inline-flex", alignItems: "center", gap: "6px" }}
                >
                  <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="#ffffff" strokeWidth="2">
                    <polyline points="20 6 9 17 4 12"/>
                  </svg>
                  <span>Update Password</span>
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

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

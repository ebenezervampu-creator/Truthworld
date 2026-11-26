import React, { useState, useEffect } from "react";
import { db, functions } from "../firebase";
import { collection, query, limit, getDocs, doc, getDoc, updateDoc, setDoc, serverTimestamp } from "firebase/firestore";
import { httpsCallable } from "firebase/functions";

export default function DubbingAdminTab({ adminUser, isSuperAdmin }) {
  const [users, setUsers] = useState([]);
  const [filteredUsers, setFilteredUsers] = useState([]);
  const [selectedUser, setSelectedUser] = useState(null);
  const [wallet, setWallet] = useState(null);
  const [loading, setLoading] = useState(false);
  const [actionLoading, setActionLoading] = useState(false);
  const [searchQuery, setSearchQuery] = useState("");
  const [filterOption, setFilterOption] = useState("all");

  // Form states
  const [creditAmount, setCreditAmount] = useState(10000);
  const [bonusUsd, setBonusUsd] = useState(0);
  const [grantReason, setGrantReason] = useState("Creator Partnership Grant");
  const [discountType, setDiscountType] = useState("none");
  const [customDiscount, setCustomDiscount] = useState(20);
  const [discountReason, setDiscountReason] = useState("VIP Creator Agreement");
  const [applyToChannels, setApplyToChannels] = useState(true);
  const [feedbackMsg, setFeedbackMsg] = useState(null);

  // 1. Fetch users and wallets
  const fetchDubbingUsers = async () => {
    setLoading(true);
    try {
      const usersSnap = await getDocs(query(collection(db, "users"), limit(100)));
      const walletsSnap = await getDocs(query(collection(db, "dubbing_wallets"), limit(150)));
      const walletMap = {};
      walletsSnap.forEach((d) => {
        walletMap[d.id] = d.data();
      });

      const list = [];
      usersSnap.forEach((d) => {
        const u = d.data();
        const uid = d.id;
        const w = walletMap[uid];

        const displayName = u.displayName || u.name || u.username || (u.email ? u.email.split("@")[0] : `User ${uid.slice(0, 6)}`);
        const balanceCredits = w?.balanceCredits || 0;
        const balanceUsd = w?.balanceUsd || 0.0;
        const totalUsed = w?.totalCharactersUsed || 0;
        const specialDiscountPercent = w?.specialDiscountPercent || u.dubbingDiscountPercent || 0;
        const specialDiscountType = w?.specialDiscountType || u.dubbingDiscountType || "none";
        const isFree = w?.isDubbingFree || u.isDubbingFree || specialDiscountType === "free" || specialDiscountPercent >= 100;

        list.push({
          id: uid,
          uid,
          displayName,
          email: u.email || "",
          photoURL: u.photoURL || u.avatarUrl || "",
          balanceCredits,
          balanceUsd,
          totalUsed,
          specialDiscountPercent,
          specialDiscountType,
          isDubbingFree: isFree,
          discountReason: w?.discountReason || u.dubbingDiscountReason || "",
        });
      });

      list.sort((a, b) => {
        if (a.isDubbingFree && !b.isDubbingFree) return -1;
        if (b.isDubbingFree && !a.isDubbingFree) return 1;
        if (a.specialDiscountPercent !== b.specialDiscountPercent) return b.specialDiscountPercent - a.specialDiscountPercent;
        return b.balanceCredits - a.balanceCredits;
      });

      setUsers(list);
      setFilteredUsers(list);
      if (list.length > 0 && !selectedUser) {
        selectUser(list[0]);
      }
    } catch (err) {
      console.error("Failed to fetch dubbing users", err);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchDubbingUsers();
  }, []);

  // 2. Filter & Search
  useEffect(() => {
    let result = [...users];

    if (filterOption === "with_discount") {
      result = result.filter((u) => u.isDubbingFree || u.specialDiscountPercent > 0);
    } else if (filterOption === "free_waiver") {
      result = result.filter((u) => u.isDubbingFree);
    } else if (filterOption === "with_credits") {
      result = result.filter((u) => u.balanceCredits > 0);
    } else if (filterOption === "zero_credits") {
      result = result.filter((u) => u.balanceCredits === 0);
    }

    if (searchQuery.trim()) {
      const q = searchQuery.toLowerCase();
      result = result.filter(
        (u) =>
          u.displayName.toLowerCase().includes(q) ||
          u.email.toLowerCase().includes(q) ||
          u.id.toLowerCase().includes(q)
      );
    }

    setFilteredUsers(result);
  }, [users, filterOption, searchQuery]);

  // 3. Select User & Load Wallet Details
  const selectUser = async (u) => {
    setSelectedUser(u);
    setDiscountType(u.specialDiscountType || (u.isDubbingFree ? "free" : u.specialDiscountPercent > 0 ? "percent" : "none"));
    setCustomDiscount(u.specialDiscountPercent || 20);
    setDiscountReason(u.discountReason || "VIP Creator Agreement");
    setFeedbackMsg(null);

    try {
      const wDoc = await getDoc(doc(db, "dubbing_wallets", u.id));
      if (wDoc.exists()) {
        setWallet(wDoc.data());
      } else {
        setWallet({
          userId: u.id,
          balanceCredits: u.balanceCredits,
          balanceUsd: u.balanceUsd,
          transactions: [],
        });
      }
    } catch (e) {
      console.warn("Wallet fetch notice", e);
    }
  };

  // 4. Grant Credits Action
  const handleGrantCredits = async () => {
    if (!selectedUser) return;
    setActionLoading(true);
    setFeedbackMsg(null);

    try {
      const callGrant = httpsCallable(functions, "adminGrantDubbingCredits");
      const res = await callGrant({
        targetUserId: selectedUser.id,
        amountCredits: Number(creditAmount),
        amountUsd: Number(bonusUsd || 0),
        reason: grantReason,
        mode: "add",
      });

      setFeedbackMsg({
        type: "success",
        text: `Granted ${Number(creditAmount).toLocaleString()} credits to ${selectedUser.displayName}!`,
      });

      // Refresh wallet & list
      fetchDubbingUsers();
      selectUser(selectedUser);
    } catch (err) {
      console.error("Grant error", err);
      // Client-side fallback if callable error
      try {
        const now = Date.now();
        const wRef = doc(db, "dubbing_wallets", selectedUser.id);
        const wSnap = await getDoc(wRef);
        const existing = wSnap.exists() ? wSnap.data() : {};
        const newCredits = (existing.balanceCredits || 0) + Number(creditAmount);
        const newUsd = Math.round(((existing.balanceUsd || 0) + Number(bonusUsd || 0)) * 100) / 100;

        const tx = {
          id: `tx_admin_${now}`,
          type: "trial_credit",
          amountCredits: Number(creditAmount),
          amountUsd: Number(bonusUsd || 0),
          description: `Admin Grant: ${grantReason}`,
          timestamp: now,
        };

        await setDoc(
          wRef,
          {
            userId: selectedUser.id,
            balanceCredits: newCredits,
            balanceUsd: newUsd,
            transactions: [tx, ...(existing.transactions || [])],
            updatedAt: now,
          },
          { merge: true }
        );

        setFeedbackMsg({
          type: "success",
          text: `Granted ${Number(creditAmount).toLocaleString()} credits directly to ${selectedUser.displayName}.`,
        });
        fetchDubbingUsers();
        selectUser(selectedUser);
      } catch (fallbackErr) {
        setFeedbackMsg({ type: "error", text: "Failed to grant credits. Please check connection." });
      }
    } finally {
      setActionLoading(false);
    }
  };

  // 5. Update Discount Action
  const handleUpdateDiscount = async () => {
    if (!selectedUser) return;
    setActionLoading(true);
    setFeedbackMsg(null);

    let percent = 0;
    if (discountType === "free") percent = 100;
    else if (discountType === "none") percent = 0;
    else percent = Number(customDiscount || 20);

    const isFree = discountType === "free" || percent >= 100;

    try {
      const callDiscount = httpsCallable(functions, "adminSetDubbingDiscount");
      await callDiscount({
        targetUserId: selectedUser.id,
        discountPercent: percent,
        discountType,
        reason: discountReason,
        applyToChannels,
      });

      setFeedbackMsg({
        type: "success",
        text: isFree
          ? "100% Free Dubbing Waiver activated!"
          : percent > 0
          ? `${percent}% Special Dubbing Discount activated.`
          : "Dubbing discount reset to standard rate.",
      });

      fetchDubbingUsers();
      selectUser(selectedUser);
    } catch (err) {
      console.error("Discount update error", err);
      // Direct Firestore fallback
      try {
        const now = Date.now();
        await setDoc(
          doc(db, "dubbing_wallets", selectedUser.id),
          {
            specialDiscountPercent: percent,
            specialDiscountType: discountType,
            isDubbingFree: isFree,
            discountReason,
            updatedAt: now,
          },
          { merge: true }
        );
        await setDoc(
          doc(db, "users", selectedUser.id),
          {
            dubbingDiscountPercent: percent,
            dubbingDiscountType: discountType,
            isDubbingFree: isFree,
            dubbingDiscountReason: discountReason,
          },
          { merge: true }
        );

        setFeedbackMsg({
          type: "success",
          text: isFree ? "100% Free Waiver set." : `${percent}% Discount set.`,
        });
        fetchDubbingUsers();
        selectUser(selectedUser);
      } catch (fallbackErr) {
        setFeedbackMsg({ type: "error", text: "Failed to update discount." });
      }
    } finally {
      setActionLoading(false);
    }
  };

  return (
    <div style={{ display: "grid", gridTemplateColumns: "380px 1fr", gap: "20px", minHeight: "650px" }}>
      {/* LEFT: USER LIST */}
      <div className="glass" style={{ padding: "16px", borderRadius: "12px", display: "flex", flexDirection: "column", height: "calc(100vh - 120px)" }}>
        <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between", marginBottom: "12px" }}>
          <div>
            <h3 style={{ margin: 0, fontSize: "16px", color: "#fff", fontWeight: "bold" }}>Dubbing Accounts</h3>
            <span style={{ fontSize: "12px", color: "rgba(255,255,255,0.6)" }}>
              {filteredUsers.length} of {users.length} accounts
            </span>
          </div>
          <button
            onClick={fetchDubbingUsers}
            style={{ background: "rgba(255,255,255,0.08)", border: "none", color: "#fff", padding: "6px 10px", borderRadius: "6px", cursor: "pointer", fontSize: "12px" }}
          >
            Refresh
          </button>
        </div>

        {/* Search */}
        <input
          type="text"
          placeholder="Search by name, email, UID..."
          value={searchQuery}
          onChange={(e) => setSearchQuery(e.target.value)}
          style={{
            width: "100%",
            padding: "8px 12px",
            background: "rgba(255,255,255,0.05)",
            border: "1px solid rgba(255,255,255,0.1)",
            borderRadius: "8px",
            color: "#fff",
            fontSize: "13px",
            marginBottom: "10px",
            boxSizing: "border-box",
          }}
        />

        {/* Filters */}
        <div style={{ display: "flex", gap: "6px", overflowX: "auto", paddingBottom: "8px", marginBottom: "8px" }}>
          {[
            { id: "all", label: "All" },
            { id: "with_discount", label: "Discounts" },
            { id: "free_waiver", label: "100% Free" },
            { id: "with_credits", label: "With Credits" },
          ].map((f) => (
            <button
              key={f.id}
              onClick={() => setFilterOption(f.id)}
              style={{
                background: filterOption === f.id ? "rgba(255,255,255,0.2)" : "transparent",
                border: "1px solid rgba(255,255,255,0.1)",
                color: filterOption === f.id ? "#fff" : "rgba(255,255,255,0.6)",
                padding: "4px 8px",
                borderRadius: "12px",
                fontSize: "11px",
                cursor: "pointer",
                whiteSpace: "nowrap",
              }}
            >
              {f.label}
            </button>
          ))}
        </div>

        {/* List */}
        <div style={{ flex: 1, overflowY: "auto", display: "flex", flexDirection: "column", gap: "8px" }}>
          {loading ? (
            <div style={{ textAlign: "center", padding: "30px", color: "rgba(255,255,255,0.5)" }}>Loading accounts...</div>
          ) : filteredUsers.length === 0 ? (
            <div style={{ textAlign: "center", padding: "30px", color: "rgba(255,255,255,0.5)" }}>No accounts matched.</div>
          ) : (
            filteredUsers.map((u) => {
              const isSelected = selectedUser?.id === u.id;
              return (
                <div
                  key={u.id}
                  onClick={() => selectUser(u)}
                  style={{
                    padding: "10px 12px",
                    borderRadius: "8px",
                    background: isSelected ? "rgba(255,255,255,0.15)" : "rgba(255,255,255,0.03)",
                    border: `1px solid ${isSelected ? "rgba(255,255,255,0.4)" : "rgba(255,255,255,0.06)"}`,
                    cursor: "pointer",
                    transition: "all 0.15s ease",
                  }}
                >
                  <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between", marginBottom: "4px" }}>
                    <div style={{ fontWeight: "bold", fontSize: "13px", color: "#fff", overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap" }}>
                      {u.displayName}
                    </div>
                    {u.isDubbingFree ? (
                      <span style={{ fontSize: "9px", background: "rgba(34,197,94,0.2)", color: "#4ade80", padding: "2px 5px", borderRadius: "4px", fontWeight: "bold" }}>
                        100% FREE
                      </span>
                    ) : u.specialDiscountPercent > 0 ? (
                      <span style={{ fontSize: "9px", background: "rgba(245,158,11,0.2)", color: "#fcd34d", padding: "2px 5px", borderRadius: "4px", fontWeight: "bold" }}>
                        {u.specialDiscountPercent}% OFF
                      </span>
                    ) : null}
                  </div>
                  <div style={{ fontSize: "11px", color: "rgba(255,255,255,0.6)", marginBottom: "6px", overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap" }}>
                    {u.email || u.id}
                  </div>
                  <div style={{ display: "flex", gap: "6px" }}>
                    <span style={{ fontSize: "11px", background: "rgba(255,255,255,0.06)", padding: "2px 6px", borderRadius: "4px", color: "#fff" }}>
                      {u.balanceCredits.toLocaleString()} chars
                    </span>
                    {u.balanceUsd > 0 && (
                      <span style={{ fontSize: "11px", background: "rgba(255,255,255,0.06)", padding: "2px 6px", borderRadius: "4px", color: "rgba(255,255,255,0.8)" }}>
                        ${u.balanceUsd.toFixed(2)}
                      </span>
                    )}
                  </div>
                </div>
              );
            })
          )}
        </div>
      </div>

      {/* RIGHT: DETAIL & CONTROLS */}
      <div style={{ overflowY: "auto", maxHeight: "calc(100vh - 120px)", paddingRight: "8px" }}>
        {selectedUser ? (
          <div>
            {/* User Profile Header */}
            <div className="glass" style={{ padding: "18px", borderRadius: "12px", marginBottom: "16px", display: "flex", alignItems: "center", justifyContent: "space-between" }}>
              <div style={{ display: "flex", alignItems: "center", gap: "14px" }}>
                <div
                  style={{
                    width: "48px",
                    height: "48px",
                    borderRadius: "50%",
                    background: "rgba(255,255,255,0.1)",
                    display: "flex",
                    alignItems: "center",
                    justifyContent: "center",
                    fontSize: "20px",
                    fontWeight: "bold",
                    color: "#fff",
                  }}
                >
                  {selectedUser.photoURL ? (
                    <img src={selectedUser.photoURL} alt="" style={{ width: "100%", height: "100%", borderRadius: "50%" }} />
                  ) : (
                    selectedUser.displayName.slice(0, 1).toUpperCase()
                  )}
                </div>
                <div>
                  <h2 style={{ margin: "0 0 4px 0", fontSize: "18px", color: "#fff", fontWeight: "bold" }}>{selectedUser.displayName}</h2>
                  <div style={{ fontSize: "12px", color: "rgba(255,255,255,0.6)" }}>{selectedUser.email || "No email"} &bull; UID: {selectedUser.id}</div>
                </div>
              </div>
            </div>

            {/* Notification alert */}
            {feedbackMsg && (
              <div
                style={{
                  padding: "12px 16px",
                  borderRadius: "8px",
                  marginBottom: "16px",
                  background: feedbackMsg.type === "success" ? "rgba(34,197,94,0.15)" : "rgba(239,68,68,0.15)",
                  border: `1px solid ${feedbackMsg.type === "success" ? "#22c55e" : "#ef4444"}`,
                  color: "#fff",
                  fontSize: "13px",
                  fontWeight: "500",
                }}
              >
                {feedbackMsg.text}
              </div>
            )}

            {/* Metric Stats */}
            <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr 1fr", gap: "12px", marginBottom: "16px" }}>
              <div className="glass" style={{ padding: "14px", borderRadius: "10px" }}>
                <div style={{ fontSize: "10px", color: "rgba(255,255,255,0.5)", fontWeight: "bold", letterSpacing: "1px" }}>CREDIT BALANCE</div>
                <div style={{ fontSize: "18px", color: "#fff", fontWeight: "bold", margin: "6px 0 2px" }}>
                  {(wallet?.balanceCredits ?? selectedUser.balanceCredits).toLocaleString()} chars
                </div>
                <div style={{ fontSize: "11px", color: "rgba(255,255,255,0.6)" }}>${(wallet?.balanceUsd ?? selectedUser.balanceUsd).toFixed(2)} USD value</div>
              </div>
              <div className="glass" style={{ padding: "14px", borderRadius: "10px" }}>
                <div style={{ fontSize: "10px", color: "rgba(255,255,255,0.5)", fontWeight: "bold", letterSpacing: "1px" }}>LIFETIME CONSUMED</div>
                <div style={{ fontSize: "18px", color: "#fff", fontWeight: "bold", margin: "6px 0 2px" }}>
                  {(wallet?.totalCharactersUsed ?? selectedUser.totalUsed).toLocaleString()} chars
                </div>
                <div style={{ fontSize: "11px", color: "rgba(255,255,255,0.6)" }}>Synthesized speech</div>
              </div>
              <div className="glass" style={{ padding: "14px", borderRadius: "10px" }}>
                <div style={{ fontSize: "10px", color: "rgba(255,255,255,0.5)", fontWeight: "bold", letterSpacing: "1px" }}>SPECIAL DISCOUNT</div>
                <div style={{ fontSize: "18px", color: selectedUser.isDubbingFree ? "#4ade80" : selectedUser.specialDiscountPercent > 0 ? "#fcd34d" : "#fff", fontWeight: "bold", margin: "6px 0 2px" }}>
                  {selectedUser.isDubbingFree ? "100% FREE" : selectedUser.specialDiscountPercent > 0 ? `${selectedUser.specialDiscountPercent}% OFF` : "Standard (0%)"}
                </div>
                <div style={{ fontSize: "11px", color: "rgba(255,255,255,0.6)" }}>{selectedUser.isDubbingFree ? "Full Waiver Active" : selectedUser.specialDiscountPercent > 0 ? "Discounted Rate" : "Standard Rate"}</div>
              </div>
            </div>

            {/* ACTION 1: GRANT FREE CREDITS */}
            <div className="glass" style={{ padding: "18px", borderRadius: "12px", marginBottom: "16px" }}>
              <h3 style={{ margin: "0 0 6px 0", fontSize: "15px", color: "#fff", fontWeight: "bold" }}>Grant Free Dubbing Credits</h3>
              <p style={{ margin: "0 0 14px 0", fontSize: "12px", color: "rgba(255,255,255,0.6)" }}>
                Add complimentary speech synthesis characters directly to this user's wallet.
              </p>

              {/* Round Presets */}
              <div style={{ display: "flex", gap: "8px", flexWrap: "wrap", marginBottom: "14px" }}>
                {[5000, 10000, 25000, 50000, 100000].map((preset) => (
                  <button
                    key={preset}
                    onClick={() => setCreditAmount(preset)}
                    style={{
                      background: creditAmount === preset ? "rgba(255,255,255,0.2)" : "rgba(255,255,255,0.05)",
                      border: "1px solid rgba(255,255,255,0.15)",
                      color: "#fff",
                      padding: "6px 12px",
                      borderRadius: "6px",
                      cursor: "pointer",
                      fontSize: "12px",
                      fontWeight: "bold",
                    }}
                  >
                    +{preset.toLocaleString()} chars
                  </button>
                ))}
              </div>

              <div style={{ display: "grid", gridTemplateColumns: "2fr 1fr", gap: "12px", marginBottom: "12px" }}>
                <div>
                  <label style={{ display: "block", fontSize: "11px", color: "rgba(255,255,255,0.6)", marginBottom: "4px" }}>Character Amount</label>
                  <input
                    type="number"
                    value={creditAmount}
                    onChange={(e) => setCreditAmount(Number(e.target.value))}
                    style={{
                      width: "100%",
                      padding: "8px 12px",
                      background: "rgba(255,255,255,0.05)",
                      border: "1px solid rgba(255,255,255,0.1)",
                      borderRadius: "6px",
                      color: "#fff",
                      fontWeight: "bold",
                      boxSizing: "border-box",
                    }}
                  />
                </div>
                <div>
                  <label style={{ display: "block", fontSize: "11px", color: "rgba(255,255,255,0.6)", marginBottom: "4px" }}>Bonus USD ($)</label>
                  <input
                    type="number"
                    value={bonusUsd}
                    onChange={(e) => setBonusUsd(Number(e.target.value))}
                    style={{
                      width: "100%",
                      padding: "8px 12px",
                      background: "rgba(255,255,255,0.05)",
                      border: "1px solid rgba(255,255,255,0.1)",
                      borderRadius: "6px",
                      color: "#fff",
                      fontWeight: "bold",
                      boxSizing: "border-box",
                    }}
                  />
                </div>
              </div>

              <div style={{ marginBottom: "14px" }}>
                <label style={{ display: "block", fontSize: "11px", color: "rgba(255,255,255,0.6)", marginBottom: "4px" }}>Audit Reason / Memo</label>
                <input
                  type="text"
                  value={grantReason}
                  onChange={(e) => setGrantReason(e.target.value)}
                  placeholder="e.g. Creator Partnership Grant"
                  style={{
                    width: "100%",
                    padding: "8px 12px",
                    background: "rgba(255,255,255,0.05)",
                    border: "1px solid rgba(255,255,255,0.1)",
                    borderRadius: "6px",
                    color: "#fff",
                    boxSizing: "border-box",
                  }}
                />
              </div>

              <button
                disabled={actionLoading}
                onClick={handleGrantCredits}
                style={{
                  background: "#fff",
                  color: "#000",
                  border: "none",
                  padding: "10px 18px",
                  borderRadius: "6px",
                  fontWeight: "bold",
                  cursor: actionLoading ? "not-allowed" : "pointer",
                  fontSize: "13px",
                }}
              >
                {actionLoading ? "Processing..." : "Grant Free Credits"}
              </button>
            </div>

            {/* ACTION 2: SPECIAL DISCOUNTS & FREE WAIVER */}
            <div className="glass" style={{ padding: "18px", borderRadius: "12px", marginBottom: "16px" }}>
              <h3 style={{ margin: "0 0 6px 0", fontSize: "15px", color: "#fff", fontWeight: "bold" }}>Special Dubbing Discounts & Free Waiver</h3>
              <p style={{ margin: "0 0 14px 0", fontSize: "12px", color: "rgba(255,255,255,0.6)" }}>
                Configure persistent discounted pricing or a 100% free speech synthesis waiver.
              </p>

              {/* Tier options */}
              <div style={{ display: "flex", gap: "8px", flexWrap: "wrap", marginBottom: "14px" }}>
                {[
                  { id: "none", label: "Standard (0%)" },
                  { id: "20%", label: "20% Off", pct: 20 },
                  { id: "30%", label: "30% Off", pct: 30 },
                  { id: "50%", label: "50% Off", pct: 50 },
                  { id: "free", label: "100% Free Waiver", pct: 100, isFree: true },
                  { id: "custom", label: "Custom %" },
                ].map((tier) => (
                  <button
                    key={tier.id}
                    onClick={() => {
                      setDiscountType(tier.id);
                      if (tier.pct !== undefined) setCustomDiscount(tier.pct);
                    }}
                    style={{
                      background:
                        discountType === tier.id
                          ? tier.isFree
                            ? "rgba(34,197,94,0.3)"
                            : "rgba(255,255,255,0.2)"
                          : "rgba(255,255,255,0.04)",
                      border: `1px solid ${discountType === tier.id ? (tier.isFree ? "#22c55e" : "#fff") : "rgba(255,255,255,0.1)"}`,
                      color: "#fff",
                      padding: "6px 12px",
                      borderRadius: "6px",
                      cursor: "pointer",
                      fontSize: "12px",
                      fontWeight: discountType === tier.id ? "bold" : "normal",
                    }}
                  >
                    {tier.label}
                  </button>
                ))}
              </div>

              {discountType === "custom" && (
                <div style={{ marginBottom: "12px" }}>
                  <label style={{ display: "block", fontSize: "11px", color: "rgba(255,255,255,0.6)", marginBottom: "4px" }}>Custom Discount Percent (%)</label>
                  <input
                    type="number"
                    min="1"
                    max="99"
                    value={customDiscount}
                    onChange={(e) => setCustomDiscount(Number(e.target.value))}
                    style={{
                      width: "120px",
                      padding: "8px 12px",
                      background: "rgba(255,255,255,0.05)",
                      border: "1px solid rgba(255,255,255,0.1)",
                      borderRadius: "6px",
                      color: "#fff",
                      fontWeight: "bold",
                    }}
                  />
                </div>
              )}

              <div style={{ display: "flex", alignItems: "center", gap: "8px", marginBottom: "14px" }}>
                <input
                  type="checkbox"
                  id="applyCh"
                  checked={applyToChannels}
                  onChange={(e) => setApplyToChannels(e.target.checked)}
                />
                <label htmlFor="applyCh" style={{ fontSize: "12px", color: "rgba(255,255,255,0.8)", cursor: "pointer" }}>
                  Apply discount to user's creator channels (Video AI Dubbing)
                </label>
              </div>

              <div style={{ marginBottom: "14px" }}>
                <label style={{ display: "block", fontSize: "11px", color: "rgba(255,255,255,0.6)", marginBottom: "4px" }}>Audit Reason</label>
                <input
                  type="text"
                  value={discountReason}
                  onChange={(e) => setDiscountReason(e.target.value)}
                  placeholder="e.g. VIP Creator Agreement"
                  style={{
                    width: "100%",
                    padding: "8px 12px",
                    background: "rgba(255,255,255,0.05)",
                    border: "1px solid rgba(255,255,255,0.1)",
                    borderRadius: "6px",
                    color: "#fff",
                    boxSizing: "border-box",
                  }}
                />
              </div>

              <button
                disabled={actionLoading}
                onClick={handleUpdateDiscount}
                style={{
                  background: "#fff",
                  color: "#000",
                  border: "none",
                  padding: "10px 18px",
                  borderRadius: "6px",
                  fontWeight: "bold",
                  cursor: actionLoading ? "not-allowed" : "pointer",
                  fontSize: "13px",
                }}
              >
                {actionLoading ? "Saving..." : "Save Special Discount"}
              </button>
            </div>

            {/* ACTION 3: WALLET LEDGER */}
            <div className="glass" style={{ padding: "18px", borderRadius: "12px" }}>
              <h3 style={{ margin: "0 0 10px 0", fontSize: "15px", color: "#fff", fontWeight: "bold" }}>Wallet Activity Ledger</h3>
              {wallet?.transactions && wallet.transactions.length > 0 ? (
                <div style={{ display: "flex", flexDirection: "column", gap: "10px" }}>
                  {wallet.transactions.slice(0, 8).map((tx, idx) => {
                    const isGrant = tx.type === "trial_credit" || tx.type === "topup";
                    return (
                      <div
                        key={idx}
                        style={{
                          display: "flex",
                          alignItems: "center",
                          justifyContent: "space-between",
                          padding: "8px 0",
                          borderBottom: "1px solid rgba(255,255,255,0.06)",
                        }}
                      >
                        <div>
                          <div style={{ fontSize: "13px", color: "#fff", fontWeight: "500" }}>{tx.description || tx.type}</div>
                          <div style={{ fontSize: "11px", color: "rgba(255,255,255,0.5)" }}>
                            {new Date(tx.timestamp).toLocaleString()}
                          </div>
                        </div>
                        <div style={{ textAlign: "right" }}>
                          <div style={{ fontSize: "13px", color: isGrant ? "#4ade80" : "rgba(255,255,255,0.7)", fontWeight: "bold" }}>
                            {isGrant ? "+" : "-"}{Number(tx.amountCredits || 0).toLocaleString()} chars
                          </div>
                          {tx.amountUsd > 0 && <div style={{ fontSize: "11px", color: "rgba(255,255,255,0.5)" }}>${tx.amountUsd.toFixed(2)}</div>}
                        </div>
                      </div>
                    );
                  })}
                </div>
              ) : (
                <div style={{ fontSize: "12px", color: "rgba(255,255,255,0.5)", padding: "10px 0" }}>No transactions recorded yet.</div>
              )}
            </div>
          </div>
        ) : (
          <div style={{ textAlign: "center", padding: "60px 20px", color: "rgba(255,255,255,0.5)" }}>
            Select an account from the list to view dubbing controls.
          </div>
        )}
      </div>
    </div>
  );
}

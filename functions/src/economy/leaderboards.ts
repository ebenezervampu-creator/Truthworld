import * as admin from "firebase-admin";

export function sanitizePublicChannel(d: admin.firestore.QueryDocumentSnapshot, rank: number) {
  const data = d.data();
  return {
    id: d.id,
    rank,
    displayName: data.displayName || data.name || "",
    handle: data.handle || data.slug || "",
    photoUrl: data.profile?.photoUrl || data.photoUrl || data.avatarUrl || "",
    tier: data.tier || "standard",
    category: data.profile?.category || data.category || "General",
    subscriberCount: data.stats?.subscriberCount || data.subscriberCount || 0,
    videosCount: data.stats?.videosCount || data.videoCount || 0,
    isVerified: data.isVerified === true || data.verification === "verified" || data.verification === "elite",
  };
}

export function isPublicActive(d: admin.firestore.QueryDocumentSnapshot): boolean {
  const status = d.data()?.status;
  return status !== "suspended" && status !== "banned" && status !== "deleted";
}

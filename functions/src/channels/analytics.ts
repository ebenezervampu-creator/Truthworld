import * as admin from "firebase-admin";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { logger } from "firebase-functions/v2";
import { TYPE_REVENUE_SHARE } from "../economy/types";


const db = () => admin.firestore();
const REGION = "asia-south1";

// =============================================================================
// TYPES
// =============================================================================

interface ChannelOverviewStats {
  totalViews: number;
  totalWatchTimeSeconds: number;
  uniqueViewers: number;
  subscribersCount: number;
  totalRevenue: number;
  viewsChangePercent: number;
  watchtimeChangePercent: number;
  subscribersChangePercent: number;
  revenueChangePercent: number;
}

interface ViewsBreakdown {
  totalViews: number;
  uniqueViewers: number;
  bouncedUnder20s: number;
  watched25Percent: number;
  watched50Percent: number;
  watched75Percent: number;
  watched100Percent: number;
  subscriberViews: number;
  nonSubscriberViews: number;
  returningViewers: number;
  newViewers: number;
}

interface GeographicData {
  states: { name: string; views: number; watchTimeSeconds: number; percentage: number }[];
  cities: { name: string; state: string; views: number; watchTimeSeconds: number; percentage: number }[];
}

interface WatchtimeBreakdown {
  totalWatchTimeSeconds: number;
  averageWatchDuration: number;
  totalViews: number;
  byGeography: GeographicData;
  byDevice: { device: string; watchTimeSeconds: number; percentage: number }[];
}

interface SubscriberInfo {
  userId: string;
  displayName: string;
  avatarUrl: string;
  subscribedAt: number;
  state?: string;
  city?: string;
  isActive: boolean;
}

interface RevenueDetails {
  currentTier: string;
  tierLabel: string;
  monetizationStatus: string;
  monetizationDate?: number;
  adsRevenueShare: number;
  membersRevenueShare: number;
  totalRevenue: number;
  pendingRevenue: number;
  lifetimeRevenue: number;
  monthlyEstimates: {
    month: string;
    grossRevenue: number;
    creatorShare: number;
    views: number;
    rpm: number;
  }[];
  requirements: {
    minSubscribersForMonetization: number;
    minWatchHours: number;
    currentSubscribers: number;
    currentWatchHours: number;
    eligibleForMonetization: boolean;
  };
}

// =============================================================================
// CLOUD FUNCTION 1: Get Channel Overview Stats
// =============================================================================

export const getChannelOverview = onCall(
  {
    region: REGION,
    memory: "256MiB",
    maxInstances: 50,
  },
  async (request) => {
    const userId = request.auth?.uid;
    if (!userId) {
      throw new HttpsError("unauthenticated", "User must be logged in.");
    }

    const { channelId } = request.data;
    if (!channelId) {
      throw new HttpsError("invalid-argument", "Missing channelId.");
    }

    try {
      // Verify channel ownership
      const channelRef = db().collection("channels").doc(channelId);
      const channelSnap = await channelRef.get();
      
      if (!channelSnap.exists) {
        throw new HttpsError("not-found", "Channel not found.");
      }

      const channelData = channelSnap.data()!;
      if (channelData.ownerId !== userId) {
        throw new HttpsError("permission-denied", "Not authorized to view this channel's analytics.");
      }

      // Get last 28 days stats
      const now = new Date();
      
      const currentPeriodStart = new Date(now);
      currentPeriodStart.setDate(currentPeriodStart.getDate() - 28);
      
      const previousPeriodStart = new Date(currentPeriodStart);
      previousPeriodStart.setDate(previousPeriodStart.getDate() - 28);

      // Fetch current period stats
      const currentStats = await _getPeriodStats(channelId, currentPeriodStart, now);
      const previousStats = await _getPeriodStats(channelId, previousPeriodStart, currentPeriodStart);

      // Calculate changes
      const calcChange = (current: number, previous: number) => 
        previous > 0 ? ((current - previous) / previous) * 100 : 0;

      // Get subscriber count from channel document
      const subscribersCount = channelData.stats?.subscribersCount || 0;
      const prevSubscribers = channelData.stats?.subscribersCount28DaysAgo || subscribersCount;

      // Fetch authentic revenue from revenue_statements
      const revenueSnap = await db()
        .collection("revenue_statements")
        .where("userId", "==", userId)
        .where("channelId", "==", channelId)
        .orderBy("month", "desc")
        .limit(2)
        .get();

      const currentRevenue = revenueSnap.empty ? 0 : (revenueSnap.docs[0].data().creatorShare || 0);
      const prevRevenue = revenueSnap.docs.length > 1 ? (revenueSnap.docs[1].data().creatorShare || 0) : 0;

      const overview: ChannelOverviewStats = {
        totalViews: currentStats.views,
        totalWatchTimeSeconds: currentStats.watchTime,
        uniqueViewers: currentStats.uniqueViewers,
        subscribersCount,
        totalRevenue: currentRevenue,
        viewsChangePercent: calcChange(currentStats.views, previousStats.views),
        watchtimeChangePercent: calcChange(currentStats.watchTime, previousStats.watchTime),
        subscribersChangePercent: calcChange(subscribersCount, prevSubscribers),
        revenueChangePercent: calcChange(currentRevenue, prevRevenue),
      };

      return { success: true, overview };
    } catch (err) {
      if (err instanceof HttpsError) throw err;
      logger.error("[getChannelOverview] Error:", err);
      throw new HttpsError("internal", "Failed to fetch channel overview.");
    }
  }
);

// =============================================================================
// CLOUD FUNCTION 2: Get Detailed Views Breakdown
// =============================================================================

export const getChannelViewsDetails = onCall(
  {
    region: REGION,
    memory: "512MiB",
    maxInstances: 50,
  },
  async (request) => {
    const userId = request.auth?.uid;
    if (!userId) {
      throw new HttpsError("unauthenticated", "User must be logged in.");
    }

    const { channelId, days = 28 } = request.data;
    if (!channelId) {
      throw new HttpsError("invalid-argument", "Missing channelId.");
    }

    try {
      // Verify ownership
      const channelRef = db().collection("channels").doc(channelId);
      const channelSnap = await channelRef.get();
      
      if (!channelSnap.exists || channelSnap.data()?.ownerId !== userId) {
        throw new HttpsError("permission-denied", "Not authorized.");
      }

      const now = new Date();
      const startDate = new Date(now);
      startDate.setDate(startDate.getDate() - days);

      // Aggregate from video_stats_daily for this channel
      const dateFormat = (d: Date) => `${d.getFullYear()}_${String(d.getMonth() + 1).padStart(2, '0')}_${String(d.getDate()).padStart(2, '0')}`;
      const startKey = dateFormat(startDate);
      const endKey = dateFormat(now);

      const dailyStats = await db()
        .collection("video_stats_daily")
        .where("channelId", "==", channelId)
        .where("dateKey", ">=", startKey)
        .where("dateKey", "<=", endKey)
        .get();

      // Aggregate stats
      let totalViews = 0;
      let uniqueViewers = 0;
      let bounced = 0;
      let w25 = 0;
      let w50 = 0;
      let w75 = 0;
      let w100 = 0;
      let subViews = 0;
      let nonSubViews = 0;
      let returning = 0;
      let newViewers = 0;

      const stateMap = new Map<string, { views: number; watchTime: number }>();
      const cityMap = new Map<string, { views: number; watchTime: number; state: string }>();

      for (const doc of dailyStats.docs) {
        const d = doc.data();
        totalViews += d.totalViews || d.views || 0;
        uniqueViewers += d.uniqueViewers || 0;
        bounced += d.bouncedUnder20s || 0;
        w25 += d.watched25Percent || 0;
        w50 += d.watched50Percent || 0;
        w75 += d.watched75Percent || 0;
        w100 += d.watched100Percent || 0;
        subViews += d.subscriberViews || 0;
        nonSubViews += d.nonSubscriberViews || 0;
        returning += d.returningViewers || 0;
        newViewers += d.newViewers || 0;

        // Geographic aggregation
        const stateTraffic: Record<string, number> = d.stateTraffic || {};
        const cityTraffic: Record<string, number> = d.cityTraffic || {};

        for (const [state, count] of Object.entries(stateTraffic)) {
          const existing = stateMap.get(state) || { views: 0, watchTime: 0 };
          existing.views += count;
          stateMap.set(state, existing);
        }

        for (const [city, count] of Object.entries(cityTraffic)) {
          // Try to find state from stateTraffic (assume city is in the state with most views)
          const stateForCity = Object.entries(stateTraffic)
            .sort((a, b) => b[1] - a[1])[0]?.[0] || "Unknown";
          const existing = cityMap.get(city) || { views: 0, watchTime: 0, state: stateForCity };
          existing.views += count;
          cityMap.set(city, existing);
        }
      }

      const viewsBreakdown: ViewsBreakdown = {
        totalViews,
        uniqueViewers,
        bouncedUnder20s: bounced,
        watched25Percent: w25,
        watched50Percent: w50,
        watched75Percent: w75,
        watched100Percent: w100,
        subscriberViews: subViews,
        nonSubscriberViews: nonSubViews,
        returningViewers: returning,
        newViewers,
      };

      // Build geographic data
      const states: GeographicData["states"] = Array.from(stateMap.entries())
        .map(([name, data]) => ({
          name,
          views: data.views,
          watchTimeSeconds: data.watchTime,
          percentage: totalViews > 0 ? (data.views / totalViews) * 100 : 0,
        }))
        .sort((a, b) => b.views - a.views);

      const cities: GeographicData["cities"] = Array.from(cityMap.entries())
        .map(([name, data]) => ({
          name,
          state: data.state,
          views: data.views,
          watchTimeSeconds: data.watchTime,
          percentage: totalViews > 0 ? (data.views / totalViews) * 100 : 0,
        }))
        .sort((a, b) => b.views - a.views)
        .slice(0, 50);

      const geographicData: GeographicData = { states, cities };

      return { 
        success: true, 
        views: viewsBreakdown, 
        geographicData,
        period: { days, startDate: startDate.toISOString(), endDate: now.toISOString() }
      };
    } catch (err) {
      if (err instanceof HttpsError) throw err;
      logger.error("[getChannelViewsDetails] Error:", err);
      throw new HttpsError("internal", "Failed to fetch views details.");
    }
  }
);

// =============================================================================
// CLOUD FUNCTION 3: Get Detailed Watchtime Breakdown
// =============================================================================

export const getChannelWatchtimeDetails = onCall(
  {
    region: REGION,
    memory: "512MiB",
    maxInstances: 50,
  },
  async (request) => {
    const userId = request.auth?.uid;
    if (!userId) {
      throw new HttpsError("unauthenticated", "User must be logged in.");
    }

    const { channelId, days = 28 } = request.data;
    if (!channelId) {
      throw new HttpsError("invalid-argument", "Missing channelId.");
    }

    try {
      // Verify ownership
      const channelRef = db().collection("channels").doc(channelId);
      const channelSnap = await channelRef.get();
      
      if (!channelSnap.exists || channelSnap.data()?.ownerId !== userId) {
        throw new HttpsError("permission-denied", "Not authorized.");
      }

      const now = new Date();
      const startDate = new Date(now);
      startDate.setDate(startDate.getDate() - days);

      const dateFormat = (d: Date) => `${d.getFullYear()}_${String(d.getMonth() + 1).padStart(2, '0')}_${String(d.getDate()).padStart(2, '0')}`;
      const startKey = dateFormat(startDate);
      const endKey = dateFormat(now);

      const dailyStats = await db()
        .collection("video_stats_daily")
        .where("channelId", "==", channelId)
        .where("dateKey", ">=", startKey)
        .where("dateKey", "<=", endKey)
        .get();

      let totalWatchTime = 0;
      let totalViews = 0;
      const stateMap = new Map<string, number>();
      const cityMap = new Map<string, { watchTime: number; state: string }>();
      const deviceMap = new Map<string, number>();

      for (const doc of dailyStats.docs) {
        const d = doc.data();
        totalWatchTime += d.totalWatchTimeSeconds || d.totalWatchSeconds || 0;
        totalViews += d.totalViews || d.views || 0;

        const stateTraffic: Record<string, number> = d.stateTraffic || {};
        const cityTraffic: Record<string, number> = d.cityTraffic || {};
        const deviceBreakdown: Record<string, number> = d.deviceBreakdown || {};

        for (const [state, count] of Object.entries(stateTraffic)) {
          stateMap.set(state, (stateMap.get(state) || 0) + count);
        }

        for (const [city, count] of Object.entries(cityTraffic)) {
          const stateForCity = Object.entries(stateTraffic)
            .sort((a, b) => b[1] - a[1])[0]?.[0] || "Unknown";
          const existing = cityMap.get(city) || { watchTime: 0, state: stateForCity };
          existing.watchTime += count;
          cityMap.set(city, existing);
        }

        for (const [device, count] of Object.entries(deviceBreakdown)) {
          deviceMap.set(device, (deviceMap.get(device) || 0) + count);
        }
      }

      const avgWatchDuration = totalViews > 0 ? totalWatchTime / totalViews : 0;

      // Build geographic breakdown by watchtime
      const states = Array.from(stateMap.entries())
        .map(([name, watchTime]) => ({
          name,
          views: watchTime,
          watchTimeSeconds: watchTime * 60, // Approximate
          percentage: totalWatchTime > 0 ? (watchTime * 60 / totalWatchTime) * 100 : 0,
        }))
        .sort((a, b) => b.watchTimeSeconds - a.watchTimeSeconds);

      const cities = Array.from(cityMap.entries())
        .map(([name, data]) => ({
          name,
          state: data.state,
          views: data.watchTime,
          watchTimeSeconds: data.watchTime * 60,
          percentage: totalWatchTime > 0 ? (data.watchTime * 60 / totalWatchTime) * 100 : 0,
        }))
        .sort((a, b) => b.watchTimeSeconds - a.watchTimeSeconds)
        .slice(0, 50);

      const byDevice = Array.from(deviceMap.entries())
        .map(([device, count]) => ({
          device,
          watchTimeSeconds: count * 60,
          percentage: totalWatchTime > 0 ? (count * 60 / totalWatchTime) * 100 : 0,
        }))
        .sort((a, b) => b.watchTimeSeconds - a.watchTimeSeconds);

      const watchtimeBreakdown: WatchtimeBreakdown = {
        totalWatchTimeSeconds: totalWatchTime,
        averageWatchDuration: avgWatchDuration,
        totalViews,
        byGeography: { states, cities },
        byDevice,
      };

      return { 
        success: true, 
        watchtime: watchtimeBreakdown,
        period: { days, startDate: startDate.toISOString(), endDate: now.toISOString() }
      };
    } catch (err) {
      if (err instanceof HttpsError) throw err;
      logger.error("[getChannelWatchtimeDetails] Error:", err);
      throw new HttpsError("internal", "Failed to fetch watchtime details.");
    }
  }
);

// =============================================================================
// CLOUD FUNCTION 4: Get Channel Subscribers List
// =============================================================================

export const getChannelSubscribers = onCall(
  {
    region: REGION,
    memory: "512MiB",
    maxInstances: 50,
  },
  async (request) => {
    const userId = request.auth?.uid;
    if (!userId) {
      throw new HttpsError("unauthenticated", "User must be logged in.");
    }

    const { channelId, limit = 50, lastUserId } = request.data;
    if (!channelId) {
      throw new HttpsError("invalid-argument", "Missing channelId.");
    }

    try {
      // Verify ownership
      const channelRef = db().collection("channels").doc(channelId);
      const channelSnap = await channelRef.get();
      
      if (!channelSnap.exists || channelSnap.data()?.ownerId !== userId) {
        throw new HttpsError("permission-denied", "Not authorized.");
      }

      // Query channel_subscribers collection
      let query = db()
        .collection("channel_subscribers")
        .where("channelId", "==", channelId)
        .orderBy("createdAt", "desc")
        .limit(limit);

      if (lastUserId) {
        const lastDoc = await db().collection("channel_subscribers").doc(`${channelId}_${lastUserId}`).get();
        if (lastDoc.exists) {
          query = query.startAfter(lastDoc);
        }
      }

      const subscribersSnap = await query.get();

      // Fetch user details for each subscriber
      const subscribers: SubscriberInfo[] = [];
      
      for (const doc of subscribersSnap.docs) {
        const data = doc.data();
        const subscriberUserId = data.userId;

        // Get user profile
        const userRef = db().collection("users").doc(subscriberUserId);
        const userSnap = await userRef.get();
        const userData = userSnap.exists ? userSnap.data() : null;

        // Try to get location from watch_sessions (most recent)
        const watchSession = await db()
          .collection("watch_sessions")
          .where("userId", "==", subscriberUserId)
          .orderBy("lastUpdated", "desc")
          .limit(1)
          .get();

        const locationData = watchSession.empty ? null : watchSession.docs[0].data();

        subscribers.push({
          userId: subscriberUserId,
          displayName: userData?.displayName || userData?.name || "Unknown User",
          avatarUrl: userData?.avatarUrl || userData?.photoURL || "",
          subscribedAt: data.createdAt,
          state: locationData?.state || "Unknown",
          city: locationData?.city || "Unknown",
          isActive: true, // Could check last activity
        });
      }

      // Get summary stats
      const totalSubscribers = channelSnap.data()?.stats?.subscribersCount || 0;

      return {
        success: true,
        subscribers,
        totalCount: totalSubscribers,
        hasMore: subscribers.length === limit,
        lastUserId: subscribers.length > 0 ? subscribers[subscribers.length - 1].userId : null,
      };
    } catch (err) {
      if (err instanceof HttpsError) throw err;
      logger.error("[getChannelSubscribers] Error:", err);
      throw new HttpsError("internal", "Failed to fetch subscribers.");
    }
  }
);

// =============================================================================
// CLOUD FUNCTION 5: Get Channel Revenue Details
// =============================================================================

export const getChannelRevenueDetails = onCall(
  {
    region: REGION,
    memory: "256MiB",
    maxInstances: 50,
  },
  async (request) => {
    const userId = request.auth?.uid;
    if (!userId) {
      throw new HttpsError("unauthenticated", "User must be logged in.");
    }

    const { channelId } = request.data;
    if (!channelId) {
      throw new HttpsError("invalid-argument", "Missing channelId.");
    }

    try {
      // Get channel data
      const channelRef = db().collection("channels").doc(channelId);
      const channelSnap = await channelRef.get();
      
      if (!channelSnap.exists) {
        throw new HttpsError("not-found", "Channel not found.");
      }

      const channelData = channelSnap.data()!;
      
      if (channelData.ownerId !== userId) {
        throw new HttpsError("permission-denied", "Not authorized.");
      }

      const type = channelData.type || channelData.channelType || "standard";
      const typeLabel = type.charAt(0).toUpperCase() + type.slice(1);


      // Get revenue share settings
      const adsShare = TYPE_REVENUE_SHARE[type as keyof typeof TYPE_REVENUE_SHARE]?.ads || 0.75;
      const membersShare = TYPE_REVENUE_SHARE[type as keyof typeof TYPE_REVENUE_SHARE]?.members || 0.75;


      // Fetch revenue statements
      const revenueSnap = await db()
        .collection("revenue_statements")
        .where("userId", "==", userId)
        .where("channelId", "==", channelId)
        .orderBy("month", "desc")
        .limit(6)
        .get();

      const monthlyEstimates = revenueSnap.docs.map(doc => {
        const d = doc.data();
        const totalViews = d.metadata?.totalViews || d.views || 0;
        const gross = d.grossAdsRevenue + d.grossSubsRevenue;
        const rpm = totalViews > 0 ? (gross / totalViews) * 1000 : 0;
        
        return {
          month: d.month,
          grossRevenue: gross,
          creatorShare: d.creatorShare,
          views: totalViews,
          rpm,
        };
      });

      // Calculate totals
      const lifetimeRevenue = monthlyEstimates.reduce((sum, m) => sum + m.creatorShare, 0);
      const pendingRevenue = monthlyEstimates.find(m => m.month === new Date().toISOString().slice(0, 7))?.creatorShare || 0;

      // Get watch hours for monetization eligibility
      const now = new Date();
      const yearAgo = new Date(now);
      yearAgo.setFullYear(yearAgo.getFullYear() - 1);

      const dateFormat = (d: Date) => `${d.getFullYear()}_${String(d.getMonth() + 1).padStart(2, '0')}_${String(d.getDate()).padStart(2, '0')}`;
      const startKey = dateFormat(yearAgo);
      const endKey = dateFormat(now);

      const yearlyStats = await db()
        .collection("channel_stats_daily")
        .where("channelId", "==", channelId)
        .where("dateKey", ">=", startKey)
        .where("dateKey", "<=", endKey)
        .get();

      const totalWatchHours = yearlyStats.docs.reduce((sum, doc) => {
        return sum + ((doc.data().totalWatchTimeSeconds || 0) / 3600);
      }, 0);

      const currentSubscribers = channelData.stats?.subscribersCount || 0;
      const monetizationRequirements = {
        minSubscribersForMonetization: 1000,
        minWatchHours: 4000,
        currentSubscribers,
        currentWatchHours: Math.round(totalWatchHours),
        eligibleForMonetization: currentSubscribers >= 1000 && totalWatchHours >= 4000,
      };

      // Determine monetization status
      let monetizationStatus = "not_eligible";
      let monetizationDate: number | undefined;

      if (monetizationRequirements.eligibleForMonetization) {
        monetizationStatus = channelData.settings?.adsEnabled ? "monetized" : "eligible_not_enabled";
        monetizationDate = channelData.settings?.monetizationEnabledAt;
      }

      const revenueDetails: RevenueDetails = {
        currentTier: type,
        tierLabel: typeLabel,
        monetizationStatus,
        monetizationDate,
        adsRevenueShare: adsShare,
        membersRevenueShare: membersShare,
        totalRevenue: pendingRevenue,
        pendingRevenue,
        lifetimeRevenue,
        monthlyEstimates,
        requirements: monetizationRequirements,
      };

      return { success: true, revenue: revenueDetails };
    } catch (err) {
      if (err instanceof HttpsError) throw err;
      logger.error("[getChannelRevenueDetails] Error:", err);
      throw new HttpsError("internal", "Failed to fetch revenue details.");
    }
  }
);

// =============================================================================
// HELPER FUNCTIONS
// =============================================================================

async function _getPeriodStats(channelId: string, start: Date, end: Date): Promise<{
  views: number;
  watchTime: number;
  uniqueViewers: number;
}> {
  const dateFormat = (d: Date) => `${d.getFullYear()}_${String(d.getMonth() + 1).padStart(2, '0')}_${String(d.getDate()).padStart(2, '0')}`;
  const startKey = dateFormat(start);
  const endKey = dateFormat(end);

  try {
    const snapshot = await db()
      .collection("channel_stats_daily")
      .where("channelId", "==", channelId)
      .where("dateKey", ">=", startKey)
      .where("dateKey", "<=", endKey)
      .get();

    let views = 0;
    let watchTime = 0;
    let uniqueViewers = 0;

    for (const doc of snapshot.docs) {
      const d = doc.data();
      views += d.totalViews || d.views || 0;
      watchTime += d.totalWatchTimeSeconds || d.totalWatchSeconds || 0;
      uniqueViewers += d.uniqueViewers || 0;
    }

    return { views, watchTime, uniqueViewers };
  } catch (e) {
    logger.error("Error getting period stats:", e);
    return { views: 0, watchTime: 0, uniqueViewers: 0 };
  }
}

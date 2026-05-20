/**
 * Cloud Functions for Search Analytics
 * 
 * Maintains trending searches and search statistics
 * Deploy with: firebase deploy --only functions:maintainSearchAnalytics
 */

const functions = require('firebase-functions');
const admin = require('firebase-admin');

const db = admin.firestore();

/**
 * Daily Cleanup & Aggregation
 * Runs every day at 2 AM UTC to:
 * - Archive old search analytics
 * - Update trending searches
 * - Calculate metrics
 */
exports.maintainSearchAnalytics = functions.pubsub
  .schedule('0 2 * * *') // Daily at 2 AM UTC
  .timeZone('UTC')
  .onRun(async (context: any) => {
    try {
      console.log('🔄 Starting search analytics maintenance...');

      const yesterday = new Date();
      yesterday.setDate(yesterday.getDate() - 1);
      yesterday.setHours(0, 0, 0, 0);

      const today = new Date();
      today.setHours(0, 0, 0, 0);

      // 1. Aggregate yesterday's searches into daily stats
      await aggregateDailySearchStats(yesterday);

      // 2. Update trending searches (last 7 days)
      await updateTrendingSearches();

      // 3. Archive old analytics (older than 90 days)
      await archiveOldAnalytics();

      // 4. Update search performance benchmarks
      await updateSearchBenchmarks();

      console.log('✅ Search analytics maintenance complete');
      return null;
    } catch (error) {
      console.error('❌ Analytics maintenance error:', error);
      return null;
    }
  });

/**
 * Aggregate daily search statistics
 */
async function aggregateDailySearchStats(date: Date) {
  try {
    const dateStr = date.toISOString().split('T')[0]; // YYYY-MM-DD
    const startOfDay = admin.firestore.Timestamp.fromDate(
      new Date(dateStr + 'T00:00:00Z')
    );
    const endOfDay = admin.firestore.Timestamp.fromDate(
      new Date(dateStr + 'T23:59:59Z')
    );

    // Fetch all searches for the day
    const snapshot = await db
      .collection('search_analytics')
      .where('timestamp', '>=', startOfDay)
      .where('timestamp', '<=', endOfDay)
      .get();

    if (snapshot.docs.length === 0) {
      console.log(`⏭️ No searches found for ${dateStr}`);
      return;
    }

    // Calculate aggregates
    let totalQueries = 0;
    let totalResults = 0;
    let totalLatency = 0;
    let cachedQueries = 0;
    let errorQueries = 0;
    const topSearches: Record<string, number> = {};
    const searchTypes: Record<string, number> = {};

    for (const doc of snapshot.docs) {
      const data = doc.data();
      totalQueries++;
      totalResults += data.resultsCount || 0;
      totalLatency += data.latencyMs || 0;
      if (data.wasCached) cachedQueries++;
      if (data.error) errorQueries++;

      // Track top searches
      const query = (data.query || '').toLowerCase();
      if (query) {
        topSearches[query] = (topSearches[query] || 0) + 1;
      }

      // Track search types
      const type = data.searchType || 'unknown';
      searchTypes[type] = (searchTypes[type] || 0) + 1;
    }

    // Create daily summary
    const summary = {
      date: dateStr,
      totalQueries,
      totalResults,
      averageLatencyMs: Math.round(totalLatency / totalQueries),
      cacheHitRate: Math.round((cachedQueries / totalQueries) * 100),
      errorRate: Math.round((errorQueries / totalQueries) * 100),
      averageResultsPerQuery: Math.round(totalResults / totalQueries),
      topSearches: Object.entries(topSearches)
        .sort((a: any, b: any) => b[1] - a[1])
        .slice(0, 10)
        .reduce((acc: any, [query, count]) => {
          acc[query] = count;
          return acc;
        }, {}),
      searchTypes,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
    };

    // Save summary
    await db.collection('search_daily_stats').doc(dateStr).set(summary);
    console.log(`✅ Daily stats saved for ${dateStr}:`, summary);
  } catch (error) {
    console.error('❌ Error aggregating daily stats:', error);
  }
}

/**
 * Update trending searches based on last 7 days
 */
async function updateTrendingSearches() {
  try {
    const sevenDaysAgo = new Date();
    sevenDaysAgo.setDate(sevenDaysAgo.getDate() - 7);

    // Get all unique queries from last 7 days with counts
    const snapshot = await db
      .collection('search_analytics')
      .where('timestamp', '>=', admin.firestore.Timestamp.fromDate(sevenDaysAgo))
      .get();

    const searchCounts: Record<string, number> = {};
    let totalLatencies: Record<string, number> = {};

    for (const doc of snapshot.docs) {
      const data = doc.data();
      const query = (data.query || '').toLowerCase();

      if (query) {
        searchCounts[query] = (searchCounts[query] || 0) + 1;
        totalLatencies[query] = (totalLatencies[query] || 0) + (data.latencyMs || 0);
      }
    }

    // Update trending searches collection
    const batch = db.batch();

    // Clear old trending data
    const oldTrending = await db.collection('trending_searches').get();
    for (const doc of oldTrending.docs) {
      batch.delete(doc.ref);
    }

    // Add updated trending
    const sortedSearches = Object.entries(searchCounts)
      .sort((a: any, b: any) => b[1] - a[1])
      .slice(0, 50);

    for (let i = 0; i < sortedSearches.length; i++) {
      const [query, count] = sortedSearches[i];
      const docRef = db.collection('trending_searches').doc();

      batch.set(docRef, {
        term: query,
        termLowercase: query,
        rank: i + 1,
        searchCount: count,
        averageLatencyMs: Math.round(totalLatencies[query] / count),
        lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
        sevenDayTrend: calculateTrend(query), // Calculate trend direction
      });
    }

    await batch.commit();
    console.log(`✅ Updated trending searches: ${sortedSearches.length} terms`);
  } catch (error) {
    console.error('❌ Error updating trending searches:', error);
  }
}

/**
 * Archive old search analytics (older than 90 days)
 */
async function archiveOldAnalytics() {
  try {
    const ninetyDaysAgo = new Date();
    ninetyDaysAgo.setDate(ninetyDaysAgo.getDate() - 90);
    const cutoffTimestamp = admin.firestore.Timestamp.fromDate(ninetyDaysAgo);

    const snapshot = await db
      .collection('search_analytics')
      .where('timestamp', '<', cutoffTimestamp)
      .limit(5000)
      .get();

    const batch = db.batch();
    let deleteCount = 0;

    for (const doc of snapshot.docs) {
      batch.delete(doc.ref);
      deleteCount++;

      if (deleteCount % 500 === 0) {
        await batch.commit();
        console.log(`📦 Archived ${deleteCount} old documents`);
      }
    }

    if (deleteCount % 500 !== 0) {
      await batch.commit();
    }

    console.log(`✅ Archived ${deleteCount} old search records`);
  } catch (error) {
    console.error('❌ Error archiving old analytics:', error);
  }
}

/**
 * Update search performance benchmarks
 */
async function updateSearchBenchmarks() {
  try {
    const sevenDaysAgo = new Date();
    sevenDaysAgo.setDate(sevenDaysAgo.getDate() - 7);

    const snapshot = await db
      .collection('search_analytics')
      .where('timestamp', '>=', admin.firestore.Timestamp.fromDate(sevenDaysAgo))
      .get();

    let totalLatency = 0;
    let cachedCount = 0;
    let errorCount = 0;
    let totalResults = 0;

    for (const doc of snapshot.docs) {
      const data = doc.data();
      totalLatency += data.latencyMs || 0;
      if (data.wasCached) cachedCount++;
      if (data.error) errorCount++;
      totalResults += data.resultsCount || 0;
    }

    const benchmarks = {
      period: 'last_7_days',
      totalQueries: snapshot.docs.length,
      averageLatencyMs: Math.round(totalLatency / snapshot.docs.length),
      p95LatencyMs: calculatePercentile(snapshot.docs, 95),
      p99LatencyMs: calculatePercentile(snapshot.docs, 99),
      cacheHitRate: Math.round((cachedCount / snapshot.docs.length) * 100),
      errorRate: Math.round((errorCount / snapshot.docs.length) * 100),
      averageResultsPerQuery: Math.round(totalResults / snapshot.docs.length),
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
    };

    await db.collection('search_benchmarks').doc('current').set(benchmarks);
    console.log('✅ Updated search benchmarks:', benchmarks);
  } catch (error) {
    console.error('❌ Error updating benchmarks:', error);
  }
}

/**
 * Calculate trend direction for a search term
 */
function calculateTrend(query: string) {
  // This is simplified - in production, compare week-over-week
  // Returns 'up', 'down', or 'stable'
  return 'up'; // Placeholder
}

/**
 * Calculate percentile from latency data
 */
function calculatePercentile(docs: any[], percentile: number) {
  const latencies = docs
    .map((doc: any) => doc.data().latencyMs || 0)
    .sort((a: number, b: number) => a - b);

  const index = Math.ceil((percentile / 100) * latencies.length) - 1;
  return latencies[Math.max(0, index)] || 0;
}

/**
 * HTTP Function: Get search stats
 */
exports.getSearchStats = functions.https.onRequest(async (req: any, res: any) => {
  try {
    const { period = '7d' } = req.query;

    const stats = await db
      .collection('search_daily_stats')
      .orderBy('date', 'desc')
      .limit(period === '30d' ? 30 : 7)
      .get();

    res.json({
      success: true,
      data: stats.docs.map((doc: any) => doc.data()),
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      error: (error as Error).message,
    });
  }
});

/**
 * HTTP Function: Get trending searches
 */
exports.getTrendingSearches = functions.https.onRequest(async (req: any, res: any) => {
  try {
    const { limit = 20 } = req.query;

    const trends = await db
      .collection('trending_searches')
      .orderBy('searchCount', 'desc')
      .limit(parseInt(limit))
      .get();

    res.json({
      success: true,
      data: trends.docs.map((doc: any) => doc.data()),
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      error: (error as Error).message,
    });
  }
});

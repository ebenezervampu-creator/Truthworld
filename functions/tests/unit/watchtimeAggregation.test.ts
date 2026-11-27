/**
 * Unit Tests: Watch Time Aggregation, Hourly Stats, Shard Rollup & Daily Delta Rollup
 *
 * Verifies:
 * - aggregateWatchStats handles milestone_* and exit events + writes video_stats_hourly
 * - rollupVideoCounterShards propagates fresh video shard watchtime to channel without stale clamping
 * - rollupDailyStats records daily deltas instead of duplicating cumulative lifetime totals
 */

import * as admin from 'firebase-admin';
import { testFirestore } from '../helpers/mockFirestore';
import { aggregateWatchStats } from '../../src/watchtime/watchtime';
import { rollupDailyStats } from '../../src/watchtime/rollup';
import { rollupVideoCounterShards } from '../../src/analytics/counterRollup';

describe('Unit: YouTube-Standard Watch Time Aggregation & Rollups', () => {
  beforeEach(() => {
    testFirestore.clear();
  });

  it('aggregateWatchStats processes video_start + milestone events and writes video_stats_hourly', async () => {
    const db = admin.firestore();
    await db.collection('system_meta').doc('analytics').set({ lastProcessedAt: 1 });
    const eventTime = 1000;

    await db.collection('watch_events').add({
      videoId: 'vid_agg_1',
      userId: 'usr_1',
      sessionId: 'sess_1',
      eventType: 'video_start',
      position: 0,
      duration: 120,
      watchTimeSecondsDelta: 0,
      isSubscriber: true,
      country: 'IN',
      state: 'Karnataka',
      city: 'Bengaluru',
      areaType: 'urban',
      createdAt: eventTime,
    });

    await db.collection('watch_events').add({
      videoId: 'vid_agg_1',
      userId: 'usr_1',
      sessionId: 'sess_1',
      eventType: 'milestone_25',
      position: 30,
      duration: 120,
      watchTimeSecondsDelta: 30,
      isSubscriber: true,
      country: 'IN',
      state: 'Karnataka',
      city: 'Bengaluru',
      areaType: 'urban',
      createdAt: eventTime + 1,
    });

    await db.collection('watch_events').add({
      videoId: 'vid_agg_1',
      userId: 'usr_1',
      sessionId: 'sess_1',
      eventType: 'milestone_50',
      position: 60,
      duration: 120,
      watchTimeSecondsDelta: 30,
      isSubscriber: true,
      country: 'IN',
      state: 'Karnataka',
      city: 'Bengaluru',
      areaType: 'urban',
      createdAt: eventTime + 2,
    });

    await (aggregateWatchStats as any).run({});

    const statsDoc = await db.collection('video_stats').doc('vid_agg_1').get();
    expect(statsDoc.exists).toBe(true);
    expect(statsDoc.data()?.totalViews).toBe(1);
    expect(statsDoc.data()?.totalWatchSeconds).toBe(60);

    const hourlySnap = await db
      .collection('video_stats_hourly')
      .where('videoId', '==', 'vid_agg_1')
      .get();
    expect(hourlySnap.docs.length).toBe(1);
    expect(hourlySnap.docs[0].data()?.totalViews).toBe(1);
    expect(hourlySnap.docs[0].data()?.totalWatchTimeSeconds).toBe(60);
  });

  it('rollupDailyStats writes daily delta instead of repeating lifetime cumulative watchtime', async () => {
    const db = admin.firestore();

    await db.collection('channels').doc('chan_delta_1').set({
      name: 'Delta Channel',
      viewCount: 10,
      totalWatchTimeSeconds: 500,
    });

    await db.collection('videos').doc('vid_delta_1').set({
      channelId: 'chan_delta_1',
      viewCount: 10,
      totalWatchTimeSeconds: 500,
    });

    await db.collection('video_stats').doc('vid_delta_1').set({
      totalViews: 10,
      totalWatchSeconds: 500,
      lastDailyRollupViews: 6,
      lastDailyRollupWatchSeconds: 320,
      uniqueUsers: 10,
      avgWatchSeconds: 50,
      completionRate: 80,
    });

    await (rollupDailyStats as any).run({});

    const dailySnap = await db
      .collection('video_stats_daily')
      .where('videoId', '==', 'vid_delta_1')
      .get();
    expect(dailySnap.docs.length).toBe(1);
    const vDaily = dailySnap.docs[0].data();
    expect(vDaily.totalViews).toBe(4);
    expect(vDaily.totalWatchTimeSeconds).toBe(180);
    expect(vDaily.cumulativeWatchTimeSeconds).toBe(500);

    const chanDailySnap = await db
      .collection('channel_stats_daily')
      .where('channelId', '==', 'chan_delta_1')
      .get();
    expect(chanDailySnap.docs.length).toBe(1);
    const cDaily = chanDailySnap.docs[0].data();
    expect(cDaily.totalViews).toBe(4);
    expect(cDaily.totalWatchTimeSeconds).toBe(180);
  });

  it('rollupVideoCounterShards propagates fresh video shard watchtime to channel without stale clamping', async () => {
    const db = admin.firestore();
    const now = admin.firestore.Timestamp.now();

    await db.collection('channels').doc('chan_shard_1').set({
      name: 'Shard Channel',
      viewCount: 1,
      totalWatchTimeSeconds: 30,
    });

    // Video doc still has stale totalWatchTimeSeconds: 30 before rollup
    await db.collection('videos').doc('vid_shard_1').set({
      channelId: 'chan_shard_1',
      durationSeconds: 300,
      viewCount: 1,
      totalWatchTimeSeconds: 30,
      status: 'published',
    });

    // Shards have 120s of watchtime and 2 views
    await db.collection('videos').doc('vid_shard_1').collection('shards').doc('0').set({
      count: 2,
      qualifiedCount: 2,
      watchTimeSeconds: 120,
      updatedAt: now,
    });
    await db.collection('channels').doc('chan_shard_1').collection('shards').doc('0').set({
      views: 2,
      watchTimeSeconds: 120,
      updatedAt: now,
    });

    const vidShardsSnap = await db.collection('videos').doc('vid_shard_1').collection('shards').get();
    const chanShardsSnap = await db.collection('channels').doc('chan_shard_1').collection('shards').get();
    const makeShardDoc = (doc: any, parentCol: string, parentId: string) => ({
      ...doc,
      data: () => doc.data(),
      ref: {
        ...doc.ref,
        parent: {
          parent: {
            id: parentId,
            parent: { id: parentCol },
          },
        },
      },
    });
    const combinedDocs = [
      ...vidShardsSnap.docs.map((d: any) => makeShardDoc(d, 'videos', 'vid_shard_1')),
      ...chanShardsSnap.docs.map((d: any) => makeShardDoc(d, 'channels', 'chan_shard_1')),
    ];

    const origAggregateField = (admin.firestore as any).AggregateField;
    (admin.firestore as any).AggregateField = {
      sum: (field: string) => ({ __aggSum: field }),
    };

    const origCollection = db.collection.bind(db);
    const colSpy = jest.spyOn(db as any, 'collection').mockImplementation((...args: any[]) => {
      const colName = args[0] as string;
      const colRef = origCollection(colName);
      const origDoc = colRef.doc.bind(colRef);
      (colRef as any).doc = (docId?: string) => {
        const docRef = origDoc(docId as string);
        const origSubCol = docRef.collection.bind(docRef);
        docRef.collection = (subName: string) => {
          const subRef = origSubCol(subName);
          if (subName === 'shards') {
            (subRef as any).aggregate = (spec: Record<string, any>) => ({
              get: async () => {
                const snap = await subRef.get();
                const out: Record<string, number> = {};
                for (const [k, v] of Object.entries(spec)) {
                  const field = (v as any).__aggSum;
                  out[k] = snap.docs.reduce((acc: number, d: any) => acc + Number(d.data()?.[field] || 0), 0);
                }
                return { data: () => out };
              },
            });
          }
          return subRef;
        };
        return docRef;
      };
      return colRef;
    });

    const cgSpy = jest.spyOn(db as any, 'collectionGroup').mockImplementation(() => ({
      where: () => ({
        orderBy: () => ({
          limit: () => ({
            get: async () => ({
              empty: false,
              size: combinedDocs.length,
              docs: combinedDocs,
            }),
          }),
        }),
      }),
    }));

    try {
      await (rollupVideoCounterShards as any).run({});
    } finally {
      cgSpy.mockRestore();
      colSpy.mockRestore();
      (admin.firestore as any).AggregateField = origAggregateField;
    }

    const updatedVid = await db.collection('videos').doc('vid_shard_1').get();
    expect(updatedVid.data()?.totalWatchTimeSeconds).toBe(120);

    const updatedChan = await db.collection('channels').doc('chan_shard_1').get();
    expect(updatedChan.data()?.totalWatchTimeSeconds).toBe(120);
    const watchMinutes =
      updatedChan.data()?.metrics?.totalWatchTimeMinutes ??
      updatedChan.data()?.['metrics.totalWatchTimeMinutes'];
    expect(watchMinutes).toBe(2);
  });
});

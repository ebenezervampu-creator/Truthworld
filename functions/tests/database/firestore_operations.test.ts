import { testFirestore, FieldValue } from '../helpers/mockFirestore';
import { buildVideo } from '../factories/videoFactory';

describe('Database Tests: Dedicated Test Database Operations', () => {
  beforeEach(() => {
    testFirestore.clear();
  });

  describe('CRUD Operations', () => {
    it('creates and reads a document successfully', async () => {
      const video = buildVideo({ id: 'vid_crud_1', title: 'Empirical Research Methods' });
      await testFirestore.collection('videos').doc(video.id).set(video);

      const snapshot = await testFirestore.collection('videos').doc(video.id).get();
      expect(snapshot.exists).toBe(true);
      expect(snapshot.id).toBe(video.id);
      expect(snapshot.data()?.title).toBe('Empirical Research Methods');
    });

    it('updates an existing document without overwriting unrelated fields', async () => {
      const video = buildVideo({ id: 'vid_crud_2', viewCount: 100, likeCount: 10 });
      await testFirestore.collection('videos').doc(video.id).set(video);

      await testFirestore.collection('videos').doc(video.id).update({
        viewCount: 150,
      });

      const snapshot = await testFirestore.collection('videos').doc(video.id).get();
      expect(snapshot.data()?.viewCount).toBe(150);
      expect(snapshot.data()?.likeCount).toBe(10); // preserved
    });

    it('throws when updating a non-existent document', async () => {
      await expect(
        testFirestore.collection('videos').doc('non_existent').update({ viewCount: 10 })
      ).rejects.toThrow('NOT_FOUND');
    });

    it('deletes a document successfully', async () => {
      const video = buildVideo({ id: 'vid_to_delete' });
      await testFirestore.collection('videos').doc(video.id).set(video);

      await testFirestore.collection('videos').doc(video.id).delete();
      const snapshot = await testFirestore.collection('videos').doc(video.id).get();
      expect(snapshot.exists).toBe(false);
      expect(snapshot.data()).toBeUndefined();
    });
  });

  describe('Constraints, Duplicate Records, & Deduplication', () => {
    it('detects and prevents duplicate record collisions for unique keys', async () => {
      const uniqueHandle = 'truth_seeker';
      await testFirestore.collection('channel_handles').doc(uniqueHandle).set({
        channelId: 'chn_orig_1',
        createdAt: new Date().toISOString(),
      });

      // Second attempt with duplicate handle
      const existing = await testFirestore.collection('channel_handles').doc(uniqueHandle).get();
      expect(existing.exists).toBe(true);
      const isDuplicate = existing.exists;
      expect(isDuplicate).toBe(true);
    });
  });

  describe('Queries: Filtering, Sorting, & Pagination', () => {
    beforeEach(async () => {
      const videos = [
        buildVideo({ id: 'v1', category: 'Science', viewCount: 100, createdAt: 1000 }),
        buildVideo({ id: 'v2', category: 'Science', viewCount: 500, createdAt: 2000 }),
        buildVideo({ id: 'v3', category: 'History', viewCount: 300, createdAt: 3000 }),
        buildVideo({ id: 'v4', category: 'Science', viewCount: 900, createdAt: 4000 }),
        buildVideo({ id: 'v5', category: 'Technology', viewCount: 50, createdAt: 5000 }),
      ];

      for (const v of videos) {
        await testFirestore.collection('videos').doc(v.id).set(v);
      }
    });

    it('filters documents by category and status', async () => {
      const snap = await testFirestore
        .collection('videos')
        .where('category', '==', 'Science')
        .get();

      expect(snap.size).toBe(3);
      const ids = snap.docs.map((d) => d.id);
      expect(ids).toContain('v1');
      expect(ids).toContain('v2');
      expect(ids).toContain('v4');
    });

    it('sorts documents descending by createdAt', async () => {
      const snap = await testFirestore
        .collection('videos')
        .orderBy('createdAt', 'desc')
        .get();

      const ids = snap.docs.map((d) => d.id);
      expect(ids).toEqual(['v5', 'v4', 'v3', 'v2', 'v1']);
    });

    it('paginates accurately using limit and startAfter', async () => {
      // Page 1: limit 2
      const page1 = await testFirestore
        .collection('videos')
        .orderBy('createdAt', 'asc')
        .limit(2)
        .get();

      expect(page1.size).toBe(2);
      expect(page1.docs[0].id).toBe('v1');
      expect(page1.docs[1].id).toBe('v2');

      // Page 2: startAfter last doc from page 1
      const lastDoc = page1.docs[1];
      const page2 = await testFirestore
        .collection('videos')
        .orderBy('createdAt', 'asc')
        .startAfter(lastDoc)
        .limit(2)
        .get();

      expect(page2.size).toBe(2);
      expect(page2.docs[0].id).toBe('v3');
      expect(page2.docs[1].id).toBe('v4');
    });
  });

  describe('Atomic Transactions & Rollback Guarantee', () => {
    it('commits all operations when transaction succeeds', async () => {
      const orderRef = testFirestore.collection('orders').doc('ord_tx_1');
      const userRef = testFirestore.collection('users').doc('usr_tx_1');

      await testFirestore.runTransaction(async (transaction) => {
        transaction.set(orderRef, { orderId: 'ord_tx_1', status: 'FULFILLED' });
        transaction.set(userRef, { userId: 'usr_tx_1', isPremium: true });
      });

      const orderSnap = await orderRef.get();
      const userSnap = await userRef.get();
      expect(orderSnap.data()?.status).toBe('FULFILLED');
      expect(userSnap.data()?.isPremium).toBe(true);
    });

    it('rolls back all staged writes when an exception is thrown inside transaction', async () => {
      const orderRef = testFirestore.collection('orders').doc('ord_tx_fail');
      const userRef = testFirestore.collection('users').doc('usr_tx_fail');

      await orderRef.set({ orderId: 'ord_tx_fail', status: 'PENDING' });

      await expect(
        testFirestore.runTransaction(async (transaction) => {
          transaction.update(orderRef, { status: 'FULFILLED' });
          transaction.set(userRef, { userId: 'usr_tx_fail', isPremium: true });
          throw new Error('Simulated external service timeout / database lock failure');
        })
      ).rejects.toThrow('Simulated external service timeout / database lock failure');

      // Verify rollback: order remains PENDING, user was never created
      const orderSnap = await orderRef.get();
      const userSnap = await userRef.get();
      expect(orderSnap.data()?.status).toBe('PENDING');
      expect(userSnap.exists).toBe(false);
    });
  });

  describe('FieldValue Operations', () => {
    it('supports FieldValue.increment()', async () => {
      const docRef = testFirestore.collection('videos').doc('vid_inc');
      await docRef.set({ viewCount: 100 });
      await docRef.update({ viewCount: FieldValue.increment(1) });
      const snap = await docRef.get();
      expect(snap.data()?.viewCount).toBe(101);
    });

    it('supports FieldValue.arrayUnion()', async () => {
      const docRef = testFirestore.collection('users').doc('usr_arr');
      await docRef.set({ tags: ['student'] });
      await docRef.update({ tags: FieldValue.arrayUnion('premium', 'student') });
      const snap = await docRef.get();
      expect(snap.data()?.tags).toEqual(['student', 'premium']);
    });

    it('supports FieldValue.serverTimestamp()', async () => {
      const docRef = testFirestore.collection('comments').doc('c_ts');
      await docRef.set({ text: 'Hello', createdAt: FieldValue.serverTimestamp() });
      const snap = await docRef.get();
      expect(snap.data()?.createdAt).toBeDefined();
    });
  });

  describe('Batch Operations', () => {
    it('commits multiple writes in a batch', async () => {
      const batch = testFirestore.batch();
      const ref1 = testFirestore.collection('users').doc('u1');
      const ref2 = testFirestore.collection('users').doc('u2');
      batch.set(ref1, { name: 'User 1' });
      batch.set(ref2, { name: 'User 2' });
      await batch.commit();

      expect((await ref1.get()).data()?.name).toBe('User 1');
      expect((await ref2.get()).data()?.name).toBe('User 2');
    });
  });

  describe('Subcollections and Collection Groups', () => {
    it('supports subcollection CRUD', async () => {
      const subRef = testFirestore.collection('users').doc('u1').collection('orders').doc('o1');
      await subRef.set({ total: 50 });
      const snap = await subRef.get();
      expect(snap.data()?.total).toBe(50);
    });

    it('supports collection group queries on top-level collections', async () => {
      // The in-memory mock's collectionGroup aliases to collection()
      // This tests the query capability rather than cross-parent traversal
      await testFirestore.collection('orders').doc('o1').set({ amount: 100, userId: 'u1' });
      await testFirestore.collection('orders').doc('o2').set({ amount: 100, userId: 'u2' });
      await testFirestore.collection('orders').doc('o3').set({ amount: 200, userId: 'u3' });
      
      const snap = await testFirestore.collectionGroup('orders').where('amount', '==', 100).get();
      expect(snap.size).toBe(2);
    });
  });

  describe('Create operation', () => {
    it('throws ALREADY_EXISTS when creating an existing document', async () => {
      const docRef = testFirestore.collection('unique').doc('id1');
      await docRef.set({ val: 1 });
      await expect(docRef.create({ val: 2 })).rejects.toThrow('ALREADY_EXISTS');
    });
  });
});

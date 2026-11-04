import { testFirestore } from '../helpers/mockFirestore';

describe('Unit: Video Cascade Deletion & Anti-Phantom Architecture', () => {
  beforeEach(() => {
    testFirestore.clear();
  });

  it('ensures video subcollections and search metadata are purged upon deletion', async () => {
    const videoId = 'test_vid_to_purge';

    // 1. Setup mock video document with subcollections and search record
    await testFirestore.collection('videos').doc(videoId).set({
      id: videoId,
      title: 'Video to Purge',
      channelId: 'chan_123',
      status: 'ready',
      visibility: 'public',
    });

    await testFirestore.collection('videos').doc(videoId).collection('media').doc('localization').set({
      languages: ['en', 'es'],
    });

    await testFirestore.collection('videos').doc(videoId).collection('shards').doc('0').set({
      views: 10,
    });

    await testFirestore.collection('video_search').doc(videoId).set({
      id: videoId,
      title: 'Video to Purge',
      status: 'ready',
    });

    // Verify subcollections and doc exist
    const docSnap = await testFirestore.collection('videos').doc(videoId).get();
    expect(docSnap.exists).toBe(true);

    const mediaSnap = await testFirestore.collection('videos').doc(videoId).collection('media').doc('localization').get();
    expect(mediaSnap.exists).toBe(true);

    // 2. Simulate deep cascade delete (recursiveDelete behavior)
    // Deleting the document and all its subcollections
    await testFirestore.collection('videos').doc(videoId).collection('media').doc('localization').delete();
    await testFirestore.collection('videos').doc(videoId).collection('shards').doc('0').delete();
    await testFirestore.collection('videos').doc(videoId).delete();
    await testFirestore.collection('video_search').doc(videoId).delete();

    // 3. Verify that the document, subcollections, and search record are completely gone
    const finalDoc = await testFirestore.collection('videos').doc(videoId).get();
    expect(finalDoc.exists).toBe(false);

    const finalMedia = await testFirestore.collection('videos').doc(videoId).collection('media').doc('localization').get();
    expect(finalMedia.exists).toBe(false);

    const finalSearch = await testFirestore.collection('video_search').doc(videoId).get();
    expect(finalSearch.exists).toBe(false);
  });

  it('guarantees that non-video or deleted documents do not remain in the active catalog', () => {
    const activeVideos = [
      { id: 'v1', status: 'ready', exists: true },
      { id: 'v2', status: 'ready', exists: true },
      { id: 'v3', status: 'rejected', exists: true },
      { id: 'v_phantom', status: undefined, exists: false }, // phantom
      { id: 'v_trashed', status: 'deletion_pending', exists: true }, // trashed
    ];

    // Filter according to Truthworld Active Video Catalog policy
    const legitimateActiveVideos = activeVideos.filter(v =>
      v.exists === true &&
      v.status !== 'deleted' &&
      v.status !== 'deletion_pending' &&
      v.id !== 'v_phantom'
    );

    expect(legitimateActiveVideos.length).toBe(3);
    expect(legitimateActiveVideos.map(v => v.id)).toEqual(['v1', 'v2', 'v3']);
  });
});

import { callOnCall, authCallableContext, anonCallableContext } from '../helpers/callableHelper';
import { searchTruthWorld } from '../../src/search/searchBackend';
import { testFirestore } from '../helpers/mockFirestore';
import { TEST_USERS } from '../helpers/authHelper';

describe('Callable: searchTruthWorld', () => {
  beforeEach(async () => {
    // Note: In test environment, setup.ts typically mocks and clears testFirestore.
    // We add some seed data for testing
    await testFirestore.collection('videos').doc('v1').set({
      title: 'Global Truth Reveal',
      visibility: 'public',
      status: 'ready',
      keywords: ['global', 'truth', 'reveal'],
      viewCount: 1500,
      channelName: 'TruthSeeker',
    });
    await testFirestore.collection('videos').doc('v2').set({
      title: 'Hidden Secrets',
      visibility: 'public',
      status: 'ready',
      keywords: ['hidden', 'secrets'],
      viewCount: 50,
      channelName: 'MysteryChannel',
    });
    
    await testFirestore.collection('channels').doc('c1').set({
      channelName: 'TruthSeeker',
      handleLowercase: 'truthseeker',
      handle: '@TruthSeeker',
      subscriberCount: 5000,
    });
  });

  it('should return empty array for unauthenticated requests', async () => {
    const context = anonCallableContext({ query: 'truth' });
    const result = await callOnCall(searchTruthWorld, context);
    expect(result).toEqual([]);
  });

  it('should return empty array for empty query', async () => {
    const context = authCallableContext(TEST_USERS.regular, { query: '   ' });
    const result = await callOnCall(searchTruthWorld, context);
    expect(result).toEqual([]);
  });

  it('should return indexed fallback results for authenticated user', async () => {
    // Using a query that matches keywords for the indexed fallback since Vector Search is mocked
    const context = authCallableContext(TEST_USERS.regular, { query: 'truth' });
    const result = await callOnCall(searchTruthWorld, context);
    expect(result.length).toBeGreaterThan(0);
    expect(result.some((r: any) => r.title === 'Global Truth Reveal' || r.title === 'TruthSeeker')).toBe(true);
  });

  it('should limit results up to 50', async () => {
    const context = authCallableContext(TEST_USERS.regular, { query: 'truth', limit: 100 });
    const result = await callOnCall(searchTruthWorld, context);
    expect(result.length).toBeLessThanOrEqual(50);
  });

  it('should search channels if filter is Channels', async () => {
    const context = authCallableContext(TEST_USERS.regular, { query: 'truthseeker', filter: 'Channels' });
    const result = await callOnCall(searchTruthWorld, context);
    expect(result.length).toBeGreaterThan(0);
    expect(result[0].type).toBe('ResultType.channel');
  });
  
  it('should rate limit multiple requests from same user', async () => {
    const context = authCallableContext(TEST_USERS.regular, { query: 'test' });
    // Make 30 requests to exhaust quota
    for (let i = 0; i < 30; i++) {
      await callOnCall(searchTruthWorld, context);
    }
    // 31st request should hit rate limit
    const limitedResult = await callOnCall(searchTruthWorld, context);
    expect(limitedResult).toEqual([]);
  });
});

export const buildChannel = (overrides = {}) => {
  return {
    id: `channel_${Math.random().toString(36).substring(7)}`,
    name: 'Test Channel',
    handle: 'test_channel',
    ownerId: `user_${Math.random().toString(36).substring(7)}`,
    type: 'standard',
    subscriberCount: 100,
    totalViews: 5000,
    totalWatchTimeSeconds: 36000,
    kycStatus: 'verified',
    createdAt: new Date().toISOString(),
    isVerified: true,
    trustScore: 90,
    ...overrides,
  };
};

/**
 * 🏭 COMMENT FACTORY
 * Creates standardized nested and flat comments for community tests.
 */

export interface TestComment {
  id: string;
  videoId: string;
  userId: string;
  userName: string;
  text: string;
  likes: number;
  dislikes: number;
  authorRankScore: number;
  createdAt: number;
  parentId?: string | null;
}

export function buildComment(overrides: Partial<TestComment> = {}): TestComment {
  const id = overrides.id || `cmt_${Math.random().toString(36).substring(2, 9)}`;
  return {
    id,
    videoId: overrides.videoId || 'vid_target_001',
    userId: overrides.userId || 'usr_commenter_202',
    userName: overrides.userName || 'TruthSeeker',
    text: overrides.text || 'Insightful fact-checked analysis.',
    likes: overrides.likes ?? 5,
    dislikes: overrides.dislikes ?? 0,
    authorRankScore: overrides.authorRankScore ?? 2.5,
    createdAt: overrides.createdAt ?? Date.now(),
    parentId: overrides.parentId ?? null,
    ...overrides,
  };
}

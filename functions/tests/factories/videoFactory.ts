/**
 * 🏭 VIDEO FACTORY
 * Creates standardized video fixture documents for feed and playback tests.
 */

export interface TestVideo {
  id: string;
  title: string;
  status: 'draft' | 'scheduled' | 'published' | 'rejected' | 'processing';
  visibility: 'public' | 'unlisted' | 'private';
  channelId: string;
  category: string;
  viewCount: number;
  likeCount: number;
  commentCount: number;
  createdAt: any;
}

export function buildVideo(overrides: Partial<TestVideo> = {}): TestVideo {
  const id = overrides.id || `vid_${Math.random().toString(36).substring(2, 9)}`;
  return {
    id,
    title: overrides.title || `Test Video ${id}`,
    status: overrides.status || 'published',
    visibility: overrides.visibility || 'public',
    channelId: overrides.channelId || 'chn_default_101',
    category: overrides.category || 'Science',
    viewCount: overrides.viewCount ?? 1500,
    likeCount: overrides.likeCount ?? 120,
    commentCount: overrides.commentCount ?? 45,
    createdAt: overrides.createdAt || new Date(),
    ...overrides,
  };
}

import { synthesizeHeuristicResponse, RelatedTruthWorldVideo } from '../../src/pipeline/aiCredibilityChat';

describe('Unit: TruthWorld Video Suggestions in Ask AI', () => {
  const sampleRelatedVideos: RelatedTruthWorldVideo[] = [
    {
      id: 'tw_vid_india_facts_part2',
      title: 'India: Ancient Heritage and Modern Science',
      channelName: 'Discovery India',
      category: 'Education',
      topics: ['History', 'Science'],
      isVerified: true,
    },
    {
      id: 'tw_vid_kerala_documentary',
      title: 'Kerala: Culture, History & Ecology',
      channelName: 'Incredible Travel',
      category: 'Travel & Events',
      topics: ['Culture', 'Travel'],
      isVerified: true,
    },
  ];

  it('suggests real videos available in TruthWorld when user asks "suggest better videos in this topic"', () => {
    const response = synthesizeHeuristicResponse({
      videoTitle: '10 Facts about India',
      videoChannel: 'Knowledge Hub',
      trustScore: null,
      existingClaims: [
        {
          statement: 'Varanasi is one of the oldest continuously inhabited cities.',
          verdict: 'Verified',
        },
      ],
      existingSources: [],
      uiReport: null,
      scope: 'video',
      data: {
        videoId: 'd0669086-0f1a-4017-8606-346188af6bb8',
        videoTitle: '10 Facts about India',
        userQuery: 'suggest better videos in this topic',
      },
      userQuery: 'suggest better videos in this topic',
      relatedVideos: sampleRelatedVideos,
    });

    // Must recommend videos available on TruthWorld
    expect(response.answer).toContain('### Recommended Videos on TruthWorld for "10 Facts about India"');
    expect(response.answer).toContain('India: Ancient Heritage and Modern Science');
    expect(response.answer).toContain('Discovery India');
    expect(response.answer).toContain('TruthWorld Verified');
    expect(response.answer).toContain('Kerala: Culture, History & Ecology');

    // Must NEVER include external legacy outlets
    expect(response.answer).not.toMatch(/Bloomberg/i);
    expect(response.answer).not.toMatch(/The Ken/i);
    expect(response.answer).not.toMatch(/dark store/i);
  });

  it('suggests related videos for specific claim scope when user asks "suggest better videos for this claim"', () => {
    const response = synthesizeHeuristicResponse({
      videoTitle: '10 Facts about India',
      videoChannel: 'Knowledge Hub',
      trustScore: null,
      existingClaims: [
        {
          statement: 'The Indian railway system employs over 1.4 million personnel.',
          verdict: 'Disputed',
        },
      ],
      existingSources: [],
      uiReport: null,
      scope: 'claim',
      data: {
        videoId: 'd0669086-0f1a-4017-8606-346188af6bb8',
        videoTitle: '10 Facts about India',
        claimIndex: 0,
        userQuery: 'suggest better videos for this claim',
      },
      userQuery: 'suggest better videos for this claim',
      relatedVideos: sampleRelatedVideos,
    });

    expect(response.answer).toContain('### Recommended Videos on TruthWorld');
    expect(response.answer).toContain('India: Ancient Heritage and Modern Science');
    expect(response.suggestedFollowups).toContain('Summarize verified claims');
  });

  it('gracefully handles empty catalog without falling back to external mock text', () => {
    const response = synthesizeHeuristicResponse({
      videoTitle: 'Exploring Deep Space',
      videoChannel: 'Astro Channel',
      trustScore: null,
      existingClaims: [],
      existingSources: [],
      uiReport: null,
      scope: 'video',
      data: {
        videoId: 'vid_space_01',
        videoTitle: 'Exploring Deep Space',
        userQuery: 'can you recommend other videos to watch?',
      },
      userQuery: 'can you recommend other videos to watch?',
      relatedVideos: [],
    });

    expect(response.answer).toContain('Discover');
    expect(response.answer).toContain('TruthWorld');
    expect(response.answer).not.toMatch(/Bloomberg/i);
    expect(response.answer).not.toMatch(/The Ken/i);
    expect(response.answer).not.toMatch(/dark store/i);
  });
});

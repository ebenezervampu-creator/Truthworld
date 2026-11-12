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

  it('responds conversationally as a chat to question in claim scope instead of echoing raw claim card', () => {
    const nehruExplanation =
      "The claim holds historical basis. Mahatma Gandhi publicly indicated his preference for Jawaharlal Nehru as his successor and as India's first Prime Minister, despite significant support for Sardar Vallabhbhai Patel among the Provincial Congress Committees (PCCs).";

    const response = synthesizeHeuristicResponse({
      videoTitle: 'Real Face of Gandhi',
      videoChannel: 'History Focus',
      existingClaims: [
        {
          statement: 'మనమూ జవహర్‌లాల్ నెహ్రూ నే ప్రైమ్ మినిస్టర్ చేదాము అనే అన్నారు',
          verdict: 'MOSTLY TRUE',
          explanation: nehruExplanation,
        },
      ],
      existingSources: [
        {
          title: 'Why was Nehru the chosen political heir of Mahatma Gandhi?',
          url: 'https://quora.com/why-nehru-chosen',
          domain: 'quora.com',
          publisher: 'Historical Archives',
        },
      ],
      uiReport: null,
      scope: 'claim',
      data: {
        videoId: 'video_nehru_14',
        videoTitle: 'Real Face of Gandhi',
        claimIndex: 0,
        claimText: 'మనమూ జవహర్‌లాల్ నెహ్రూ నే ప్రైమ్ మినిస్టర్ చేదాము అనే అన్నారు',
        verdict: 'MOSTLY TRUE',
        claimExplanation: nehruExplanation,
        userQuery: 'why gandhi declared Nehru as Prime Minster?',
      },
      userQuery: 'why gandhi declared Nehru as Prime Minster?',
    });

    // Must be a conversational chat response
    expect(response.answer).toContain('Regarding your question about');
    expect(response.answer).toContain('why gandhi declared Nehru as Prime Minster');
    expect(response.answer).toContain('Key Historical Context & Verified Rationale');
    expect(response.answer).toContain('International Diplomacy');
    expect(response.answer).toContain('Sardar Vallabhbhai Patel');

    // Must NOT be the raw static claim card
    expect(response.answer.startsWith('### Claim #1 Analysis:')).toBe(false);
  });

  it('anchors inquiry to playback timestamp and transcript snippet for relative questions', () => {
    const response = synthesizeHeuristicResponse({
      videoTitle: 'Real Face of Gandhi',
      videoChannel: 'History Focus',
      existingClaims: [
        {
          statement: 'మనమూ జవహర్‌లాల్ నెహ్రూ నే ప్రైమ్ మినిస్టర్ చేదాము అనే అన్నారు',
          verdict: 'MOSTLY TRUE',
        },
      ],
      existingSources: [],
      uiReport: null,
      scope: 'claim',
      data: {
        videoId: 'video_nehru_14',
        videoTitle: 'Real Face of Gandhi',
        claimIndex: 0,
        playbackSec: 358, // 05:58
        transcriptSnippet: 'మనమూ జవహర్‌లాల్ నెహ్రూ నే ప్రైమ్ మినిస్టర్ చేదాము అనే అన్నారు',
        activeChapterTitle: 'Nomination Decision',
        userQuery: 'what did the speaker just mean by that?',
      },
      userQuery: 'what did the speaker just mean by that?',
    });

    expect(response.answer).toContain('Temporal Video & Transcript Analysis (05:58)');
    expect(response.answer).toContain('Nomination Decision');
    expect(response.answer).toContain('మనమూ జవహర్‌లాల్ నెహ్రూ నే ప్రైమ్ మినిస్టర్ చేదాము అనే అన్నారు');
    expect(response.suggestedFollowups).toContain('Did the speaker contradict an earlier claim?');
    expect(response.suggestedFollowups).toContain('What sources verify what was said at 05:58?');
  });

  it('evaluates self-contradictions and ledger consistency when user asks if speaker contradicted earlier claim', () => {
    const response = synthesizeHeuristicResponse({
      videoTitle: 'Economic Forecast 2026',
      videoChannel: 'Market Truth',
      existingClaims: [
        {
          statement: 'Q1 growth exceeded 8% across retail banking.',
          verdict: 'Verified',
        },
        {
          statement: 'Operating margins contracted by 200 basis points.',
          verdict: 'Verified',
        },
      ],
      existingSources: [],
      uiReport: null,
      scope: 'video',
      data: {
        videoId: 'econ_2026',
        videoTitle: 'Economic Forecast 2026',
        playbackSec: 120, // 02:00
        userQuery: 'did the speaker contradict an earlier claim?',
      },
      userQuery: 'did the speaker contradict an earlier claim?',
    });

    expect(response.answer).toContain('Temporal Video & Transcript Analysis (02:00)');
    expect(response.answer).toContain('Self-Contradiction & Claim Consistency Analysis');
    expect(response.answer).toContain('Ledger Alignment');
    expect(response.suggestedFollowups).toContain('Did the speaker contradict an earlier claim?');
  });
});

import { MultilingualSubtitleLocalizer } from '../../src/pipeline/services/multilingual_subtitle_localizer';
import { getSubtitleProfile } from '../../src/pipeline/services/subtitle_language_profiles';
import { SubtitleReadabilityValidator } from '../../src/pipeline/services/subtitle_readability_validator';
import { WordTimestamp } from '../../src/pipeline/types';

describe('Unit: Multilingual Subtitle Localizer & Readability Engine', () => {
  const sampleWords: WordTimestamp[] = [
    { text: 'Welcome', start: 112, end: 481, confidence: 0.95 },
    { text: 'to', start: 513, end: 658, confidence: 0.99 },
    { text: 'Truth', start: 658, end: 995, confidence: 0.99 },
    { text: "World's", start: 1059, end: 1396, confidence: 0.98 },
    { text: 'Fact-Checking', start: 1396, end: 2039, confidence: 0.96 },
    { text: 'Network.', start: 2119, end: 2536, confidence: 0.97 },
    { text: 'Today', start: 3484, end: 3741, confidence: 0.99 },
    { text: 'we', start: 3741, end: 3950, confidence: 0.99 },
    { text: 'are', start: 3950, end: 4120, confidence: 0.99 },
    { text: 'investigating', start: 4120, end: 4890, confidence: 0.98 },
    { text: 'claims', start: 4890, end: 5310, confidence: 0.99 },
    { text: 'regarding', start: 5310, end: 5750, confidence: 0.97 },
    { text: 'global', start: 5750, end: 6180, confidence: 0.98 },
    { text: 'renewable', start: 6180, end: 6690, confidence: 0.98 },
    { text: 'energy.', start: 6690, end: 7064, confidence: 0.99 },
    { text: 'Solar', start: 8076, end: 8430, confidence: 0.99 },
    { text: 'efficiency', start: 8430, end: 8980, confidence: 0.98 },
    { text: 'has', start: 8980, end: 9150, confidence: 0.99 },
    { text: 'doubled', start: 9150, end: 9580, confidence: 0.98 },
    { text: 'over', start: 9580, end: 9810, confidence: 0.99 },
    { text: 'the', start: 9810, end: 9960, confidence: 0.99 },
    { text: 'last', start: 9960, end: 10320, confidence: 0.98 },
    { text: 'decade,', start: 10320, end: 10805, confidence: 0.98 },
    { text: 'and', start: 11335, end: 11520, confidence: 0.99 },
    { text: 'grid', start: 11520, end: 11840, confidence: 0.98 },
    { text: 'batteries', start: 11840, end: 12450, confidence: 0.98 },
    { text: 'exceed', start: 12450, end: 12980, confidence: 0.97 },
    { text: '85%', start: 12980, end: 13540, confidence: 0.96 },
    { text: 'efficiency.', start: 13540, end: 14290, confidence: 0.99 },
  ];

  describe('Pillar 1: Intra-Word Compound Hyphen & Sentence Extraction', () => {
    it('preserves hyphenated compound words like Fact-Checking without splitting', () => {
      const sentences = MultilingualSubtitleLocalizer.extractSourceSentences(sampleWords);
      expect(sentences.length).toBe(4);
      expect(sentences[0].text).toBe("Welcome to Truth World's Fact-Checking Network.");
      expect(sentences[0].startMs).toBe(112);
      expect(sentences[0].endMs).toBe(2536);
      expect(sentences[0].followingPauseMs).toBeGreaterThan(900);
    });

    it('correctly calculates followingPauseMs for silence utilization', () => {
      const sentences = MultilingualSubtitleLocalizer.extractSourceSentences(sampleWords);
      // Pause between Sentence 1 (2536) and Sentence 2 (3484) is 948ms
      expect(sentences[0].followingPauseMs).toBe(948);
      // Pause between Sentence 2 (7064) and Sentence 3 (8076) is 1012ms
      expect(sentences[1].followingPauseMs).toBe(1012);
      // Pause between Sentence 3 (10805) and Sentence 4 (11335) is 530ms
      expect(sentences[2].followingPauseMs).toBe(530);
    });
  });

  describe('Pillar 2: Spanish Retiming & Elimination of 48.29 CPS Blowout', () => {
    it('retimes Spanish translation across full envelope and guarantees reading speed <= 21 CPS', () => {
      const profile = getSubtitleProfile('es');
      const sentence1 = MultilingualSubtitleLocalizer.extractSourceSentences(sampleWords)[0];

      const spanishText = 'Bienvenidos a la Red de Verificación de Hechos de TruthWorld.';
      const phrases = MultilingualSubtitleLocalizer.segmentTranslatedSentence(spanishText, 'es', profile);

      const timedCues = MultilingualSubtitleLocalizer.retimeTargetPhrasesForSentence({
        sentence: sentence1,
        phrases,
        languageCode: 'es',
        profile,
        startCueId: 1,
        nextSentenceStartMs: 3484,
      });

      expect(timedCues.length).toBeGreaterThan(0);
      for (const cue of timedCues) {
        expect(cue.charactersPerSecond).toBeLessThanOrEqual(21);
        expect(cue.durationMs).toBeGreaterThanOrEqual(profile.minimumCueDurationMs);
        expect(cue.endMs).toBeLessThanOrEqual(3484 - profile.minInterCueGapMs);
      }
    });
  });

  describe('Pillar 3: Non-Overlapping Inter-Cue Gaps & Monotonicity', () => {
    it('enforces >= 66ms (2 frames) gap between all consecutive cues with zero overlaps', () => {
      const sentences = MultilingualSubtitleLocalizer.extractSourceSentences(sampleWords);
      const profile = getSubtitleProfile('es');
      const spanishTranslations = [
        'Bienvenidos a la Red de Verificación de Hechos de TruthWorld.',
        'Hoy estamos investigando afirmaciones sobre la energía renovable global.',
        'La eficiencia solar se ha duplicado en la última década,',
        'y las baterías de red superan el 85% de eficiencia.',
      ];

      const allCues = [];
      let cueId = 1;

      for (let sIdx = 0; sIdx < sentences.length; sIdx++) {
        const sentence = sentences[sIdx];
        const nextSentence = sIdx < sentences.length - 1 ? sentences[sIdx + 1] : null;
        const nextSentenceStartMs = nextSentence ? nextSentence.startMs : undefined;
        const previousCueEndMs = allCues.length > 0 ? allCues[allCues.length - 1].endMs : undefined;

        const phrases = MultilingualSubtitleLocalizer.segmentTranslatedSentence(
          spanishTranslations[sIdx],
          'es',
          profile
        );
        const cues = MultilingualSubtitleLocalizer.retimeTargetPhrasesForSentence({
          sentence,
          phrases,
          languageCode: 'es',
          profile,
          startCueId: cueId,
          nextSentenceStartMs,
          previousCueEndMs,
        });

        for (const cue of cues) {
          allCues.push(cue);
          cueId++;
        }
      }

      const report = SubtitleReadabilityValidator.validateTrack(allCues, 'es', profile);
      expect(report.hasOverlaps).toBe(false);
      expect(report.status).toBe('pass');
      expect(report.errors).toHaveLength(0);

      // Verify gap between each consecutive cue
      for (let i = 1; i < allCues.length; i++) {
        const gap = allCues[i].startMs - allCues[i - 1].endMs;
        expect(gap).toBeGreaterThanOrEqual(profile.minInterCueGapMs);
      }
    });
  });

  describe('Pillar 4: Indic Language Validation (Hindi & Telugu)', () => {
    it('validates Hindi subtitles against Indic script thresholds', () => {
      const sentences = MultilingualSubtitleLocalizer.extractSourceSentences(sampleWords);
      const profile = getSubtitleProfile('hi');
      const hindiTranslations = [
        'ट्रुथवर्ल्ड फैक्ट-चेकिंग नेटवर्क में आपका स्वागत है।',
        'आज हम वैश्विक नवीकरणीय ऊर्जा से जुड़े दावों की पड़ताल कर रहे हैं।',
        'पिछले एक दशक में सौर ऊर्जा दक्षता दोगुनी हो चुकी है,',
        'और ग्रिड बैटरियां 85% से अधिक दक्षता प्रदान करती हैं।',
      ];

      const allCues = [];
      let cueId = 1;

      for (let sIdx = 0; sIdx < sentences.length; sIdx++) {
        const sentence = sentences[sIdx];
        const nextSentence = sIdx < sentences.length - 1 ? sentences[sIdx + 1] : null;
        const nextSentenceStartMs = nextSentence ? nextSentence.startMs : undefined;
        const previousCueEndMs = allCues.length > 0 ? allCues[allCues.length - 1].endMs : undefined;

        const phrases = MultilingualSubtitleLocalizer.segmentTranslatedSentence(
          hindiTranslations[sIdx],
          'hi',
          profile
        );
        const cues = MultilingualSubtitleLocalizer.retimeTargetPhrasesForSentence({
          sentence,
          phrases,
          languageCode: 'hi',
          profile,
          startCueId: cueId,
          nextSentenceStartMs,
          previousCueEndMs,
        });

        for (const cue of cues) {
          allCues.push(cue);
          cueId++;
        }
      }

      const report = SubtitleReadabilityValidator.validateTrack(allCues, 'hi', profile);
      expect(report.status).toBe('pass');
      expect(report.hasOverlaps).toBe(false);
      expect(report.maxCps).toBeLessThanOrEqual(profile.maxReadingSpeedCps);
    });

    it('validates Telugu subtitles against Indic script thresholds', () => {
      const sentences = MultilingualSubtitleLocalizer.extractSourceSentences(sampleWords);
      const profile = getSubtitleProfile('te');
      const teluguTranslations = [
        'ట్రూత్‌వరల్డ్ ఫాక్ట్-చెకింగ్ నెట్‌వర్క్‌కు స్వాగతం.',
        'ఈరోజు మేము ప్రపంచ పునరుత్పాదక శక్తిపై వచ్చిన వాదనలను పరిశోధిస్తున్నాము.',
        'గత దశాబ్దంలో సౌర సామర్థ్యం రెట్టింపు అయింది,',
        'మరియు గ్రిడ్ బ్యాటరీలు 85% సామర్థ్యాన్ని మించిపోయాయి.',
      ];

      const allCues = [];
      let cueId = 1;

      for (let sIdx = 0; sIdx < sentences.length; sIdx++) {
        const sentence = sentences[sIdx];
        const nextSentence = sIdx < sentences.length - 1 ? sentences[sIdx + 1] : null;
        const nextSentenceStartMs = nextSentence ? nextSentence.startMs : undefined;
        const previousCueEndMs = allCues.length > 0 ? allCues[allCues.length - 1].endMs : undefined;

        const phrases = MultilingualSubtitleLocalizer.segmentTranslatedSentence(
          teluguTranslations[sIdx],
          'te',
          profile
        );
        const cues = MultilingualSubtitleLocalizer.retimeTargetPhrasesForSentence({
          sentence,
          phrases,
          languageCode: 'te',
          profile,
          startCueId: cueId,
          nextSentenceStartMs,
          previousCueEndMs,
        });

        for (const cue of cues) {
          allCues.push(cue);
          cueId++;
        }
      }

      const report = SubtitleReadabilityValidator.validateTrack(allCues, 'te', profile);
      expect(report.status).toBe('pass');
      expect(report.hasOverlaps).toBe(false);
      expect(report.maxCps).toBeLessThanOrEqual(profile.maxReadingSpeedCps);
    });
  });

  describe('Pillar 5: SubtitleReadabilityValidator Defense & Diagnostics', () => {
    it('detects and flags overlapping cues and broken encoding', () => {
      const profile = getSubtitleProfile('en');
      const badCues = [
        {
          id: 1,
          languageCode: 'en',
          text: 'This is cue one with a broken \uFFFD character',
          startMs: 1000,
          endMs: 2500,
          durationMs: 1500,
          sourceWordStartIndex: 0,
          sourceWordEndIndex: 5,
          charactersPerSecond: 30, // Exceeds reading speed
          charactersPerLine: 45,
          alignmentConfidence: 0.9,
          validationStatus: 'warning' as const,
        },
        {
          id: 2,
          languageCode: 'en',
          text: 'This cue overlaps with cue one',
          startMs: 2200, // Starts before cue 1 ends (2500ms) -> 300ms overlap
          endMs: 3500,
          durationMs: 1300,
          sourceWordStartIndex: 6,
          sourceWordEndIndex: 10,
          charactersPerSecond: 20,
          charactersPerLine: 30,
          alignmentConfidence: 0.9,
          validationStatus: 'pass' as const,
        },
      ];

      const report = SubtitleReadabilityValidator.validateTrack(badCues, 'en', profile);
      expect(report.status).toBe('review');
      expect(report.hasOverlaps).toBe(true);
      expect(report.errors.some((e) => e.includes('Overlaps'))).toBe(true);
      expect(report.errors.some((e) => e.includes('Unicode replacement'))).toBe(true);
    });
  });
});

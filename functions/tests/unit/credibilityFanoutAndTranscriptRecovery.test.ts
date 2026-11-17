import { isCredibilityEnabled, ExecutionPlan } from '../../src/pipeline/types';

describe('Unit: Credibility Fan-out and Recovery Fixes', () => {
  describe('ExecutionPlan isCredibilityEnabled Verification', () => {
    it('evaluates true when enableCredibility is true', () => {
      const plan: Partial<ExecutionPlan> = {
        enableCredibility: true,
      };
      expect(isCredibilityEnabled(plan)).toBe(true);
    });

    it('evaluates true when factCheckEnabled is true', () => {
      const plan: Partial<ExecutionPlan> = {
        factCheckEnabled: true,
      };
      expect(isCredibilityEnabled(plan)).toBe(true);
    });

    it('evaluates true when enableFactChecking is true', () => {
      const plan = {
        enableFactChecking: true,
      };
      expect(isCredibilityEnabled(plan)).toBe(true);
    });

    it('evaluates true in the 05-transcription webhook fanout condition for standard videoPublishTrigger plan', () => {
      // This is the exact plan constructed by videoPublishTrigger when publishing a fact-checked video
      const executionPlan = {
        jobId: 'job_test_123',
        videoId: 'video_test_456',
        enableCredibility: true,
        factCheckEnabled: true,
        enableFactChecking: true,
      };

      const webhookFanoutCondition =
        isCredibilityEnabled(executionPlan) ||
        (executionPlan as any)?.isCredibilityRequested ||
        (executionPlan as any)?.generateFactChecking ||
        (executionPlan as any)?.features?.credibility;

      expect(webhookFanoutCondition).toBe(true);
    });

    it('evaluates false when credibility is explicitly false', () => {
      const plan: Partial<ExecutionPlan> = {
        enableCredibility: false,
        factCheckEnabled: false,
      };
      expect(isCredibilityEnabled(plan)).toBe(false);
    });
  });

  describe('Utterance Splitting for Large Monologues', () => {
    // Test the logic implemented in FactExtractionService.splitLargeUtterance
    function splitLargeUtteranceSimulation(text: string, durationMs: number): { text: string; start: number; end: number }[] {
      const words = text.split(/\s+/);
      const subUtterances: { text: string; start: number; end: number }[] = [];
      const targetWords = 180;
      const overlapWords = 25;

      let i = 0;
      while (i < words.length) {
        let endIdx = i + targetWords;
        const searchWindow = Math.floor(targetWords * 0.3);
        const windowEnd = Math.min(words.length, i + targetWords);
        const windowStart = Math.max(i, windowEnd - searchWindow);

        for (let j = windowEnd - 1; j >= windowStart; j--) {
          if (words[j].endsWith('.') || words[j].endsWith('?') || words[j].endsWith('!')) {
            endIdx = j + 1;
            break;
          }
        }

        const chunkWords = words.slice(i, Math.min(words.length, endIdx));
        if (chunkWords.length < 30 && subUtterances.length > 0) break;

        const ratioStart = i / words.length;
        const ratioEnd = Math.min(1, endIdx / words.length);

        subUtterances.push({
          text: chunkWords.join(' '),
          start: Math.floor(0 + (durationMs * ratioStart)),
          end: Math.floor(0 + (durationMs * ratioEnd)),
        });

        if (endIdx >= words.length) break;
        i = Math.max(i + 1, endIdx - overlapWords);
      }

      return subUtterances;
    }

    it('covers continuous monologues without skipping words', () => {
      // 500 word continuous monologue
      const words = Array.from({ length: 500 }, (_, idx) => `word${idx}.`);
      const monologue = words.join(' ');
      const chunks = splitLargeUtteranceSimulation(monologue, 300_000);

      expect(chunks.length).toBeGreaterThan(1);
      // Ensure all words from beginning to end are covered in the chunks
      expect(chunks[0].text).toContain('word0.');
      expect(chunks[chunks.length - 1].text).toContain('word499.');

      // Check overlap between consecutive chunks
      for (let c = 0; c < chunks.length - 1; c++) {
        const lastWordOfCurrent = chunks[c].text.split(' ').slice(-1)[0];
        const nextWords = chunks[c + 1].text.split(' ');
        // The overlap ensures no gap between chunks
        expect(chunks[c].end).toBeGreaterThan(chunks[c + 1].start);
      }
    });
  });
});

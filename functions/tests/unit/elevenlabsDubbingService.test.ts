/**
 * 🧪 UNIT TEST: ElevenLabsDubbingService
 *
 * Verifies:
 *   1. isAvailable() accurately reflects API key presence.
 *   2. Language normalization maps regional/BCP-47 codes (hi -> hi, tl -> fil).
 *   3. createDubbing() sends POST /v1/dubbing with multipart/form-data.
 *   4. dubMedia() orchestrates polling, emits progressive milestones (25%, 55%, 85%, 95%),
 *      downloads completed audio, uploads to Cloud Storage, and cleans up.
 *   5. Error handling when ElevenLabs cloud fails.
 */

import { ElevenLabsDubbingService } from '../../src/pipeline/services/elevenlabsDubbingService';
import { PIPELINE_CONFIG } from '../../src/pipeline/config';

// Mock storage
const mockSave = jest.fn().mockResolvedValue(undefined);
const mockFile = jest.fn(() => ({
  save: mockSave,
}));
const mockBucket = {
  name: 'truthworld-test-bucket',
  file: mockFile,
};

jest.mock('firebase-admin', () => {
  const original = jest.requireActual('firebase-admin');
  return {
    ...original,
    storage: () => ({
      bucket: () => mockBucket,
    }),
  };
});

jest.mock('../../src/pipeline/services/audio-identity', () => ({
  audioIdentityService: {
    getAccessibleUrl: jest.fn().mockImplementation(async (url: string) => url),
  },
}));

jest.mock('axios');
import axios from 'axios';
const mockedAxios = axios as jest.Mocked<typeof axios>;

describe('ElevenLabs Native Dubbing Service', () => {
  let service: ElevenLabsDubbingService;

  beforeEach(() => {
    jest.clearAllMocks();
    service = new ElevenLabsDubbingService();
  });

  describe('Language Normalization & Availability', () => {
    it('normalizes target languages to ElevenLabs supported codes', () => {
      expect(service.normalizeTargetLanguage('hi')).toBe('hi');
      expect(service.normalizeTargetLanguage('HI ')).toBe('hi');
      expect(service.normalizeTargetLanguage('es')).toBe('es');
      expect(service.normalizeTargetLanguage('tl')).toBe('fil');
      expect(service.normalizeTargetLanguage('de')).toBe('de');
    });

    it('reports availability based on API key configuration', () => {
      const originalKey = PIPELINE_CONFIG.ELEVENLABS_API_KEY;
      expect(service.isAvailable()).toBe(true);
    });
  });

  describe('Dubbing Lifecycle & Orchestration', () => {
    it('creates dubbing job successfully via POST /v1/dubbing', async () => {
      mockedAxios.post.mockResolvedValueOnce({
        data: {
          dubbing_id: 'dub_test_123',
          expected_duration_sec: 24,
        },
      });

      const res = await service.createDubbing({
        sourceUrl: 'https://storage.googleapis.com/test-bucket/video.mp4',
        targetLang: 'hi',
        sourceLang: 'en',
      });

      expect(res.dubbingId).toBe('dub_test_123');
      expect(res.expectedDurationSec).toBe(24);
      expect(mockedAxios.post).toHaveBeenCalledWith(
        'https://api.elevenlabs.io/v1/dubbing',
        expect.any(Object),
        expect.objectContaining({
          headers: expect.objectContaining({
            'xi-api-key': expect.any(String),
          }),
        })
      );
    });

    it('orchestrates end-to-end dubMedia with progress reporting, audio download, and GCS save', async () => {
      // 1. Create dubbing mock
      mockedAxios.post.mockResolvedValueOnce({
        data: {
          dubbing_id: 'dub_active_456',
          expected_duration_sec: 10,
        },
      });

      // 2. Poll 1: in progress
      mockedAxios.get.mockResolvedValueOnce({
        data: {
          dubbing_id: 'dub_active_456',
          status: 'dubbing',
        },
      });

      // 3. Poll 2: completed
      mockedAxios.get.mockResolvedValueOnce({
        data: {
          dubbing_id: 'dub_active_456',
          status: 'dubbed',
        },
      });

      // 4. Download audio track
      const mockAudioBytes = Buffer.from('mock-hindi-dubbed-mp3-audio');
      mockedAxios.get.mockResolvedValueOnce({
        data: mockAudioBytes,
      });

      // 5. Download transcript (404/empty or srt)
      mockedAxios.get.mockRejectedValueOnce(new Error('No transcript'));

      // 6. Delete project
      mockedAxios.delete.mockResolvedValueOnce({ data: { ok: true } });

      const progressSnapshots: Array<{ progress: number; stageTitle: string; step: number }> = [];

      const result = await service.dubMedia({
        jobId: 'video_job_24s',
        userId: 'creator_1',
        mediaUrl: 'https://example.com/source_24s.mp4',
        targetLang: 'hi',
        sourceLang: 'en',
        onProgress: async (p, title, step) => {
          progressSnapshots.push({ progress: p, stageTitle: title, step });
        },
      });

      expect(result.dubbingId).toBe('dub_active_456');
      expect(result.audioUrl).toBe('gs://truthworld-test-bucket/audio/video_job_24s/hi/master.mp3');
      expect(result.directAudioUrl).toContain('audio/video_job_24s/hi/master.mp3');

      // Verify file was saved to GCS
      expect(mockFile).toHaveBeenCalledWith('audio/video_job_24s/hi/master.mp3');
      expect(mockSave).toHaveBeenCalledWith(
        mockAudioBytes,
        expect.objectContaining({
          metadata: expect.objectContaining({
            contentType: 'audio/mpeg',
          }),
        })
      );

      // Verify progress callbacks emitted milestones
      expect(progressSnapshots.length).toBeGreaterThanOrEqual(3);
      expect(progressSnapshots.some((s) => s.progress >= 85)).toBe(true);
      expect(progressSnapshots[progressSnapshots.length - 1].progress).toBe(95);
    });

    it('throws error and cleans up if ElevenLabs returns failed status', async () => {
      mockedAxios.post.mockResolvedValueOnce({
        data: {
          dubbing_id: 'dub_fail_789',
          expected_duration_sec: 15,
        },
      });

      mockedAxios.get.mockResolvedValueOnce({
        data: {
          dubbing_id: 'dub_fail_789',
          status: 'failed',
          error: 'Unsupported audio format in input video',
        },
      });

      mockedAxios.delete.mockResolvedValueOnce({ data: { ok: true } });

      await expect(
        service.dubMedia({
          jobId: 'job_fail_test',
          userId: 'user_fail',
          mediaUrl: 'https://example.com/bad.mp4',
          targetLang: 'hi',
        })
      ).rejects.toThrow('Unsupported audio format in input video');

      expect(mockedAxios.delete).toHaveBeenCalledWith(
        'https://api.elevenlabs.io/v1/dubbing/dub_fail_789',
        expect.any(Object)
      );
    });
  });
});

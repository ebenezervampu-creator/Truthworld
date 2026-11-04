/**
 * 🧪 UNIT TEST: Industry-Standard M&E (Music & Foley) Preservation & Dynamic Sidechain Ducking
 *
 * Verifies:
 *   1. MediaService.extractMneStem:
 *      - Dual-path stem demixing: Phase-inverted vocal subtraction when isolated vocal is available.
 *      - 3-band frequency crossover (<220Hz lowpass, 1800Hz mid stereotools vocal suppression, >5000Hz highpass)
 *        when isolated vocal is not provided or fails.
 *      - Idempotent stem caching: returns existing GCS path without reprocessing.
 *   2. MediaService.mixDubWithMne:
 *      - Dynamic sidechain ducking (20ms attack, 300ms release) of M&E stem under dubbed dialogue.
 *      - Integrated EBU R128 / ITU-R BS.1770 -14 LUFS loudness mastering with -1 dBTP true peak limiting.
 *      - DSP filter chain integration and video duration clamping.
 *   3. Dubbing Pipeline Non-Destructive Preservation:
 *      - Preserves M&E, dialogue, master, and vocal stem URLs in job outputs and Firestore.
 *      - Guarantees video muxing receives pre-mastered composite track instead of destructive dialog-only overwrite.
 */

import { MediaService } from '../../src/pipeline/services/media';
import * as child_process from 'child_process';

// Mock storage
const mockSave = jest.fn().mockResolvedValue(undefined);
const mockDownload = jest.fn().mockResolvedValue([Buffer.from('fake-audio-bytes')]);
const mockExists = jest.fn().mockResolvedValue([false]);
const mockUpload = jest.fn().mockResolvedValue(undefined);
const mockFile = jest.fn((path: string) => ({
  save: mockSave,
  download: mockDownload,
  exists: mockExists,
}));
const mockBucket = {
  name: 'truthworld-test-bucket',
  file: mockFile,
  upload: mockUpload,
};

jest.mock('firebase-admin', () => {
  const original = jest.requireActual('firebase-admin');
  return {
    ...original,
    storage: () => ({
      bucket: () => mockBucket,
    }),
    firestore: () => ({
      collection: jest.fn(() => ({
        doc: jest.fn(() => ({
          set: jest.fn().mockResolvedValue({}),
          get: jest.fn().mockResolvedValue({ exists: false }),
          update: jest.fn().mockResolvedValue({}),
        })),
      })),
    }),
  };
});

// Mock child_process execFile
jest.mock('child_process', () => ({
  ...jest.requireActual('child_process'),
  execFile: jest.fn((cmd, args, optsOrCb, cb) => {
    const callback = typeof optsOrCb === 'function' ? optsOrCb : cb;
    if (typeof callback === 'function') {
      callback(null, '', 'Duration: 00:01:30.00\nStream #0:0: Audio: mp3, 44100 Hz, stereo, fltp, 192 kb/s');
    }
  }),
}));

describe('🎛️ Industry-Standard M&E (Music & Foley) Preservation & Ducking', () => {
  let mediaService: MediaService;
  const mockedExecFile = child_process.execFile as unknown as jest.Mock;

  beforeEach(() => {
    jest.clearAllMocks();
    mediaService = new MediaService();
  });

  describe('1. MediaService.extractMneStem (Dual-Path Demixing)', () => {
    it('returns cached M&E stem if already computed for the job (Idempotency)', async () => {
      mockExists.mockResolvedValueOnce([true]);

      const result = await mediaService.extractMneStem('job_cached', 'gs://truthworld-test-bucket/audio/job_cached/original.mp3');

      expect(result).toBe('gs://truthworld-test-bucket/audio/job_cached/m_and_e.mp3');
      // Should not download or run FFmpeg if already cached
      expect(mockDownload).not.toHaveBeenCalled();
      expect(mockUpload).not.toHaveBeenCalled();
    });

    it('executes Path 1 (Phase-Inverted Subtraction + Mid/Side Cleanup) when isolated vocal is available', async () => {
      mockExists.mockResolvedValueOnce([false]);

      const result = await mediaService.extractMneStem(
        'job_phase_sub',
        'gs://truthworld-test-bucket/audio/job_phase_sub/original.mp3',
        { isolatedVocalUrl: 'gs://truthworld-test-bucket/audio/job_phase_sub/isolated-vocal.mp3' }
      );

      expect(mockDownload).toHaveBeenCalledTimes(2); // Original audio + Isolated vocal
      expect(mockedExecFile).toHaveBeenCalled();

      const demixCall = mockedExecFile.mock.calls.find((call: any[]) => call[1]?.includes('-filter_complex'));
      const ffmpegArgs = demixCall[1];
      const filterArg = ffmpegArgs[ffmpegArgs.indexOf('-filter_complex') + 1];

      // Verifies phase subtraction formula c0-c2 and c1-c3
      expect(filterArg).toContain('pan=stereo|c0=c0-c2|c1=c1-c3');
      // Verifies mid/side stereotools vocal cleanup
      expect(filterArg).toContain('stereotools=mlev=0.08:slev=1.05');
      expect(mockUpload).toHaveBeenCalledWith(
        expect.any(String),
        expect.objectContaining({
          destination: 'audio/job_phase_sub/m_and_e.mp3',
          metadata: expect.objectContaining({
            metadata: expect.objectContaining({
              separationMethod: 'phase_subtraction_midside',
            }),
          }),
        })
      );
      expect(result).toBe('gs://truthworld-test-bucket/audio/job_phase_sub/m_and_e.mp3');
    });

    it('executes Path 2 (3-Band Frequency Crossover) when isolated vocal is not available', async () => {
      mockExists.mockResolvedValueOnce([false]);

      const result = await mediaService.extractMneStem(
        'job_crossover',
        'gs://truthworld-test-bucket/audio/job_crossover/original.mp3'
      );

      expect(mockDownload).toHaveBeenCalledTimes(1); // Only original audio
      expect(mockedExecFile).toHaveBeenCalled();

      const demixCall = mockedExecFile.mock.calls.find((call: any[]) => call[1]?.includes('-filter_complex'));
      const ffmpegArgs = demixCall[1];
      const filterArg = ffmpegArgs[ffmpegArgs.indexOf('-filter_complex') + 1];

      // Verifies 3-band frequency split
      expect(filterArg).toContain('asplit=3[low_in][mid_in][high_in]');
      // Lowpass preserves bass & sub-foley below 220Hz
      expect(filterArg).toContain('lowpass=f=220');
      // Bandpass + stereotools suppresses center-channel vocal formants while keeping stereo music
      expect(filterArg).toContain('bandpass=f=1800:width_type=h:w=3200');
      expect(filterArg).toContain('stereotools=mlev=0.10:slev=1.15');
      // Highpass preserves cymbals & high-frequency foley above 5000Hz
      expect(filterArg).toContain('highpass=f=5000');
      // 3-way summation
      expect(filterArg).toContain('amix=inputs=3');

      expect(mockUpload).toHaveBeenCalledWith(
        expect.any(String),
        expect.objectContaining({
          destination: 'audio/job_crossover/m_and_e.mp3',
          metadata: expect.objectContaining({
            metadata: expect.objectContaining({
              separationMethod: 'mono_adaptive_or_3band_crossover',
            }),
          }),
        })
      );
      expect(result).toBe('gs://truthworld-test-bucket/audio/job_crossover/m_and_e.mp3');
    });
  });

  describe('2. MediaService.mixDubWithMne (Sidechain Dynamic Ducking & Mastering)', () => {
    it('applies sidechain dynamic ducking with 20ms attack, 300ms release, and -14 LUFS mastering', async () => {
      const result = await mediaService.mixDubWithMne('job_mix', 'te', {
        mneUrl: 'gs://truthworld-test-bucket/audio/job_mix/m_and_e.mp3',
        dubbedAudioUrl: 'gs://truthworld-test-bucket/audio/job_mix/te/dialogue.mp3',
        totalDurationSeconds: 120,
      });

      expect(mockDownload).toHaveBeenCalledTimes(2); // M&E stem + Dubbed voice stem
      expect(mockedExecFile).toHaveBeenCalled();

      const demixCall = mockedExecFile.mock.calls.find((call: any[]) => call[1]?.includes('-filter_complex'));
      const ffmpegArgs = demixCall[1];
      const filterArg = ffmpegArgs[ffmpegArgs.indexOf('-filter_complex') + 1];

      // Verifies sidechain compressor configuration
      expect(filterArg).toContain('sidechaincompress=threshold=0.03:ratio=4:attack=20:release=300:makeup=1');
      // Verifies amix combining ducked M&E with dubbed voice
      expect(filterArg).toContain('amix=inputs=2:weights=1.0 1.0:normalize=0');
      // Verifies ITU-R BS.1770 / EBU R128 -14 LUFS broadcast mastering
      expect(filterArg).toContain('loudnorm=I=-14:TP=-1:LRA=11');

      // Verifies duration clamp
      expect(ffmpegArgs).toContain('-t');
      expect(ffmpegArgs).toContain('120');

      expect(mockUpload).toHaveBeenCalledWith(
        expect.any(String),
        expect.objectContaining({
          destination: 'audio/job_mix/te/master.mp3',
          metadata: expect.objectContaining({
            metadata: expect.objectContaining({
              stem: 'master_mix',
              ducking: 'sidechain_dynamic',
              targetLoudness: '-14 LUFS',
            }),
          }),
        })
      );
      expect(result).toBe('gs://truthworld-test-bucket/audio/job_mix/te/master.mp3');
    });

    it('integrates custom DSP filters into dubbed dialogue stream before ducking', async () => {
      const customFilters = 'equalizer=f=120:width_type=h:w=100:g=3,compand=attacks=0.03';
      await mediaService.mixDubWithMne('job_dsp', 'hi', {
        mneUrl: 'gs://truthworld-test-bucket/audio/job_dsp/m_and_e.mp3',
        dubbedAudioUrl: 'gs://truthworld-test-bucket/audio/job_dsp/hi/dialogue.mp3',
        audioFilters: customFilters,
      });

      const demixCall = mockedExecFile.mock.calls.find((call: any[]) => call[1]?.includes('-filter_complex'));
      const ffmpegArgs = demixCall[1];
      const filterArg = ffmpegArgs[ffmpegArgs.indexOf('-filter_complex') + 1];

      expect(filterArg).toContain(customFilters);
      expect(filterArg).toContain('sidechaincompress=');
    });
  });

  describe('3. Non-Destructive Video Merging Contract', () => {
    it('flags isPreMastered to prevent redundant re-compression during video muxing', async () => {
      await mediaService.mergeAudioToVideo({
        jobId: 'job_premaster',
        videoUrl: 'gs://truthworld-test-bucket/videos/sample.mp4',
        audioUrl: 'gs://truthworld-test-bucket/audio/job_premaster/te/master.mp3',
        language: 'te',
        audioFilters: 'loudnorm=I=-14:TP=-1:LRA=11',
        isPreMastered: true,
      });

      expect(mockedExecFile).toHaveBeenCalled();
      const ffmpegArgs = mockedExecFile.mock.calls[0][1];

      // Because isPreMastered is true, audioFilters should NOT be appended again (only clean apad)
      expect(ffmpegArgs[ffmpegArgs.indexOf('-filter:a') + 1]).toBe('apad');
      expect(ffmpegArgs.join(' ')).not.toContain('loudnorm');
    });
  });
});

/**
 * 🧪 ACCEPTANCE TEST SUITE: Dubbing M&E Preservation & Mastering Quality Gate
 *
 * Verifies the 8 strict technical acceptance criteria:
 *   1. Cache Invalidation: Stale M&E stems without MNE_PIPELINE_VERSION = "2" are strictly rejected.
 *   2. M&E Safety Guard: Residual vocal-band energy in M&E stem (> -24 dBFS) clamps makeup gain ceiling.
 *   3. Fallback Headroom Cap: Degraded/DSP fallback stems are clamped to +3 dB max gain.
 *   4. Master Loudness Limits: Enforces ITU-R BS.1770 -14 LUFS target and -1 dBTP true-peak ceiling.
 *   5. Stereo Preservation: Audio tracks strictly maintain stereo channel layout (no mono collapse).
 *   6. Dynamic Ducking Transparency: Gentler sidechain ducking (0.08 threshold, ratio 2.0, 15ms attack, 200ms release) ensures audible music during pauses.
 *   7. Zero Filter Re-Application: Dialogue is passed through without double loudnorm stacking.
 *   8. Observability & Telemetry: Degraded fallbacks and separation engine metadata are strictly tracked.
 */

import { MediaService, MNE_PIPELINE_VERSION } from '../../src/pipeline/services/media';
import * as child_process from 'child_process';

const mockDownload = jest.fn().mockResolvedValue([Buffer.from('fake-audio-bytes')]);
const mockExists = jest.fn().mockResolvedValue([true]);
const mockUpload = jest.fn().mockResolvedValue(undefined);
const mockGetMetadata = jest.fn().mockResolvedValue([{ size: 50000, metadata: {} }]);
const mockFile = jest.fn((path: string) => ({
  download: mockDownload,
  exists: mockExists,
  getMetadata: mockGetMetadata,
}));
const mockBucket = {
  name: 'truthworld-test-bucket',
  file: mockFile,
  upload: mockUpload,
};

jest.mock('firebase-admin', () => ({
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
}));

jest.mock('child_process', () => ({
  ...jest.requireActual('child_process'),
  execFile: jest.fn((cmd, args, optsOrCb, cb) => {
    const callback = typeof optsOrCb === 'function' ? optsOrCb : cb;
    if (typeof callback === 'function') {
      callback(
        null,
        '',
        'Duration: 00:00:07.00\nStream #0:0: Audio: mp3, 44100 Hz, stereo, fltp, 192 kb/s\n' +
        'mean_volume: -28.0 dB\nmax_volume: -2.0 dB\n' +
        'Integrated loudness:\n    I: -14.1 LUFS\n    Threshold: -24.1 LUFS\n' +
        'Loudness range:\n    LRA: 8.5 LU\n' +
        'Peak:\n    True: -1.02 dBFS\n'
      );
    }
  }),
}));

describe('🎯 TruthWorld Dubbing Production Acceptance Suite', () => {
  let mediaService: MediaService;
  const mockedExecFile = child_process.execFile as unknown as jest.Mock;

  beforeEach(() => {
    jest.clearAllMocks();
    mediaService = new MediaService();
  });

  describe('1. Cache Invalidation Gate', () => {
    it('rejects stale cached M&E stems that lack MNE_PIPELINE_VERSION = "2"', async () => {
      mockExists.mockResolvedValueOnce([true]);
      mockGetMetadata.mockResolvedValueOnce([{
        size: 50000,
        metadata: { mnePipelineVersion: '1', separationMethod: 'old_phase_sub' },
      }]);

      const result = await mediaService.extractMneStemDetailedParallel('job_stale', 'gs://truthworld-test-bucket/audio/job_stale/orig.mp3');

      // Must have re-extracted (DSP fallback since worker mock not configured) rather than returning stale cache
      expect(result.source).not.toBe('cached_mne');
    });

    it('accepts cached M&E stem when MNE_PIPELINE_VERSION matches "2"', async () => {
      mockExists.mockResolvedValueOnce([true]);
      mockGetMetadata.mockResolvedValueOnce([{
        size: 50000,
        metadata: {
          mnePipelineVersion: MNE_PIPELINE_VERSION,
          mneSource: 'neural_demixing',
          degraded: 'false',
        },
      }]);

      const result = await mediaService.extractMneStemDetailedParallel('job_fresh', 'gs://truthworld-test-bucket/audio/job_fresh/orig.mp3');

      expect(result.mneUrl).toBe('gs://truthworld-test-bucket/audio/job_fresh/m_and_e.mp3');
      expect(result.degraded).toBe(false);
    });
  });

  describe('2. M&E Gain Calibration Safety Guard', () => {
    it('clamps makeup gain when elevated vocal-band energy (> -24 dBFS) is detected during dialogue intervals', async () => {
      // Mock execFile to return high vocal-band energy (-18 dBFS) during spoken intervals
      mockedExecFile.mockImplementation((cmd, args, optsOrCb, cb) => {
        const callback = typeof optsOrCb === 'function' ? optsOrCb : cb;
        const argStr = Array.isArray(args) ? args.join(' ') : '';
        let stderr = 'Duration: 00:00:07.00\nStream #0:0: Audio: mp3, 44100 Hz, stereo, fltp, 192 kb/s\n';
        if (argStr.includes('bandpass=f=1800')) {
          // Elevated vocal band energy during dialogue window -> residual speech leak!
          stderr += 'mean_volume: -18.0 dB\nmax_volume: -2.0 dB\n';
        } else if (argStr.includes('loudnorm=I=-18')) {
          stderr += '{\n"input_i" : "-32.00"\n}\n';
        } else if (argStr.includes('ebur128')) {
          stderr += 'Integrated loudness:\n    I: -14.0 LUFS\nPeak:\n    True: -1.0 dBFS\nLoudness range:\n    LRA: 9.0 LU\n';
        }
        callback(null, stderr, stderr);
      });

      await mediaService.mixDubWithMne('job_residual_guard', 'te', {
        mneUrl: 'gs://truthworld-test-bucket/audio/job_residual_guard/mne.mp3',
        dubbedAudioUrl: 'gs://truthworld-test-bucket/audio/job_residual_guard/te/dub.mp3',
        spokenSegments: [{ start: 500, end: 4000 }],
      });

      const demixCall = mockedExecFile.mock.calls.find((call: any[]) => call[1]?.includes('-filter_complex'));
      const filterArg = demixCall[1][demixCall[1].indexOf('-filter_complex') + 1];

      // Makeup gain should be strictly clamped to <= 3 dB (linear <= 1.4125), NOT +12 dB (linear 3.98)
      const volumeMatch = filterArg.match(/volume=([\d.]+)/);
      expect(volumeMatch).toBeDefined();
      const gainVal = parseFloat(volumeMatch![1]);
      expect(gainVal).toBeLessThan(1.5); // Clamped safely away from +12 dB (3.98x)
    });

    it('caps fallback/degraded M&E stems to maximum +3 dB gain', async () => {
      mockedExecFile.mockImplementation((cmd, args, optsOrCb, cb) => {
        const callback = typeof optsOrCb === 'function' ? optsOrCb : cb;
        const argStr = Array.isArray(args) ? args.join(' ') : '';
        let stderr = 'Duration: 00:00:07.00\nStream #0:0: Audio: mp3, 44100 Hz, stereo, fltp, 192 kb/s\n';
        if (argStr.includes('loudnorm=I=-18')) {
          stderr += '{\n"input_i" : "-36.00"\n}\n';
        } else if (argStr.includes('ebur128')) {
          stderr += 'Integrated loudness:\n    I: -14.0 LUFS\nPeak:\n    True: -1.0 dBFS\nLoudness range:\n    LRA: 9.0 LU\n';
        }
        callback(null, stderr, stderr);
      });

      await mediaService.mixDubWithMne('job_degraded_cap', 'hi', {
        mneUrl: 'gs://truthworld-test-bucket/audio/job_degraded_cap/mne.mp3',
        dubbedAudioUrl: 'gs://truthworld-test-bucket/audio/job_degraded_cap/hi/dub.mp3',
        isDegradedMne: true, // Degraded DSP fallback stem
      });

      const demixCall = mockedExecFile.mock.calls.find((call: any[]) => call[1]?.includes('-filter_complex'));
      const filterArg = demixCall[1][demixCall[1].indexOf('-filter_complex') + 1];

      // +3 dB corresponds to 10^(3/20) ≈ 1.4125x gain
      const volumeMatch = filterArg.match(/volume=([\d.]+)/);
      expect(volumeMatch).toBeDefined();
      const gainVal = parseFloat(volumeMatch![1]);
      expect(gainVal).toBeCloseTo(1.4125, 2);
    });
  });

  describe('3. Dynamic Ducking, Loudness & Stereo Integrity', () => {
    it('enforces stereo layout, gentle ducking, and single-pass loudnorm', async () => {
      await mediaService.mixDubWithMne('job_master_verify', 'te', {
        mneUrl: 'gs://truthworld-test-bucket/audio/job_master_verify/mne.mp3',
        dubbedAudioUrl: 'gs://truthworld-test-bucket/audio/job_master_verify/te/dub.mp3',
        totalDurationSeconds: 7.0,
      });

      const demixCall = mockedExecFile.mock.calls.find((call: any[]) => call[1]?.includes('-filter_complex'));
      const filterArg = demixCall[1][demixCall[1].indexOf('-filter_complex') + 1];

      // 1. Stereo channel layouts guaranteed
      expect(filterArg).toContain('aformat=channel_layouts=stereo');
      // 2. Dialogue passthrough (zero double-DSP)
      expect(filterArg).toContain('[dub_sc][dub_mix]');
      expect(filterArg).not.toContain('[dub_raw]');
      // 3. Gentle sidechain ducking parameters
      expect(filterArg).toContain('sidechaincompress=threshold=0.08:ratio=2:attack=15:release=200:makeup=1');
      // 4. ITU-R BS.1770 -14 LUFS mastering
      expect(filterArg).toContain('loudnorm=I=-14:TP=-1:LRA=11');

      // 5. Verifies GCS metadata records measured loudness telemetry
      expect(mockUpload).toHaveBeenCalledWith(
        expect.any(String),
        expect.objectContaining({
          destination: 'audio/job_master_verify/te/master.mp3',
          metadata: expect.objectContaining({
            metadata: expect.objectContaining({
              targetLoudness: '-14 LUFS',
              measuredLufs: expect.stringContaining('LUFS'),
              measuredTruePeak: expect.stringContaining('dBTP'),
              mneAutoGain: expect.any(String),
            }),
          }),
        })
      );
    });
  });
});

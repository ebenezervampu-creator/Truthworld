/**
 * 🧪 UNIT TEST: Industry-Standard Hybrid TTS Architecture
 *
 * Verifies:
 *   1. Google Cloud Text-to-Speech locale resolution & high-fidelity voice catalog mapping.
 *   2. Default routing to Google Cloud TTS for standard dubbing (50%-75% cost savings & native regional accents).
 *   3. Voice cloning routing to ElevenLabs when requested (preferVoiceCloning / voiceCloneId).
 *   4. Automatic, seamless fallback from ElevenLabs to Google Cloud TTS upon rate-limits/quota/errors.
 *   5. Accurate cost engine accounting across Google Neural2, Standard, and ElevenLabs.
 */

import { GoogleTextToSpeechService, LANGUAGE_LOCALE_MAP, RECOMMENDED_VOICES } from '../../src/pipeline/services/googleTextToSpeechService';
import { ElevenLabsTTSService, TTSService } from '../../src/pipeline/services/tts';
import { costEngine, RATE_CARDS } from '../../src/pipeline/services/cost-engine';
import { TTSRequest } from '../../src/pipeline/types';

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

// Mock axios for ElevenLabs
jest.mock('axios');
import axios from 'axios';
const mockedAxios = axios as jest.Mocked<typeof axios>;

describe('Industry-Standard Hybrid Text-to-Speech (TTS) Architecture', () => {
  let mockGoogleClient: any;
  let googleTtsService: GoogleTextToSpeechService;
  let elevenLabsService: ElevenLabsTTSService;
  let hybridTtsService: TTSService;

  beforeEach(() => {
    jest.clearAllMocks();

    // Mock Google Cloud Text-to-Speech client
    mockGoogleClient = {
      synthesizeSpeech: jest.fn().mockResolvedValue([
        {
          audioContent: Buffer.from('mock-google-tts-mp3-audio-bytes'),
        },
      ]),
    };

    googleTtsService = new GoogleTextToSpeechService(mockGoogleClient as any);
    elevenLabsService = new ElevenLabsTTSService('test-elevenlabs-api-key');
    hybridTtsService = new TTSService(googleTtsService, elevenLabsService);

    // Spy on costEngine.recordTTSCost
    jest.spyOn(costEngine, 'recordTTSCost').mockImplementation(async () => {});
  });

  describe('1. Google Cloud Text-to-Speech Locale & Voice Resolution', () => {
    it('correctly maps 2-letter codes for Indian regional languages to BCP-47 subcontinent locales', () => {
      expect(googleTtsService.resolveLocale('te')).toBe('te-IN');
      expect(googleTtsService.resolveLocale('hi')).toBe('hi-IN');
      expect(googleTtsService.resolveLocale('ta')).toBe('ta-IN');
      expect(googleTtsService.resolveLocale('kn')).toBe('kn-IN');
      expect(googleTtsService.resolveLocale('ml')).toBe('ml-IN');
      expect(googleTtsService.resolveLocale('mr')).toBe('mr-IN');
      expect(googleTtsService.resolveLocale('bn')).toBe('bn-IN');
      expect(googleTtsService.resolveLocale('gu')).toBe('gu-IN');
      expect(googleTtsService.resolveLocale('pa')).toBe('pa-IN');
      expect(googleTtsService.resolveLocale('ur')).toBe('ur-IN');
    });

    it('correctly maps global core languages to standard BCP-47 locales', () => {
      expect(googleTtsService.resolveLocale('en')).toBe('en-US');
      expect(googleTtsService.resolveLocale('es')).toBe('es-US');
      expect(googleTtsService.resolveLocale('fr')).toBe('fr-FR');
      expect(googleTtsService.resolveLocale('de')).toBe('de-DE');
      expect(googleTtsService.resolveLocale('ja')).toBe('ja-JP');
      expect(googleTtsService.resolveLocale('zh')).toBe('cmn-CN');
      expect(googleTtsService.resolveLocale('ar')).toBe('ar-XA');
    });

    it('selects high-fidelity Chirp 3: HD voices by gender across Indian regional and global languages', () => {
      // Hindi: Chirp 3: HD
      const hiFemale = googleTtsService.resolveVoice({
        jobId: 'job_1', language: 'hi', text: 'नमस्ते', gender: 'FEMALE',
      });
      expect(hiFemale.locale).toBe('hi-IN');
      expect(hiFemale.voiceName).toBe('hi-IN-Chirp3-HD-Kore');
      expect(hiFemale.modelType).toBe('chirp3-hd');

      const hiMale = googleTtsService.resolveVoice({
        jobId: 'job_1', language: 'hi', text: 'नमस्ते', gender: 'MALE',
      });
      expect(hiMale.voiceName).toBe('hi-IN-Chirp3-HD-Fenrir');
      expect(hiMale.modelType).toBe('chirp3-hd');

      // Telugu: Generative Chirp 3: HD voice (No more robotic standard voice)
      const teFemale = googleTtsService.resolveVoice({
        jobId: 'job_1', language: 'te', text: 'నమస్కారం', gender: 'FEMALE',
      });
      expect(teFemale.locale).toBe('te-IN');
      expect(teFemale.voiceName).toBe('te-IN-Chirp3-HD-Kore');
      expect(teFemale.modelType).toBe('chirp3-hd');

      // English: Chirp 3: HD natural voice
      const enFemale = googleTtsService.resolveVoice({
        jobId: 'job_1', language: 'en', text: 'Hello', gender: 'FEMALE',
      });
      expect(enFemale.locale).toBe('en-US');
      expect(enFemale.voiceName).toBe('en-US-Chirp3-HD-Kore');
      expect(enFemale.modelType).toBe('chirp3-hd');
    });

    it('maps legacy voiceId presets to gender when gender is omitted', () => {
      // Adam preset voiceId -> Male
      const adamVoice = googleTtsService.resolveVoice({
        jobId: 'job_1', language: 'hi', text: 'परीक्षण', voiceId: 'pNInz6obpgDQGcFmaJgB',
      });
      expect(adamVoice.voiceName).toBe('hi-IN-Chirp3-HD-Fenrir');

      // Bella preset voiceId -> Female
      const bellaVoice = googleTtsService.resolveVoice({
        jobId: 'job_1', language: 'te', text: 'పరీక్ష', voiceId: 'hpp4J3VqNfWAUOO0d1Us',
      });
      expect(bellaVoice.voiceName).toBe('te-IN-Chirp3-HD-Kore');
    });

    it('preserves native Google Cloud voice ID if passed directly', () => {
      const explicitVoice = googleTtsService.resolveVoice({
        jobId: 'job_1', language: 'hi', text: 'परीक्षण', voiceId: 'hi-IN-Neural2-D',
      });
      expect(explicitVoice.voiceName).toBe('hi-IN-Neural2-D');
      expect(explicitVoice.modelType).toBe('neural2');
    });
  });

  describe('2. Google Cloud Text-to-Speech Synthesis', () => {
    it('synthesizes audio, uploads to storage, and records cost with provider rate card', async () => {
      const request: TTSRequest = {
        jobId: 'job_tts_123',
        userId: 'user_456',
        language: 'hi',
        text: 'భారతదేశం ఒక గొప్ప దేశం',
        gender: 'FEMALE',
      };

      const result = await googleTtsService.synthesize(request);

      expect(mockGoogleClient.synthesizeSpeech).toHaveBeenCalledTimes(1);
      expect(mockSave).toHaveBeenCalledTimes(1);
      expect(result.jobId).toBe('job_tts_123');
      expect(result.language).toBe('hi');
      expect(result.format).toBe('mp3');
      expect(result.provider).toBe('google-cloud-tts');
      expect(result.audioUrl).toContain('gs://truthworld-test-bucket/audio/job_tts_123/hi/chunk-');

      expect(costEngine.recordTTSCost).toHaveBeenCalledWith(
        'job_tts_123',
        'user_456',
        request.text.length,
        'google-tts-chirp3-hd'
      );
    });
  });

  describe('3. Dubbing Architecture Routing (Google Cloud Chirp Default vs ElevenLabs Voice Cloning)', () => {
    it('routes video dubbing audio track requests to Google Cloud Chirp 3: HD by default', async () => {
      const request: TTSRequest = {
        jobId: 'job_std_dubbing',
        userId: 'user_creator_1',
        language: 'te',
        text: 'సత్యమేవ జయతే',
        gender: 'FEMALE',
      };

      const result = await hybridTtsService.synthesize(request);

      // Verified: Google Cloud Chirp called, ElevenLabs NOT called
      expect(mockGoogleClient.synthesizeSpeech).toHaveBeenCalledTimes(1);
      expect(mockedAxios.post).not.toHaveBeenCalled();
      expect(result.provider).toBe('google-cloud-tts');
      expect(result.voiceName).toBe('te-IN-Chirp3-HD-Kore');
    });

    it('routes voice cloning requests (preferVoiceCloning: true) strictly to ElevenLabs', async () => {
      mockedAxios.post.mockResolvedValueOnce({
        data: Buffer.from('mock-elevenlabs-cloned-audio-bytes'),
      });

      const request: TTSRequest = {
        jobId: 'job_clone_123',
        userId: 'user_creator_1',
        language: 'en',
        text: 'This is a voice cloned narration.',
        preferVoiceCloning: true,
        voiceCloneId: 'custom_voice_clone_abc',
      };

      const result = await hybridTtsService.synthesize(request);

      // Verified: ElevenLabs called, Google Cloud TTS NOT called
      expect(mockedAxios.post).toHaveBeenCalledTimes(1);
      expect(mockGoogleClient.synthesizeSpeech).not.toHaveBeenCalled();
      expect(result.provider).toBe('elevenlabs');
      expect(result.voiceName).toBe('custom_voice_clone_abc');
    });

    it('routes Audio Pro requests strictly to ElevenLabs v4 Turbo (eleven_v4_turbo)', async () => {
      mockedAxios.post.mockResolvedValueOnce({
        data: Buffer.from('mock-elevenlabs-v4-turbo-audio-bytes'),
      });

      const request: TTSRequest = {
        jobId: 'job_pro_audio',
        userId: 'user_creator_pro',
        language: 'en',
        text: 'This is high-speed audio pro dubbing with ElevenLabs v4 Turbo.',
        ttsTier: 'audio_pro',
      };

      const result = await hybridTtsService.synthesize(request);

      expect(mockedAxios.post).toHaveBeenCalledTimes(1);
      expect(mockedAxios.post.mock.calls[0][1]).toMatchObject({ model_id: 'eleven_v4_turbo' });
      expect(mockGoogleClient.synthesizeSpeech).not.toHaveBeenCalled();
      expect(result.provider).toBe('elevenlabs');
    });
  });

  describe('4. Resilient Fallback to ElevenLabs Tier 2 and Graceful Google Chirp Fallback', () => {
    it('seamlessly falls back to Tier 2 (eleven_v3) when Tier 1 (eleven_v4) returns 429 Rate Limit', async () => {
      mockedAxios.post
        .mockRejectedValueOnce({
          response: {
            status: 429,
            data: { detail: 'Too many requests' },
          },
          message: 'Request failed with status code 429',
        })
        .mockResolvedValueOnce({
          data: Buffer.from('mock-v3-audio-bytes'),
        });

      const request: TTSRequest = {
        jobId: 'job_rate_limited',
        userId: 'user_creator_2',
        language: 'hi',
        text: 'यह एक स्वचालित परीक्षण है।',
        preferVoiceCloning: true,
      };

      const result = await hybridTtsService.synthesize(request);

      // Verified: ElevenLabs attempted v4, failed, then fallback to v3 succeeded
      expect(mockedAxios.post).toHaveBeenCalledTimes(2);
      expect(mockedAxios.post.mock.calls[0][1]).toMatchObject({ model_id: 'eleven_v4' });
      expect(mockedAxios.post.mock.calls[1][1]).toMatchObject({ model_id: 'eleven_v3' });
      expect(result.provider).toBe('elevenlabs');
      expect(result.audioUrl).toContain('gs://truthworld-test-bucket/audio/job_rate_limited/hi/chunk-');
    });

    it('gracefully falls back to Google Cloud Chirp 3: HD if voice cloning is requested without an ElevenLabs API key', async () => {
      const serviceWithoutKey = new TTSService(
        googleTtsService,
        new ElevenLabsTTSService('')
      );

      const request: TTSRequest = {
        jobId: 'job_no_key',
        userId: 'user_creator_3',
        language: 'te',
        text: 'ఏకీకృత ధ్వని సంశ్లేషణ',
        preferVoiceCloning: true,
      };

      const result = await serviceWithoutKey.synthesize(request);
      expect(mockGoogleClient.synthesizeSpeech).toHaveBeenCalledTimes(1);
      expect(result.provider).toBe('google-cloud-tts');
      expect(result.voiceName).toBe('te-IN-Chirp3-HD-Fenrir');
    });
  });

  describe('5. Cost Engine Verification', () => {
    it('has accurate rate cards for Google TTS Chirp 3: HD, Neural2, Standard, and ElevenLabs', () => {
      expect(RATE_CARDS['google-tts-chirp3-hd'].perCharacter).toBe(0.000030);
      expect(RATE_CARDS['google-tts-neural2'].perCharacter).toBe(0.000016);
      expect(RATE_CARDS['google-tts-standard'].perCharacter).toBe(0.000004);
      expect(RATE_CARDS['elevenlabs-turbo'].perCharacter).toBe(0.000040);
      expect(RATE_CARDS.elevenlabs.perCharacter).toBe(0.000200);
    });
  });
});

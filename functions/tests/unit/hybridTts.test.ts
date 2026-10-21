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

    it('selects high-fidelity Neural2 / Journey / Standard voices by gender', () => {
      // Hindi: Neural2
      const hiFemale = googleTtsService.resolveVoice({
        jobId: 'job_1', language: 'hi', text: 'नमस्ते', gender: 'FEMALE',
      });
      expect(hiFemale.locale).toBe('hi-IN');
      expect(hiFemale.voiceName).toBe('hi-IN-Neural2-A');
      expect(hiFemale.modelType).toBe('neural2');

      const hiMale = googleTtsService.resolveVoice({
        jobId: 'job_1', language: 'hi', text: 'नमस्ते', gender: 'MALE',
      });
      expect(hiMale.voiceName).toBe('hi-IN-Neural2-B');
      expect(hiMale.modelType).toBe('neural2');

      // Telugu: Native Standard subcontinent voice
      const teFemale = googleTtsService.resolveVoice({
        jobId: 'job_1', language: 'te', text: 'నమస్కారం', gender: 'FEMALE',
      });
      expect(teFemale.locale).toBe('te-IN');
      expect(teFemale.voiceName).toBe('te-IN-Standard-A');
      expect(teFemale.modelType).toBe('standard');

      // English: Journey natural voice
      const enFemale = googleTtsService.resolveVoice({
        jobId: 'job_1', language: 'en', text: 'Hello', gender: 'FEMALE',
      });
      expect(enFemale.locale).toBe('en-US');
      expect(enFemale.voiceName).toBe('en-US-Journey-F');
      expect(enFemale.modelType).toBe('journey');
    });

    it('maps legacy voiceId presets to gender when gender is omitted', () => {
      // Adam preset voiceId -> Male
      const adamVoice = googleTtsService.resolveVoice({
        jobId: 'job_1', language: 'hi', text: 'परीक्षण', voiceId: 'pNInz6obpgDQGcFmaJgB',
      });
      expect(adamVoice.voiceName).toBe('hi-IN-Neural2-B');

      // Bella preset voiceId -> Female
      const bellaVoice = googleTtsService.resolveVoice({
        jobId: 'job_1', language: 'te', text: 'పరీక్ష', voiceId: 'hpp4J3VqNfWAUOO0d1Us',
      });
      expect(bellaVoice.voiceName).toBe('te-IN-Standard-A');
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
        'google-tts-neural2'
      );
    });
  });

  describe('3. Hybrid Routing (Google Cloud TTS Default vs ElevenLabs Voice Cloning)', () => {
    it('routes standard dubbing requests to Google Cloud Text-to-Speech by default', async () => {
      const request: TTSRequest = {
        jobId: 'job_std_dubbing',
        userId: 'user_creator_1',
        language: 'te',
        text: 'సత్యమేవ జయతే',
        gender: 'FEMALE',
      };

      const result = await hybridTtsService.synthesize(request);

      // Verified: Google Cloud TTS called, ElevenLabs NOT called
      expect(mockGoogleClient.synthesizeSpeech).toHaveBeenCalledTimes(1);
      expect(mockedAxios.post).not.toHaveBeenCalled();
      expect(result.provider).toBe('google-cloud-tts');
    });

    it('routes voice cloning requests (preferVoiceCloning: true) to ElevenLabs', async () => {
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
  });

  describe('4. Resilient Fallback to Google Cloud Text-to-Speech', () => {
    it('seamlessly falls back to Google Cloud TTS when ElevenLabs returns 429 Rate Limit', async () => {
      mockedAxios.post.mockRejectedValue({
        response: {
          status: 429,
          data: { detail: 'Too many requests' },
        },
        message: 'Request failed with status code 429',
      });

      const request: TTSRequest = {
        jobId: 'job_rate_limited',
        userId: 'user_creator_2',
        language: 'hi',
        text: 'यह एक स्वचालित परीक्षण है।',
        preferVoiceCloning: true,
      };

      const result = await hybridTtsService.synthesize(request);

      // Verified: ElevenLabs attempted, failed, then fallback to Google Cloud TTS succeeded
      expect(mockedAxios.post).toHaveBeenCalled();
      expect(mockGoogleClient.synthesizeSpeech).toHaveBeenCalledTimes(1);
      expect(result.provider).toBe('google-cloud-tts');
      expect(result.audioUrl).toContain('gs://truthworld-test-bucket/audio/job_rate_limited/hi/chunk-');
    });

    it('falls back to Google Cloud TTS when ElevenLabs API key is missing', async () => {
      const noKeyElevenLabs = new ElevenLabsTTSService('');
      const fallbackHybrid = new TTSService(googleTtsService, noKeyElevenLabs);

      const request: TTSRequest = {
        jobId: 'job_no_key',
        userId: 'user_creator_3',
        language: 'te',
        text: 'ఏకీకృత ధ్వని సంశ్లేషణ',
        preferVoiceCloning: true,
      };

      const result = await fallbackHybrid.synthesize(request);

      expect(mockedAxios.post).not.toHaveBeenCalled();
      expect(mockGoogleClient.synthesizeSpeech).toHaveBeenCalledTimes(1);
      expect(result.provider).toBe('google-cloud-tts');
    });
  });

  describe('5. Cost Engine Verification', () => {
    it('has accurate rate cards for Google TTS Neural2, Standard, and ElevenLabs', () => {
      expect(RATE_CARDS['google-tts-standard'].perCharacter).toBe(0.000004);
      expect(RATE_CARDS['google-tts-neural2'].perCharacter).toBe(0.000016);
      expect(RATE_CARDS.elevenlabs.perCharacter).toBe(0.000030);

      // Google Neural2 is 46.7% cheaper than ElevenLabs
      expect(RATE_CARDS['google-tts-neural2'].perCharacter).toBeLessThan(RATE_CARDS.elevenlabs.perCharacter);

      // Google Standard is 86.7% cheaper than ElevenLabs
      expect(RATE_CARDS['google-tts-standard'].perCharacter).toBeLessThan(RATE_CARDS['google-tts-neural2'].perCharacter);
    });
  });
});

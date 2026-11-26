import * as admin from 'firebase-admin';
import {
  ExecutionPlan,
  isCredibilityEnabled,
  isDubbingEnabled,
  isSubtitlesEnabled,
  isLocalizationEnabled,
} from '../../src/pipeline/types';
import { InputLayer } from '../../src/pipeline/layers/02-input';
import { EdgeLayer } from '../../src/pipeline/layers/01-edge';
import { AggregationLayer } from '../../src/pipeline/layers/09-aggregation';
import { DistributionLayer } from '../../src/pipeline/layers/04-distribution';
import { mockBucket, mockFile } from '../setup';

jest.mock('../../src/notifications/notifications', () => ({
  notifyUser: jest.fn(async () => undefined),
}));

jest.mock('../../src/pipeline/services/reputationService', () => ({
  reputationService: {
    updateReputation: jest.fn(async () => undefined),
  },
}));

jest.mock('../../src/pipeline/services/speakerReputationService', () => ({
  SpeakerReputationService: jest.fn().mockImplementation(() => ({
    updateReputation: jest.fn(async () => undefined),
  })),
}));

describe('Credibility & Dubbing 100% System Independence', () => {
  const db = () => admin.firestore();

  beforeEach(() => {
    (mockBucket as any).name = 'truthworld-1.firebasestorage.app';
    jest.spyOn(DistributionLayer.prototype, 'checkAndMarkEventId').mockResolvedValue('NEW');
    jest.spyOn(DistributionLayer.prototype, 'publish').mockResolvedValue('msg_1');
  });

  it('InputLayer.createExecutionPlan uses clean domain flags and zero Path 1 / Path 2 aliases', () => {
    const inputLayer = new InputLayer();

    const credOnlyPlan = inputLayer.createExecutionPlan('job_cred', {
      userId: 'user_1',
      channelType: 'standard',
      languages: ['en'],
      dubbingMode: 'none',
      genLangSubs: false,
      generateDubbing: false,
      enableFactCheck: true,
      priority: 'normal',
    });

    expect('enablePath1' in (credOnlyPlan as any)).toBe(false);
    expect('enablePath2' in (credOnlyPlan as any)).toBe(false);
    expect('enableTruthEngine' in (credOnlyPlan as any)).toBe(false);
    expect('enableReachEngine' in (credOnlyPlan as any)).toBe(false);

    expect(isCredibilityEnabled(credOnlyPlan)).toBe(true);
    expect(isDubbingEnabled(credOnlyPlan)).toBe(false);
    expect(isSubtitlesEnabled(credOnlyPlan)).toBe(false);
    expect(isLocalizationEnabled(credOnlyPlan)).toBe(false);

    const dubOnlyPlan = inputLayer.createExecutionPlan('job_dub', {
      userId: 'user_1',
      channelType: 'standard',
      languages: ['en', 'es'],
      dubbingMode: 'voice_clone',
      genLangSubs: true,
      generateDubbing: true,
      enableFactCheck: false,
      priority: 'normal',
    });

    expect(isCredibilityEnabled(dubOnlyPlan)).toBe(false);
    expect(isDubbingEnabled(dubOnlyPlan)).toBe(true);
    expect(isSubtitlesEnabled(dubOnlyPlan)).toBe(true);
    expect(isLocalizationEnabled(dubOnlyPlan)).toBe(true);
  });

  it('finalizes Credibility immediately while Dubbing is still running, without prematurely completing video_jobs', async () => {
    const jobId = 'job_cred_fast';
    const videoId = '11111111-1111-4111-8111-111111111111';
    const userId = 'user_cred';

    const plan: ExecutionPlan = {
      jobId,
      videoId,
      languages: ['en', 'es'],
      primaryLanguage: 'en',
      enableCredibility: true,
      factCheckEnabled: true,
      enableDubbing: true,
      generateDubbing: true,
      enableSubtitles: true,
      genLangSubs: true,
      enableAuxiliary: true,
      dubbingMode: 'standard',
      channelType: 'standard',
      maxClaims: 50,
      priority: 'normal',
      skipCache: false,
    };

    const credPayload = {
      videoId,
      trustLabel: 'Verified',
      summary: 'Simple summary for viewers.',
      viewerNote: '',
      claims: [],
      factCheckStats: { totalClaims: 3, correct: 3, incorrect: 0, unverifiable: 0 },
      contextualFlags: [],
      confidenceNotes: [],
      diagnostics: [],
    };
    mockFile.download.mockResolvedValue([Buffer.from(JSON.stringify(credPayload))]);

    await db().collection('videos').doc(videoId).set({
      userId,
      status: 'published',
      title: 'Test Video',
    });
    await db().collection('video_jobs').doc(jobId).set({
      jobId,
      videoId,
      userId,
      status: 'processing',
      executionPlan: plan,
      outputs: {
        factCheckUrl: 'gs://truthworld-1.firebasestorage.app/factChecks/job_cred_fast/latest.json',
      },
      stages: {
        transcription: { status: 'completed', progress: 100 },
        copyright: { status: 'completed', progress: 100 },
        credibility: { status: 'running', progress: 90 },
        dubbing: { status: 'running', progress: 40 },
        translating_es: { status: 'running', progress: 40 },
        dubbing_es: { status: 'pending', progress: 0 },
      },
      createdAt: Date.now(),
      updatedAt: Date.now(),
    });

    const agg = new AggregationLayer({
      loadAnalysis: jest.fn(async () => null),
      saveAnalysis: jest.fn(async () => ({ path: 'final_outputs/job_cred_fast/latest.json' })),
    } as any);

    await agg.onStageComplete(jobId, 'credibility', userId, plan, 'evt_cred_1');

    const videoSnap = await db().collection('videos').doc(videoId).get();
    const credSubSnap = await db().collection('videos').doc(videoId).collection('media').doc('credibility').get();
    const jobSnap = await db().collection('video_jobs').doc(jobId).get();
    const credLedgerSnap = await db().collection('credibility_jobs').doc(jobId).get();

    expect(videoSnap.data()?.isFactChecked).toBe(true);
    expect(credSubSnap.exists).toBe(true);
    expect(credSubSnap.data()?.credibilityVerified).toBe(true);
    expect(credLedgerSnap.data()?.status).toBe('completed');
    expect(jobSnap.data()?.status).toBe('processing'); // Dubbing still running
  });

  it('converges Credibility to completed when Dubbing fails via EdgeLayer.failStage', async () => {
    const jobId = 'job_dub_fails_cred_ok';
    const videoId = '22222222-2222-4222-8222-222222222222';
    const userId = 'user_2';

    const plan: ExecutionPlan = {
      jobId,
      videoId,
      languages: ['en', 'hi'],
      primaryLanguage: 'en',
      enableCredibility: true,
      factCheckEnabled: true,
      enableDubbing: true,
      generateDubbing: true,
      enableSubtitles: true,
      genLangSubs: true,
      enableAuxiliary: true,
      dubbingMode: 'standard',
      channelType: 'standard',
      maxClaims: 50,
      priority: 'normal',
      skipCache: false,
    };

    const credPayload = {
      videoId,
      trustLabel: 'Verified',
      summary: 'Credibility finished independently.',
      claims: [],
      factCheckStats: { totalClaims: 2, correct: 2, incorrect: 0, unverifiable: 0 },
    };
    mockFile.download.mockResolvedValue([Buffer.from(JSON.stringify(credPayload))]);

    await db().collection('videos').doc(videoId).set({
      userId,
      status: 'published',
      title: 'Test Video 2',
    });
    await db().collection('video_jobs').doc(jobId).set({
      jobId,
      videoId,
      userId,
      status: 'processing',
      executionPlan: plan,
      outputs: {
        factCheckUrl: 'gs://truthworld-1.firebasestorage.app/factChecks/job_dub_fails_cred_ok/latest.json',
      },
      stages: {
        transcription: { status: 'completed', progress: 100 },
        copyright: { status: 'completed', progress: 100 },
        credibility: { status: 'running', progress: 90 },
        dubbing: { status: 'running', progress: 30 },
        translating_hi: { status: 'pending', progress: 0 },
        dubbing_hi: { status: 'pending', progress: 0 },
      },
      createdAt: Date.now(),
      updatedAt: Date.now(),
    });

    await EdgeLayer.failStage(jobId, 'dubbing', 'AssemblyAI STT unavailable');
    await EdgeLayer.upsertDubbingJob(jobId, { status: 'failed', error: 'AssemblyAI STT unavailable' });

    const jobMidSnap = await db().collection('video_jobs').doc(jobId).get();
    expect(jobMidSnap.data()?.status).toBe('processing');
    expect(jobMidSnap.data()?.stages?.dubbing?.status).toBe('failed');

    const agg = new AggregationLayer({
      loadAnalysis: jest.fn(async () => null),
      saveAnalysis: jest.fn(async () => ({ path: 'final_outputs/job_dub_fails_cred_ok/latest.json' })),
    } as any);

    await agg.onStageComplete(jobId, 'credibility', userId, plan, 'evt_cred_2');

    const jobEndSnap = await db().collection('video_jobs').doc(jobId).get();
    const videoEndSnap = await db().collection('videos').doc(videoId).get();
    const dubLedgerSnap = await db().collection('dubbing_jobs').doc(jobId).get();

    expect(jobEndSnap.data()?.status).toBe('completed');
    expect(jobEndSnap.data()?.stages?.dubbing?.status).toBe('failed');
    expect(dubLedgerSnap.data()?.status).toBe('failed');
    expect(videoEndSnap.data()?.isFactChecked).toBe(true);
  });

  it('converges Dubbing to completed and preserves pre-existing Credibility when Credibility fails', async () => {
    const jobId = 'job_cred_fails_dub_ok';
    const videoId = '33333333-3333-4333-8333-333333333333';
    const userId = 'user_3';

    const plan: ExecutionPlan = {
      jobId,
      videoId,
      languages: ['en', 'es'],
      primaryLanguage: 'en',
      enableCredibility: true,
      factCheckEnabled: true,
      enableDubbing: true,
      generateDubbing: true,
      enableSubtitles: true,
      genLangSubs: true,
      enableAuxiliary: true,
      dubbingMode: 'standard',
      channelType: 'standard',
      maxClaims: 50,
      priority: 'normal',
      skipCache: false,
    };

    await db().collection('videos').doc(videoId).set({
      userId,
      status: 'published',
      title: 'Test Video 3',
      isFactChecked: true,
      factCheckUrl: 'https://existing-report.example/report.json',
    });
    await db().collection('dubbing_results').doc(`${jobId}_es`).set({
      language: 'es',
      audioUrl: 'gs://truthworld-1.firebasestorage.app/dubs/es.mp3',
      videoUrl: 'gs://truthworld-1.firebasestorage.app/dubs/es.mp4',
      subtitleUrl: 'gs://truthworld-1.firebasestorage.app/subs/es.vtt',
      createdAt: Date.now(),
    });
    await db().collection('video_jobs').doc(jobId).set({
      jobId,
      videoId,
      userId,
      status: 'processing',
      executionPlan: plan,
      outputs: {
        audioTracks: { es: 'gs://truthworld-1.firebasestorage.app/dubs/es.mp3' },
        subtitles: { es: { vttPath: 'gs://truthworld-1.firebasestorage.app/subs/es.vtt' } },
      },
      stages: {
        transcription: { status: 'completed', progress: 100 },
        copyright: { status: 'completed', progress: 100 },
        credibility: { status: 'running', progress: 50 },
        dubbing: { status: 'running', progress: 95 },
        translating_es: { status: 'completed', progress: 100 },
        dubbing_es: { status: 'completed', progress: 100 },
      },
      createdAt: Date.now(),
      updatedAt: Date.now(),
    });

    await EdgeLayer.failStage(jobId, 'credibility', 'Vertex quota exhausted');
    await EdgeLayer.upsertCredibilityJob(jobId, { status: 'failed', error: 'Vertex quota exhausted' });

    const agg = new AggregationLayer({
      loadAnalysis: jest.fn(async () => null),
      saveAnalysis: jest.fn(async () => ({ path: 'final_outputs/job_cred_fails_dub_ok/latest.json' })),
    } as any);

    await agg.onStageComplete(jobId, 'dubbing', userId, plan, 'evt_dub_3');

    const jobEndSnap = await db().collection('video_jobs').doc(jobId).get();
    const videoEndSnap = await db().collection('videos').doc(videoId).get();
    const locSubSnap = await db().collection('videos').doc(videoId).collection('media').doc('localization').get();

    expect(jobEndSnap.data()?.status).toBe('completed');
    expect(locSubSnap.exists).toBe(true);
    expect(videoEndSnap.data()?.audioTracks?.es).toBeTruthy();
    // Must not overwrite existing Credibility data when Dubbing completes
    expect(videoEndSnap.data()?.isFactChecked).toBe(true);
    expect(videoEndSnap.data()?.factCheckUrl).toBe('https://existing-report.example/report.json');
  });

  it('marks video_jobs failed only when ALL enabled systems fail', async () => {
    const jobId = 'job_both_fail';
    const videoId = '44444444-4444-4444-8444-444444444444';
    const userId = 'user_4';

    const plan: ExecutionPlan = {
      jobId,
      videoId,
      languages: ['en', 'fr'],
      primaryLanguage: 'en',
      enableCredibility: true,
      factCheckEnabled: true,
      enableDubbing: true,
      generateDubbing: true,
      enableSubtitles: false,
      genLangSubs: false,
      enableAuxiliary: false,
      dubbingMode: 'standard',
      channelType: 'standard',
      maxClaims: 50,
      priority: 'normal',
      skipCache: false,
    };

    await db().collection('videos').doc(videoId).set({ userId, status: 'processing' });
    await db().collection('video_jobs').doc(jobId).set({
      jobId,
      videoId,
      userId,
      status: 'processing',
      executionPlan: plan,
      stages: {
        transcription: { status: 'completed', progress: 100 },
        copyright: { status: 'completed', progress: 100 },
        credibility: { status: 'running', progress: 50 },
        dubbing: { status: 'running', progress: 20 },
      },
      createdAt: Date.now(),
      updatedAt: Date.now(),
    });

    await EdgeLayer.failStage(jobId, 'credibility', 'Cred error');
    await EdgeLayer.failStage(jobId, 'dubbing', 'Dub error');

    const agg = new AggregationLayer({
      loadAnalysis: jest.fn(async () => null),
      saveAnalysis: jest.fn(async () => ({ path: 'final_outputs/job_both_fail/latest.json' })),
    } as any);

    await agg.onStageComplete(jobId, 'dubbing', userId, plan, 'evt_dub_4');

    const jobEndSnap = await db().collection('video_jobs').doc(jobId).get();
    expect(jobEndSnap.data()?.status).toBe('failed');
  });
});

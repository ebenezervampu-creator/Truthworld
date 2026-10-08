import {
  checkAndMarkEventId,
  markEventCompleted,
  markEventFailed,
} from '../../src/shared/idempotency';
import { testFirestore } from '../helpers/mockFirestore';

describe('Unit: Idempotency Engine', () => {
  beforeEach(() => {
    testFirestore.clear();
  });

  it('marks a brand new event as NEW and transitions to PROCESSING', async () => {
    const eventId = 'evt_test_new_1';
    const jobId = 'job_1';

    const status = await checkAndMarkEventId(eventId, jobId);
    expect(status).toBe('NEW');

    const doc = await testFirestore.collection('processed_events').doc(eventId).get();
    expect(doc.exists).toBe(true);
    expect(doc.data()?.status).toBe('PROCESSING');
    expect(doc.data()?.jobId).toBe(jobId);
  });

  it('detects a completed event and prevents duplicate processing', async () => {
    const eventId = 'evt_test_completed_2';
    const jobId = 'job_2';

    await checkAndMarkEventId(eventId, jobId);
    await markEventCompleted(eventId);

    const status = await checkAndMarkEventId(eventId, 'job_worker_duplicate');
    expect(status).toBe('COMPLETED');
  });

  it('allows self-healing re-run for failed tasks', async () => {
    const eventId = 'evt_test_failed_3';
    const jobId = 'job_3';

    await checkAndMarkEventId(eventId, jobId);
    await markEventFailed(eventId, 'Timeout during third-party gateway call');

    const status = await checkAndMarkEventId(eventId, 'job_worker_retry');
    expect(status).toBe('NEW');

    const doc = await testFirestore.collection('processed_events').doc(eventId).get();
    expect(doc.data()?.status).toBe('PROCESSING');
  });

  it('throws an error when eventId or jobId is missing', async () => {
    await expect(checkAndMarkEventId('', 'job_4')).rejects.toThrow('Missing idempotency keys');
    await expect(checkAndMarkEventId('evt_4', '')).rejects.toThrow('Missing idempotency keys');
  });
});

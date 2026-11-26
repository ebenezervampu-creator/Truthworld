import 'package:flutter_test/flutter_test.dart';
import 'package:truthworld/features/dubbing/data/dubbing_service.dart';
import 'package:truthworld/features/dubbing/data/models/dubbing_job.dart';

void main() {
  group('DubbingService.mergeJobWithVideoJobData', () {
    final baseStudioData = <String, dynamic>{
      'id': 'dub_dubjob_30s_1000',
      'userId': 'user_1',
      'title': 'WhatsApp Video 30s',
      'mode': 'dubbing',
      'status': 'processing',
      'progressPercent': 10,
      'currentStepMessage': 'Extracting dialogue and generating transcription...',
      'sourceMediaUrl': 'https://firebasestorage.googleapis.com/v0/b/truthworld-1.firebasestorage.app/o/dubbing_uploads%2Fu1%2Fclip.mp4?alt=media',
      'sourceMediaType': 'video',
      'durationSeconds': 32,
      'characterCount': 0,
      'sourceLanguage': 'en',
      'targetLanguages': ['te'],
      'pipelineJobId': 'dubjob_30s',
      'createdAt': 1700000000000,
    };

    test('parses pipelineJobId and error on DubbingJob.fromMap', () {
      final job = DubbingJob.fromMap({
        ...baseStudioData,
        'error': 'Custom error',
      });
      expect(job.pipelineJobId, 'dubjob_30s');
      expect(job.error, 'Custom error');
      expect(job.videoId, isNull);
    });

    test('advances standalone upload beyond 10% through transcription and dubbing stages', () {
      final transJob = DubbingService.mergeJobWithVideoJobData(baseStudioData, {
        'status': 'processing',
        'stages': {
          'transcription': {'status': 'running', 'progress': 60},
          'dubbing': {'status': 'pending', 'progress': 0},
        },
      });
      expect(transJob.status, DubbingJobStatus.transcribing);
      expect(transJob.progressPercent, 25);
      expect(transJob.stages?['audio_extraction']?['status'], 'completed');

      final synthJob = DubbingService.mergeJobWithVideoJobData(baseStudioData, {
        'status': 'processing',
        'stages': {
          'transcription': {'status': 'completed', 'progress': 100},
          'dubbing': {'status': 'running', 'progress': 65},
        },
      });
      expect(synthJob.status, DubbingJobStatus.synthesizingSpeech);
      expect(synthJob.progressPercent, greaterThanOrEqualTo(60));
      expect(synthJob.stages?['transcription']?['status'], 'completed');

      final doneJob = DubbingService.mergeJobWithVideoJobData(baseStudioData, {
        'status': 'completed',
        'stages': {
          'transcription': {'status': 'completed', 'progress': 100},
          'dubbing': {'status': 'completed', 'progress': 100},
        },
      });
      expect(doneJob.status, DubbingJobStatus.completed);
      expect(doneJob.progressPercent, 100);
      expect(doneJob.stages?['mastering']?['status'], 'completed');
    });

    test('does not mark dubbing completed when video_jobs.status is published', () {
      final midJob = DubbingService.mergeJobWithVideoJobData(baseStudioData, {
        'status': 'published',
        'stages': {
          'transcription': {'status': 'completed', 'progress': 100},
          'dubbing': {'status': 'pending', 'progress': 0},
        },
      });
      expect(midJob.status, DubbingJobStatus.translating);
      expect(midJob.progressPercent, 35);
    });

    test('handles subtitles_only completion via stages.subtitles', () {
      final subStudioData = <String, dynamic>{
        ...baseStudioData,
        'mode': 'subtitles_only',
      };
      final doneSubJob = DubbingService.mergeJobWithVideoJobData(subStudioData, {
        'status': 'processing',
        'stages': {
          'transcription': {'status': 'completed', 'progress': 100},
          'dubbing': {'status': 'skipped', 'progress': 100},
          'subtitles': {'status': 'completed', 'progress': 100},
        },
      });
      expect(doneSubJob.status, DubbingJobStatus.completed);
      expect(doneSubJob.progressPercent, 100);
    });

    test('surfaces stage failures cleanly with friendly message', () {
      final failedJob = DubbingService.mergeJobWithVideoJobData(baseStudioData, {
        'status': 'processing',
        'stages': {
          'transcription': {'status': 'completed', 'progress': 100},
          'dubbing': {'status': 'failed', 'error': 'We could not complete the Telugu dub.'},
        },
      });
      expect(failedJob.status, DubbingJobStatus.failed);
      expect(failedJob.error, 'We could not complete the Telugu dub.');
    });

    test('populates segmentsByLanguage from video_jobs transcription segments', () {
      final withSegments = DubbingService.mergeJobWithVideoJobData(baseStudioData, {
        'status': 'processing',
        'stages': {
          'transcription': {'status': 'completed', 'progress': 100},
          'dubbing': {'status': 'running', 'progress': 25},
        },
        'transcription': {
          'segments': [
            {'start': 0.0, 'end': 3.5, 'text': 'Welcome to TruthWorld.', 'speaker': 'speaker_0'},
          ],
        },
      });
      expect(withSegments.segmentsByLanguage['en'], isNotNull);
      expect(withSegments.segmentsByLanguage['en']!.length, 1);
      expect(withSegments.segmentsByLanguage['en']!.first.originalText, 'Welcome to TruthWorld.');
    });

    test('reports failed instead of completed when stages.dubbing fails even if video_jobs.status is completed', () {
      final failedJob = DubbingService.mergeJobWithVideoJobData(
        {
          ...baseStudioData,
          'status': 'completed',
          'progressPercent': 100,
        },
        {
          'status': 'completed',
          'stages': {
            'transcription': {'status': 'completed', 'progress': 100},
            'dubbing': {'status': 'failed', 'error': 'We could not complete the Telugu dub.'},
            'subtitles': {'status': 'completed', 'progress': 100},
          },
        },
      );
      expect(failedJob.status, DubbingJobStatus.failed);
      expect(failedJob.error, 'We could not complete the Telugu dub.');
    });
  });
}

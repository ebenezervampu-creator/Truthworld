import 'package:flutter_test/flutter_test.dart';
import 'package:truthworld/features/dubbing/data/models/dubbing_job.dart';

void main() {
  group('DubbingJobStatus.fromString', () {
    test('maps pipeline statuses explicitly', () {
      expect(DubbingJobStatus.fromString('pending'), DubbingJobStatus.pending);
      expect(DubbingJobStatus.fromString('running'), DubbingJobStatus.running);
      expect(DubbingJobStatus.fromString('completed'), DubbingJobStatus.completed);
      expect(DubbingJobStatus.fromString('failed'), DubbingJobStatus.failed);
    });

    test('maps pipeline statuses case-insensitively with whitespace', () {
      expect(DubbingJobStatus.fromString(' PENDING '), DubbingJobStatus.pending);
      expect(DubbingJobStatus.fromString('Running'), DubbingJobStatus.running);
      expect(DubbingJobStatus.fromString('COMPLETED'), DubbingJobStatus.completed);
      expect(DubbingJobStatus.fromString(' Failed '), DubbingJobStatus.failed);
    });

    test('maps all studio stage statuses', () {
      expect(DubbingJobStatus.fromString('queued'), DubbingJobStatus.queued);
      expect(DubbingJobStatus.fromString('processing'), DubbingJobStatus.processing);
      expect(DubbingJobStatus.fromString('ingesting'), DubbingJobStatus.ingesting);
      expect(DubbingJobStatus.fromString('demuxing'), DubbingJobStatus.demuxing);
      expect(DubbingJobStatus.fromString('diarizing'), DubbingJobStatus.diarizing);
      expect(DubbingJobStatus.fromString('transcribing'), DubbingJobStatus.transcribing);
      expect(DubbingJobStatus.fromString('awaiting_transcription_review'), DubbingJobStatus.awaitingTranscriptionReview);
      expect(DubbingJobStatus.fromString('translating'), DubbingJobStatus.translating);
      expect(DubbingJobStatus.fromString('synthesizing_speech'), DubbingJobStatus.synthesizingSpeech);
      expect(DubbingJobStatus.fromString('awaiting_post_tts_review'), DubbingJobStatus.awaitingPostTtsReview);
      expect(DubbingJobStatus.fromString('muxing_audio'), DubbingJobStatus.muxingAudio);
      expect(DubbingJobStatus.fromString('generating_subtitles'), DubbingJobStatus.generatingSubtitles);
    });

    test('unknown status or null defaults to neutral processing (never failed)', () {
      expect(DubbingJobStatus.fromString(null), DubbingJobStatus.processing);
      expect(DubbingJobStatus.fromString(''), DubbingJobStatus.processing);
      expect(DubbingJobStatus.fromString('some_unexpected_stage'), DubbingJobStatus.processing);
      expect(DubbingJobStatus.fromString('in_progress'), DubbingJobStatus.processing);
      expect(DubbingJobStatus.fromString('waiting_for_gpu'), DubbingJobStatus.processing);
    });
  });
}

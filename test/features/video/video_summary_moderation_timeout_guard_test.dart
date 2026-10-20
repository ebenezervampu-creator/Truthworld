import 'package:flutter_test/flutter_test.dart';
import 'package:truthworld/core/ux/user_feedback_sanitizer.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/features/video/data/models/video_media.dart';

void main() {
  group('Video Summary Moderation Timeout Guard Tests', () {
    test('UserFeedbackSanitizer.isValidVideoSummary rejects moderation timeout and developer errors', () {
      // Direct timeout messages
      expect(
        UserFeedbackSanitizer.isValidVideoSummary(
          'Moderation timed out — video approved pending async review.',
        ),
        isFalse,
      );
      expect(
        UserFeedbackSanitizer.isValidVideoSummary(
          'Moderation timed out - video appproved pending async review',
        ),
        isFalse,
      );
      expect(
        UserFeedbackSanitizer.isValidVideoSummary(
          'Moderation could not complete — video approved pending async review.',
        ),
        isFalse,
      );
      expect(
        UserFeedbackSanitizer.isValidVideoSummary(
          'Video verification in progress. Content held safely in review queue.',
        ),
        isFalse,
      );
      expect(
        UserFeedbackSanitizer.isValidVideoSummary(
          'Video held for Admin manual review.',
        ),
        isFalse,
      );
      expect(
        UserFeedbackSanitizer.isValidVideoSummary(
          'Automatic Gemini moderation bypassed per system settings. Held for manual admin decision.',
        ),
        isFalse,
      );
      expect(
        UserFeedbackSanitizer.isValidVideoSummary('Summary unavailable.'),
        isFalse,
      );
      expect(
        UserFeedbackSanitizer.isValidVideoSummary(null),
        isFalse,
      );
      expect(
        UserFeedbackSanitizer.isValidVideoSummary('   '),
        isFalse,
      );
    });

    test('UserFeedbackSanitizer.isValidVideoSummary accepts genuine video summaries', () {
      expect(
        UserFeedbackSanitizer.isValidVideoSummary(
          'A live worship performance of the song Mahonathuda by Raj Prakash Paul at Lords Church conference.',
        ),
        isTrue,
      );
      expect(
        UserFeedbackSanitizer.isValidVideoSummary(
          'In this tutorial, we explore advanced Flutter state management techniques with GetX.',
        ),
        isTrue,
      );
    });

    test('VideoMapParser never leaks moderation timeout message into video.moderationSummary', () {
      final rawData = <String, dynamic>{
        'id': 'video_raj_prakash_paul_worship',
        'title': 'Mahonathuda song by Raj prakash paul worship conference',
        'description': 'Lords Church worship conference',
        'videoUrl': 'https://storage.example.com/video.mp4',
        'thumbnailUrl': 'https://storage.example.com/thumb.jpg',
        'channelId': 'ch_1',
        'channelName': 'Ebenezer Vampu',
        'category': 'Music',
        'tags': ['worship', 'conference'],
        'moderation': {
          'status': 'approved',
          'summary': 'Moderation timed out — video approved pending async review.',
          'explanation': 'Moderation timed out — video approved pending async review.',
          'policyAction': 'allow',
        },
      };

      final video = Video.fromMap(rawData, 'video_raj_prakash_paul_worship');
      expect(video.moderationSummary, isEmpty);
      // summary getter falls back to description since no genuine AI summary is available yet
      expect(video.summary, equals('Lords Church worship conference'));
    });

    test('VideoMapParser preserves genuine summary when provided', () {
      final rawData = <String, dynamic>{
        'id': 'video_genuine_summary',
        'title': 'Mahonathuda song by Raj prakash paul worship conference',
        'description': 'Lords Church worship conference',
        'videoUrl': 'https://storage.example.com/video.mp4',
        'thumbnailUrl': 'https://storage.example.com/thumb.jpg',
        'channelId': 'ch_1',
        'channelName': 'Ebenezer Vampu',
        'category': 'Music',
        'tags': ['worship', 'conference'],
        'summary': 'A live gospel worship service presenting spiritual songs and prayers.',
        'moderation': {
          'status': 'approved',
          'summary': 'Moderation timed out — video approved pending async review.',
        },
      };

      final video = Video.fromMap(rawData, 'video_genuine_summary');
      expect(
        video.moderationSummary,
        equals('A live gospel worship service presenting spiritual songs and prayers.'),
      );
      expect(
        video.summary,
        equals('A live gospel worship service presenting spiritual songs and prayers.'),
      );
    });

    test('UserFeedbackSanitizer.isValidVideoSummary rejects raw transcript snippets and cuts', () {
      const transcriptSnippet =
          "Welcome to This Explainer. Today we're cracking open one of the most universally debated questions out there. It's something you've probably pondered while standing totally confused in the grocery ...";
      expect(
        UserFeedbackSanitizer.isValidVideoSummary(transcriptSnippet),
        isFalse,
      );

      const fullTranscript =
          "Welcome to This Explainer. Today we're cracking open one of the most universally debated questions out there. It's something you've probably pondered while standing totally confused in the grocery aisle holding a carton of eggs.";
      expect(
        UserFeedbackSanitizer.isValidVideoSummary(
          "Welcome to This Explainer. Today we're cracking open one of the most universally debated questions out there.",
          transcript: fullTranscript,
        ),
        isFalse,
      );
    });

    test('VideoMediaCredibility.fromMap filters out moderation timeout strings', () {
      final credData = <String, dynamic>{
        'trustScore': 90.0,
        'summary': 'Moderation timed out — video approved pending async review.',
      };

      final cred = VideoMediaCredibility.fromMap(credData);
      expect(cred.summary, isEmpty);

      final genuineCredData = <String, dynamic>{
        'trustScore': 95.0,
        'summary': 'Comprehensive theological exposition and worship service breakdown.',
      };

      final genuineCred = VideoMediaCredibility.fromMap(genuineCredData);
      expect(
        genuineCred.summary,
        equals('Comprehensive theological exposition and worship service breakdown.'),
      );
    });
  });
}

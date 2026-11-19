import 'package:flutter_test/flutter_test.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/features/video/presentation/views/player/models/player_models.dart';

void main() {
  group('Video Model and Parser Audio Tracks Tests', () {
    test('Video correctly instantiates with direct audioTracks and dubbedVideos', () {
      final video = Video(
        id: 'test_vid_1',
        title: 'Dubbed Video Test',
        description: 'Testing dubbed audio tracks',
        thumbnailUrl: 'https://example.com/thumb.jpg',
        ownerId: 'owner_1',
        channelId: 'channel_1',
        channelName: 'TruthWorld Studios',
        category: 'Technology',
        tags: const ['tech', 'dubbing'],
        videoUrl: 'https://storage.googleapis.com/test/vid.mp4',
        jobId: 'job_1790251383_test',
        audioTracks: {
          'te': 'https://firebasestorage.googleapis.com/v0/b/truthworld.appspot.com/o/audio%2Fjob_1790251383%2Fte%2Fstitched.mp3?alt=media',
          'be': 'https://firebasestorage.googleapis.com/v0/b/truthworld.appspot.com/o/audio%2Fjob_1790251383%2Fbe%2Fstitched.mp3?alt=media',
        },
        dubbedVideos: {
          'te': 'https://firebasestorage.googleapis.com/v0/b/truthworld.appspot.com/o/videos%2Fjob_1790251383%2Fte.mp4?alt=media',
        },
      );

      expect(video.jobId, equals('job_1790251383_test'));
      expect(video.audioTracks.length, equals(2));
      expect(video.audioTracks['te'], contains('te%2Fstitched.mp3'));
      expect(video.audioTracks['be'], contains('be%2Fstitched.mp3'));
      expect(video.dubbedVideos['te'], contains('te.mp4'));
    });

    test('VideoMapParser parses audioTracks and dubbedVideos from top-level fields', () {
      final docMap = {
        'id': 'vid_123',
        'title': 'Test Video',
        'channelName': 'TruthWorld',
        'videoUrl': 'https://example.com/video.mp4',
        'language': 'en',
        'jobId': 'job_998877',
        'audioTracks': {
          'te': 'audio/job_998877/te/stitched.mp3',
          'be': 'audio/job_998877/be/stitched.mp3',
        },
        'dubbedVideos': {
          'te': 'videos/job_998877/te.mp4',
        },
      };

      final video = VideoMapParser.parse(docMap, 'vid_123');

      expect(video.id, equals('vid_123'));
      expect(video.jobId, equals('job_998877'));
      expect(video.audioTracks['te'], equals('audio/job_998877/te/stitched.mp3'));
      expect(video.audioTracks['be'], equals('audio/job_998877/be/stitched.mp3'));
      expect(video.dubbedVideos['te'], equals('videos/job_998877/te.mp4'));
    });

    test('VideoMapParser parses audioTracks from nested media map', () {
      final docMap = {
        'id': 'vid_456',
        'title': 'Test Nested Media',
        'channelName': 'TruthWorld',
        'videoUrl': 'https://example.com/video.mp4',
        'media': {
          'jobId': 'job_12345',
          'audioTracks': {
            'te': 'https://storage.truthworld.in/audio/te.mp3',
            'be': 'https://storage.truthworld.in/audio/be.mp3',
          },
          'dubbedVideos': {
            'be': 'https://storage.truthworld.in/video/be.mp4',
          },
        },
      };

      final video = VideoMapParser.parse(docMap, 'vid_456');

      expect(video.jobId, equals('job_12345'));
      expect(video.audioTracks['te'], equals('https://storage.truthworld.in/audio/te.mp3'));
      expect(video.audioTracks['be'], equals('https://storage.truthworld.in/audio/be.mp3'));
      expect(video.dubbedVideos['be'], equals('https://storage.truthworld.in/video/be.mp4'));
    });

    test('VideoMapParser parses structured audioTracks descriptor maps and prioritizes hlsMasterUrl', () {
      final docMap = {
        'id': 'vid_hls_canary',
        'title': 'Canary Multi-Audio Video',
        'channelName': 'TruthWorld Studios',
        'videoUrl': 'https://storage.googleapis.com/test-bucket/videos/vid_canary/raw.mp4',
        'hlsMasterUrl': 'https://storage.googleapis.com/test-bucket/videos/vid_canary/master.m3u8',
        'hlsUrl': 'https://storage.googleapis.com/test-bucket/videos/vid_canary/prog.m3u8',
        'audioTracks': {
          'te': {
            'language': 'te',
            'name': 'తెలుగు (Telugu)',
            'audioUrl': 'https://storage.googleapis.com/test-bucket/audio/job_canary/te/stitched.mp3',
            'playlistUrl': 'https://storage.googleapis.com/test-bucket/videos/vid_canary/audio/te/prog.m3u8',
          },
          'hi': {
            'language': 'hi',
            'name': 'हिन्दी (Hindi)',
            'audioUrl': 'https://storage.googleapis.com/test-bucket/audio/job_canary/hi/stitched.mp3',
            'playlistUrl': 'https://storage.googleapis.com/test-bucket/videos/vid_canary/audio/hi/prog.m3u8',
          },
        },
      };

      final video = VideoMapParser.parse(docMap, 'vid_hls_canary');

      expect(video.id, equals('vid_hls_canary'));
      expect(video.hlsUrl, equals('https://storage.googleapis.com/test-bucket/videos/vid_canary/master.m3u8'));
      expect(video.audioTracks['te'], equals('https://storage.googleapis.com/test-bucket/audio/job_canary/te/stitched.mp3'));
      expect(video.audioTracks['hi'], equals('https://storage.googleapis.com/test-bucket/audio/job_canary/hi/stitched.mp3'));
    });

    test('Video.copyWith preserves or updates audioTracks and jobId', () {
      final original = Video(
        id: 'orig_1',
        title: 'Orig Title',
        description: 'Orig desc',
        thumbnailUrl: 'https://example.com/t.jpg',
        ownerId: 'u1',
        channelId: 'c1',
        channelName: 'TruthWorld',
        category: 'General',
        tags: const [],
        videoUrl: 'https://example.com/v.mp4',
        jobId: 'job_original',
        audioTracks: {'te': 'audio/te.mp3'},
      );

      final updated = original.copyWith(
        jobId: 'job_new',
        audioTracks: {
          'te': 'audio/te.mp3',
          'be': 'audio/be.mp3',
        },
      );

      expect(updated.id, equals('orig_1'));
      expect(updated.jobId, equals('job_new'));
      expect(updated.audioTracks.length, equals(2));
      expect(updated.audioTracks.containsKey('be'), isTrue);
      expect(original.audioTracks.length, equals(1));
    });

    test('AudioTrack model constructs with valid types and labels', () {
      const trackTe = AudioTrack(
        label: 'Telugu (Audio)',
        langCode: 'te',
        type: 'Audio',
        url: 'https://example.com/audio/te.mp3',
      );

      const trackBe = AudioTrack(
        label: 'Belarusian (Audio)',
        langCode: 'be',
        type: 'Audio',
        url: 'https://example.com/audio/be.mp3',
      );

      expect(trackTe.langCode, equals('te'));
      expect(trackTe.label, equals('Telugu (Audio)'));
      expect(trackTe.type, equals('Audio'));
      expect(trackTe.url, equals('https://example.com/audio/te.mp3'));

      expect(trackBe.langCode, equals('be'));
      expect(trackBe.label, equals('Belarusian (Audio)'));
      expect(trackBe.type, equals('Audio'));
      expect(trackBe.url, equals('https://example.com/audio/be.mp3'));
    });
  });
}

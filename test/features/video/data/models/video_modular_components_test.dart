import 'package:flutter_test/flutter_test.dart';
import 'package:truthworld/features/video/data/models/video.dart';

void main() {
  group('VideoDurationUtils Unit Tests', () {
    test('parseDuration handles Duration object directly', () {
      const d = Duration(minutes: 5, seconds: 30);
      expect(VideoDurationUtils.parseDuration(d), d);
    });

    test('parseDuration handles null gracefully', () {
      expect(VideoDurationUtils.parseDuration(null), Duration.zero);
    });

    test('parseDuration handles int milliseconds (> 100,000)', () {
      expect(
        VideoDurationUtils.parseDuration(180000),
        const Duration(minutes: 3),
      );
    });

    test('parseDuration handles int seconds (<= 100,000)', () {
      expect(
        VideoDurationUtils.parseDuration(90),
        const Duration(seconds: 90),
      );
    });

    test('parseDuration handles double seconds', () {
      expect(
        VideoDurationUtils.parseDuration(120.5),
        const Duration(seconds: 120),
      );
    });

    test('parseDuration handles mm:ss string', () {
      expect(
        VideoDurationUtils.parseDuration('12:45'),
        const Duration(minutes: 12, seconds: 45),
      );
    });

    test('parseDuration handles hh:mm:ss string', () {
      expect(
        VideoDurationUtils.parseDuration('01:15:30'),
        const Duration(hours: 1, minutes: 15, seconds: 30),
      );
    });

    test('parseDuration handles numeric string', () {
      expect(
        VideoDurationUtils.parseDuration('250000'),
        const Duration(milliseconds: 250000),
      );
      expect(
        VideoDurationUtils.parseDuration('45'),
        const Duration(seconds: 45),
      );
    });

    test('parseDuration returns Duration.zero for invalid string', () {
      expect(VideoDurationUtils.parseDuration('invalid_time'), Duration.zero);
      expect(VideoDurationUtils.parseDuration(''), Duration.zero);
    });

    test('formatDuration formats < 1 hour to mm:ss', () {
      const d = Duration(minutes: 4, seconds: 9);
      expect(VideoDurationUtils.formatDuration(d), '04:09');
    });

    test('formatDuration formats >= 1 hour to hh:mm:ss', () {
      const d = Duration(hours: 2, minutes: 5, seconds: 8);
      expect(VideoDurationUtils.formatDuration(d), '02:05:08');
    });
  });

  group('VideoResolutions Unit Tests', () {
    test('VideoResolutionV2 handles fromMap and toMap', () {
      final res = VideoResolutionV2.fromMap({
        'label': '1080p',
        'url': 'https://example.com/1080.mp4',
        'width': 1920,
        'height': 1080,
        'bitrate': 4500000,
      });

      expect(res.label, '1080p');
      expect(res.url, 'https://example.com/1080.mp4');
      expect(res.width, 1920);
      expect(res.height, 1080);
      expect(res.bitrate, 4500000);

      final map = res.toMap();
      expect(map['label'], '1080p');
      expect(map['width'], 1920);
    });

    test('ResolutionV2 compatibility wrapper stores path', () {
      final res = ResolutionV2('https://example.com/stream.m3u8');
      expect(res.path, 'https://example.com/stream.m3u8');
    });

    test('VideoStatus has all 10 expected pipeline statuses', () {
      expect(VideoStatus.values.length, 10);
      expect(VideoStatus.values.map((e) => e.name), containsAll([
        'uploading',
        'processing',
        'ready',
        'flagged',
        'deleted',
        'private',
        'scheduled',
        'rejected',
        'pending_review',
        'draft',
      ]));
    });
  });

  group('VideoMapParser Unit Tests', () {
    test('generates fallback resolutions when adaptiveResolutions is empty', () {
      final video = Video.fromMap({
        'id': 'vid_res_test',
        'title': 'Resolution Fallback Video',
        'videoUrl': 'https://example.com/fallback.mp4',
        'ownerId': 'owner_1',
        'channelId': 'ch_1',
      });

      expect(video.adaptiveResolutions.length, 6);
      expect(video.adaptiveResolutions.first.label, '1080p');
      expect(video.adaptiveResolutions.last.label, '144p');
    });

    test('infers title from autoChapters when title is empty', () {
      final video = Video.fromMap({
        'id': 'vid_chap_title',
        'title': '',
        'autoChapters': [
          {'title': 'Inferred Chapter Title', 'startMs': 0},
        ],
        'ownerId': 'owner_1',
        'channelId': 'ch_1',
      });

      expect(video.title, 'Inferred Chapter Title');
    });

    test('infers title from summary when chapters are absent', () {
      final video = Video.fromMap({
        'id': 'vid_summary_title',
        'title': 'untitled',
        'summary': 'A comprehensive exploration of science and astronomy.',
        'ownerId': 'owner_1',
        'channelId': 'ch_1',
      });

      expect(
        video.title,
        'A comprehensive exploration of science and astronomy.',
      );
    });

    test('resolves moderation approval correctly', () {
      final approvedVideo = Video.fromMap({
        'id': 'vid_appr',
        'title': 'Approved Video',
        'status': 'ready',
        'moderation': {'status': 'approved'},
        'ownerId': 'owner_1',
        'channelId': 'ch_1',
      });
      expect(approvedVideo.geminiApproved, isTrue);
      expect(approvedVideo.isApproved, isTrue);
      expect(approvedVideo.isApprovedByGeminiOrManual, isTrue);

      final rejectedVideo = Video.fromMap({
        'id': 'vid_rej',
        'title': 'Rejected Video',
        'status': 'rejected',
        'geminiApproved': false,
        'ownerId': 'owner_1',
        'channelId': 'ch_1',
      });
      expect(rejectedVideo.isApprovedByGeminiOrManual, isFalse);
    });
  });

  group('Video Status Helpers & Serializer Tests', () {
    test('isDraft and isUntitled identify untitled and draft videos', () {
      final draftVideo = Video(
        id: 'draft_1',
        title: 'Untitled Video',
        description: '',
        thumbnailUrl: '',
        ownerId: 'u1',
        channelId: 'c1',
        channelName: 'Channel',
        category: 'Tech',
        tags: [],
        status: VideoStatus.draft,
      );

      expect(draftVideo.isDraft, isTrue);
      expect(draftVideo.isUntitled, isTrue);
      expect(draftVideo.isUploadingOrProcessing, isTrue);
    });

    test('toOffline converts Video to OfflineVideo accurately', () {
      final video = Video(
        id: 'off_1',
        title: 'Offline Tutorial',
        description: 'Tutorial',
        thumbnailUrl: 'https://example.com/thumb.jpg',
        ownerId: 'u1',
        channelId: 'c1',
        channelName: 'Code Channel',
        category: 'Education',
        tags: [],
        viewCount: 450,
      );

      final offline = video.toOffline();
      expect(offline.id, 'off_1');
      expect(offline.title, 'Offline Tutorial');
      expect(offline.channelName, 'Code Channel');
      expect(offline.views, '450');
      expect(offline.thumbnailUrl, 'https://example.com/thumb.jpg');
    });

    test('copyWith creates modified clone properly', () {
      final video = Video(
        id: 'cp_1',
        title: 'Original Title',
        description: 'Desc',
        thumbnailUrl: '',
        ownerId: 'u1',
        channelId: 'c1',
        channelName: 'Channel',
        category: 'Tech',
        tags: ['tag1'],
      );

      final updated = video.copyWith(title: 'New Title', viewCount: 999);
      expect(updated.id, 'cp_1');
      expect(updated.title, 'New Title');
      expect(updated.viewCount, 999);
      expect(updated.tags, ['tag1']);
    });
  });
}

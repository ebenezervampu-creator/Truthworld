import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/download_notification_service.dart';
import 'package:truthworld/core/utils/format_utils.dart';
import 'package:truthworld/data/models/offline.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/features/video/presentation/controllers/downloadcontroller.dart';
import 'package:truthworld/features/video/presentation/widgets/download_feedback_helper.dart';
import 'package:truthworld/features/video/presentation/widgets/video_player_settings_sheet.dart';

import '../../test_helpers/mock_firebase.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await setupMockFirebase();
  });

  tearDown(Get.reset);

  group('Download Notifications & Byte Formatting Unit Tests', () {
    test('FormatUtils.formatBytes formats sizes accurately', () {
      expect(FormatUtils.formatBytes(0), equals('0 MB'));
      expect(FormatUtils.formatBytes(512), equals('512 B'));
      expect(FormatUtils.formatBytes(15 * 1024 * 1024), equals('15 MB'));
      expect(FormatUtils.formatBytes(290 * 1024 * 1024), equals('290 MB'));
      expect(FormatUtils.formatBytes((1.81 * 1024 * 1024 * 1024).toInt()), equals('1.8 GB'));
    });

    test('ActiveDownloadTask tracks progress, bytes, and byteProgressText', () {
      final video = Video(
        id: 'test_vid_1',
        title: 'JESUS (Telugu) 🎬',
        description: 'Test description',
        thumbnailUrl: 'https://example.com/thumb.jpg',
        ownerId: 'owner1',
        channelId: 'ch1',
        channelName: 'Channel One',
        category: 'Documentary',
        tags: const ['faith'],
        videoUrl: 'https://example.com/video.mp4',
        channelAvatarUrl: '',
        views: 1000,
        createdAt: DateTime.now(),
      );

      final task = ActiveDownloadTask(
        video: video,
        isAudioOnly: false,
        quality: '1080p',
        initialProgress: 0.05,
        initialReceivedBytes: 15 * 1024 * 1024,
        initialTotalBytes: 290 * 1024 * 1024,
      );

      expect(task.quality, equals('1080p'));
      expect(task.progress.value, equals(0.05));
      expect(task.byteProgressText, equals('15 MB / 290 MB'));

      // Update bytes dynamically
      task.receivedBytes.value = 50 * 1024 * 1024;
      expect(task.byteProgressText, equals('50 MB / 290 MB'));
    });

    test('DownloadNotificationService registers and configures channel IDs', () {
      expect(DownloadNotificationService.channelId, equals('truthworld_video_downloads'));
      expect(DownloadNotificationService.channelName, equals('Video Downloads'));
      final service = DownloadNotificationService.to;
      expect(service, isNotNull);
    });
  });

  group('Download Feedback Helper & Bottom Sheet Widget Tests', () {
    testWidgets('showDownloadStartedSnackbar renders with exact text and action button', (tester) async {
      final video = Video(
        id: 'test_vid_2',
        title: 'JESUS (Telugu) 🎬',
        description: 'Test description',
        thumbnailUrl: 'https://example.com/thumb.jpg',
        ownerId: 'owner1',
        channelId: 'ch1',
        channelName: 'Channel One',
        category: 'Documentary',
        tags: const ['faith'],
        videoUrl: 'https://example.com/video.mp4',
        channelAvatarUrl: '',
        views: 1000,
        createdAt: DateTime.now(),
      );

      await tester.pumpWidget(
        GetMaterialApp(
          home: Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () {
                  DownloadFeedbackHelper.showDownloadStartedSnackbar(
                    video: video,
                    resolutionText: '1080p',
                  );
                },
                child: const Text('Start'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Start'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Downloading...'), findsOneWidget);
      expect(find.text('1080p'), findsOneWidget);
      expect(find.text('View'), findsOneWidget);

      Get.closeAllSnackbars();
      await tester.pumpAndSettle();
    });

    testWidgets('showDownloadedOptionsSheet renders with options to delete and other resolutions', (tester) async {
      final video = Video(
        id: 'test_vid_3',
        title: 'TruthWorld Documentary',
        description: 'Test description',
        thumbnailUrl: 'https://example.com/thumb.jpg',
        ownerId: 'owner1',
        channelId: 'ch1',
        channelName: 'Channel One',
        category: 'Documentary',
        tags: const ['news'],
        videoUrl: 'https://example.com/video.mp4',
        channelAvatarUrl: '',
        views: 5000,
        createdAt: DateTime.now(),
      );

      final dlCtrl = Get.put(DownloadsController());
      dlCtrl.videos.add(
        OfflineVideo(
          id: video.id,
          title: video.title,
          channelName: video.channelName,
          channelImage: '',
          views: '5K',
          thumbnailUrl: video.thumbnailUrl,
          downloadedAt: DateTime.now(),
          quality: '1080p',
        ),
      );

      await tester.pumpWidget(
        GetMaterialApp(
          home: Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () {
                  VideoPlayerSettingsSheet.showDownloadedOptionsSheet(
                    video: video,
                    downloadsCtrl: dlCtrl,
                  );
                },
                child: const Text('Show Options'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show Options'));
      await tester.pumpAndSettle();

      expect(find.text('TruthWorld Documentary'), findsOneWidget);
      expect(find.text('Downloaded'), findsOneWidget);
      expect(find.text('Delete from downloads'), findsOneWidget);
      expect(find.text('Download in other resolutions'), findsOneWidget);
      expect(find.text('View in downloads'), findsOneWidget);

      Get.back();
      await tester.pumpAndSettle();
    });
  });
}

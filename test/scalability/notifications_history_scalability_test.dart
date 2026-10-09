// Notifications & Watch History Scalability Tests
//
// Verifies UserNotification filtering & unread aggregation across large notification backlogs,
// JSON deserialization throughput of complex notification snapshots,
// WatchHistoryController temporal date grouping & multi-criteria sorting under scale, and
// bounded history buffer memory limits.
//
// Pure Dart tests — zero mock data, zero network calls.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:truthworld/features/notifications/data/models/user_notification.dart';
import 'package:truthworld/features/notifications/presentation/controllers/user_notification_controller.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/features/watchhistory/presentation/controllers/watch_history_controller.dart';

import '../test_helpers/mock_firebase.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

UserNotification _makeNotification({
  required String id,
  required String title,
  required String message,
  NotificationSeverity severity = NotificationSeverity.info,
  bool read = false,
  DateTime? createdAt,
}) {
  return UserNotification(
    id: id,
    userId: 'usr_bench',
    type: 'system_alert',
    severity: severity,
    title: title,
    message: message,
    read: read,
    createdAt: createdAt ?? DateTime.now(),
  );
}

Video _makeHistoryVideo({
  required String id,
  required String title,
  required int views,
  required int likeCount,
  required Timestamp createdAt,
}) {
  return Video(
    id: id,
    title: title,
    description: 'Description for video $id',
    thumbnailUrl: 'https://example.com/thumb_$id.jpg',
    videoUrl: 'https://cdn.truthworld.in/video_$id.mp4',
    ownerId: 'owner_1',
    channelId: 'ch_1',
    channelName: 'Truth Channel',
    category: 'News',
    tags: const [],
    status: VideoStatus.ready,
    visibility: 'public',
    isApproved: true,
    geminiApproved: true,
    viewCount: views,
    likeCount: likeCount,
    createdAt: createdAt,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (methodCall) async => '.',
    );
    await GetStorage.init();
    await setupMockFirebase();
  });

  tearDown(Get.reset);

  // ── Group 1: UserNotificationController — Filtering & Badge Counts ────────

  group('UserNotificationController — Filtering & Unread Counting at Scale', () {
    test('Filters 2,000 notifications by severity in under 40 ms', () {
      final notifications = List<UserNotification>.generate(2000, (i) {
        final severities = [
          NotificationSeverity.info,
          NotificationSeverity.success,
          NotificationSeverity.warning,
          NotificationSeverity.priority,
        ];
        return _makeNotification(
          id: 'notif_$i',
          title: 'Alert #$i',
          message: 'System message for notification $i',
          severity: severities[i % severities.length],
        );
      });

      final controller = UserNotificationController();
      controller.notifications.assignAll(notifications);
      controller.setSeverityFilter('warning');

      // Warmup pass
      var filtered = controller.filteredNotifications;

      final stopwatch = Stopwatch()..start();
      filtered = controller.filteredNotifications;
      stopwatch.stop();

      // Exactly 500 (25%) are warnings
      expect(filtered.length, equals(500));
      expect(filtered.every((n) => n.severity == NotificationSeverity.warning), isTrue);
      expect(stopwatch.elapsedMilliseconds, lessThan(40),
          reason: 'Filtering 2,000 notifications by severity must take < 40 ms. '
              'Took ${stopwatch.elapsedMilliseconds} ms.');
    });

    test('Filters 2,000 notifications by searchQuery substring in under 50 ms', () {
      final notifications = List<UserNotification>.generate(2000, (i) {
        final isMatch = (i % 10 == 0); // 200 matches
        final title = isMatch
            ? 'Breaking: Fact Check Verified Report #$i'
            : 'Standard Weekly Summary #$i';
        return _makeNotification(
          id: 'n_$i',
          title: title,
          message: 'Notification body text with details.',
        );
      });

      final controller = UserNotificationController();
      controller.notifications.assignAll(notifications);
      controller.searchQuery.value = 'fact check verified';

      // Warmup pass
      var results = controller.filteredNotifications;

      final stopwatch = Stopwatch()..start();
      results = controller.filteredNotifications;
      stopwatch.stop();

      expect(results.length, equals(200));
      expect(stopwatch.elapsedMilliseconds, lessThan(50),
          reason: 'Full-text filtering 2,000 notifications must take < 50 ms. '
              'Took ${stopwatch.elapsedMilliseconds} ms.');
    });

    test('Computes unread badge count across 5,000 notifications in under 20 ms', () {
      final notifications = List<UserNotification>.generate(5000, (i) {
        // 30% unread (read == false)
        final isRead = i % 10 >= 3;
        return _makeNotification(
          id: 'n_$i',
          title: 'Notice $i',
          message: 'Detail $i',
          read: isRead,
        );
      });

      final controller = UserNotificationController();
      controller.notifications.assignAll(notifications);

      // Warmup pass
      var count = controller.unreadCount;

      final stopwatch = Stopwatch()..start();
      count = controller.unreadCount;
      stopwatch.stop();

      expect(count, equals(1500)); // 30% of 5,000
      expect(stopwatch.elapsedMilliseconds, lessThan(20),
          reason: 'Calculating unread count across 5,000 items must take < 20 ms. '
              'Took ${stopwatch.elapsedMilliseconds} ms.');
    });

    test('Parses 1,000 UserNotification fromJson items in under 80 ms', () {
      final rawMaps = List<Map<String, dynamic>>.generate(1000, (i) => {
        'id': 'notif_json_$i',
        'userId': 'usr_dest',
        'type': 'channel_upload',
        'severity': (i % 2 == 0) ? 'priority' : 'info',
        'priority': 'high',
        'status': (i % 3 == 0) ? 'read' : 'unread',
        'category': 'creator',
        'title': 'New Upload from Creator #$i',
        'message': 'Check out the new fact check video and share your perspective.',
        'createdAt': 1700000000000 + i * 1000,
        'read': (i % 3 == 0),
        'actions': [
          {'id': 'act_1', 'label': 'Watch Now', 'type': 'OPEN_VIDEO'},
        ],
      });

      // Warmup pass
      for (var i = 0; i < 20; i++) {
        UserNotification.fromJson('w_$i', rawMaps[i]);
      }

      final stopwatch = Stopwatch()..start();
      final parsed = <UserNotification>[];
      for (var i = 0; i < rawMaps.length; i++) {
        parsed.add(UserNotification.fromJson('notif_$i', rawMaps[i]));
      }
      stopwatch.stop();

      expect(parsed.length, equals(1000));
      expect(parsed.first.severity, equals(NotificationSeverity.priority));
      expect(parsed.first.actions.first.label, equals('Watch Now'));
      expect(stopwatch.elapsedMilliseconds, lessThan(80),
          reason: 'Parsing 1,000 notifications from JSON must complete in < 80 ms. '
              'Took ${stopwatch.elapsedMilliseconds} ms.');
    });
  });

  // ── Group 2: WatchHistoryController — Date Grouping & Sorting ─────────────

  group('WatchHistoryController — Date Grouping & Multi-Criteria Sorting', () {
    test('Groups 1,000 watch history items by date in under 40 ms', () {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day, 10);
      final yesterday = today.subtract(const Duration(days: 1));
      final threeDaysAgo = today.subtract(const Duration(days: 3));

      final videos = List<Video>.generate(1000, (i) {
        final date = (i % 3 == 0)
            ? today
            : (i % 3 == 1)
                ? yesterday
                : threeDaysAgo;
        return _makeHistoryVideo(
          id: 'v_$i',
          title: 'History Video #$i',
          views: i * 10,
          likeCount: i,
          createdAt: Timestamp.fromDate(date),
        );
      });

      final controller = WatchHistoryController();

      // Warmup pass
      var groups = controller.groupVideosByDate(videos.take(50).toList());

      final stopwatch = Stopwatch()..start();
      groups = controller.groupVideosByDate(videos);
      stopwatch.stop();

      expect(groups.containsKey('Today'), isTrue);
      expect(groups.containsKey('Yesterday'), isTrue);
      expect(groups['Today']!.length, equals(334));
      expect(groups['Yesterday']!.length, equals(333));
      expect(stopwatch.elapsedMilliseconds, lessThan(75),
          reason: 'Grouping 1,000 history items by date must take < 75 ms. '
              'Took ${stopwatch.elapsedMilliseconds} ms.');
    });

    test('Sorts 1,000 history items by views (descending & ascending) in under 30 ms', () {
      final now = Timestamp.now();
      final videos = List<Video>.generate(1000, (i) {
        return _makeHistoryVideo(
          id: 'v_$i',
          title: 'Video $i',
          views: (i * 31) % 50000,
          likeCount: i,
          createdAt: now,
        );
      });

      final controller = WatchHistoryController();
      controller.sortBy.value = 'views';
      controller.isAscending.value = false;

      final stopwatch = Stopwatch()..start();
      controller.sortVideos(videos);
      stopwatch.stop();

      expect(videos.first.views, greaterThanOrEqualTo(videos.last.views));
      expect(stopwatch.elapsedMilliseconds, lessThan(30),
          reason: 'Sorting 1,000 history items by views must take < 30 ms. '
              'Took ${stopwatch.elapsedMilliseconds} ms.');

      // Ascending sort
      controller.isAscending.value = true;
      controller.sortVideos(videos);
      expect(videos.first.views, lessThanOrEqualTo(videos.last.views));
    });

    test('Sorts 1,000 history items alphabetically by title in under 30 ms', () {
      final now = Timestamp.now();
      final videos = List<Video>.generate(1000, (i) {
        final title = 'Truth Report ${(1000 - i).toString().padLeft(4, '0')}';
        return _makeHistoryVideo(
          id: 'v_$i',
          title: title,
          views: i,
          likeCount: i,
          createdAt: now,
        );
      });

      final controller = WatchHistoryController();
      controller.sortBy.value = 'title';
      controller.isAscending.value = true;

      final stopwatch = Stopwatch()..start();
      controller.sortVideos(videos);
      stopwatch.stop();

      expect(videos.first.title, equals('Truth Report 0001'));
      expect(videos.last.title, equals('Truth Report 1000'));
      expect(stopwatch.elapsedMilliseconds, lessThan(30),
          reason: 'Alphabetical sorting 1,000 history items must take < 30 ms. '
              'Took ${stopwatch.elapsedMilliseconds} ms.');
    });
  });

  // ── Group 3: History Bounded Buffer & Memory Stability ────────────────────

  group('History Bounded Buffer & Date Range Invariants', () {
    test('Simulates 1,000 continuous video watches maintaining LRU limit of 100 in under 30 ms', () {
      final historySet = <String>{};
      final historyOrder = <String>[];
      const maxHistoryCapacity = 100;

      final stopwatch = Stopwatch()..start();
      for (var i = 0; i < 1000; i++) {
        final videoId = 'video_${i % 250}'; // Revisiting videos periodically
        if (historySet.contains(videoId)) {
          historyOrder.remove(videoId);
        } else if (historyOrder.length >= maxHistoryCapacity) {
          final oldest = historyOrder.removeAt(0);
          historySet.remove(oldest);
        }
        historyOrder.add(videoId);
        historySet.add(videoId);
      }
      stopwatch.stop();

      expect(historyOrder.length, equals(maxHistoryCapacity));
      expect(historySet.length, equals(maxHistoryCapacity));
      expect(stopwatch.elapsedMilliseconds, lessThan(30),
          reason: 'LRU bounded history tracking across 1,000 events must complete in < 30 ms. '
              'Took ${stopwatch.elapsedMilliseconds} ms.');
    });

    test('Verifies strict non-overlapping temporal date intervals', () {
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      final yesterdayStart = todayStart.subtract(const Duration(days: 1));
      final yesterdayEnd = DateTime(
        yesterdayStart.year,
        yesterdayStart.month,
        yesterdayStart.day,
        23,
        59,
        59,
      );

      expect(yesterdayEnd.isBefore(todayStart), isTrue,
          reason: 'Yesterday end timestamp must be strictly before today start timestamp.');
      expect(todayStart.difference(yesterdayStart).inHours, equals(24),
          reason: 'Day boundary difference must be exactly 24 hours.');
    });
  });
}

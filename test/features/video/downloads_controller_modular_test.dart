import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/data/models/offline.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/features/video/presentation/controllers/downloadcontroller.dart';
import '../../test_helpers/mock_firebase.dart';

class TestDownloadsController extends DownloadsController {
  @override
  Future<void> loadVideos() async {
    // No-op for unit tests
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await setupMockFirebase();
  });

  tearDown(Get.reset);

  group('DownloadFilterHelper Unit Tests', () {
    final testVideos = [
      OfflineVideo(
        id: 'v1',
        title: 'Breaking Tech Investigation',
        channelName: 'Truth Tech Desk',
        channelImage: '',
        views: '10K',
        thumbnailUrl: '',
        downloadedAt: DateTime.now(),
        quality: '1080p',
      ),
      OfflineVideo(
        id: 'a1',
        title: 'Daily Fact Check Podcast',
        channelName: 'Truth Tech Desk',
        channelImage: '',
        views: '5K',
        thumbnailUrl: '',
        downloadedAt: DateTime.now().subtract(const Duration(days: 1)),
        isAudioOnly: true,
        quality: 'Audio only',
      ),
      OfflineVideo(
        id: 'v2',
        title: 'Science and Climate Claims Debunked',
        channelName: 'Global Science News',
        channelImage: '',
        views: '25K',
        thumbnailUrl: '',
        downloadedAt: DateTime.now().subtract(const Duration(days: 4)),
        quality: '720p',
      ),
    ];

    test('1. filterVideos correctly filters by category and search query', () {
      // All
      final allItems = DownloadFilterHelper.filterVideos(
        videos: testVideos,
        category: 'All',
        searchQuery: '',
      );
      expect(allItems.length, equals(3));

      // Videos only
      final videosOnly = DownloadFilterHelper.filterVideos(
        videos: testVideos,
        category: 'Videos',
        searchQuery: '',
      );
      expect(videosOnly.length, equals(2));
      expect(videosOnly.every((v) => !v.isAudioOnly), isTrue);

      // Audio only
      final audioOnly = DownloadFilterHelper.filterVideos(
        videos: testVideos,
        category: 'Audio',
        searchQuery: '',
      );
      expect(audioOnly.length, equals(1));
      expect(audioOnly.first.id, equals('a1'));

      // Search by title
      final searchTitle = DownloadFilterHelper.filterVideos(
        videos: testVideos,
        category: 'All',
        searchQuery: 'debunked',
      );
      expect(searchTitle.length, equals(1));
      expect(searchTitle.first.id, equals('v2'));

      // Search by channel name
      final searchChannel = DownloadFilterHelper.filterVideos(
        videos: testVideos,
        category: 'All',
        searchQuery: 'Tech Desk',
      );
      expect(searchChannel.length, equals(2));
      expect(searchChannel.map((v) => v.id), containsAll(['v1', 'a1']));
    });

    test('2. formatTimeAgo produces standard English intervals', () {
      final now = DateTime.now();

      expect(
        DownloadFilterHelper.formatTimeAgo(now.subtract(const Duration(seconds: 10))),
        equals('Just now'),
      );

      expect(
        DownloadFilterHelper.formatTimeAgo(now.subtract(const Duration(minutes: 5))),
        equals('5 minutes ago'),
      );

      expect(
        DownloadFilterHelper.formatTimeAgo(now.subtract(const Duration(hours: 3))),
        equals('3 hours ago'),
      );

      expect(
        DownloadFilterHelper.formatTimeAgo(now.subtract(const Duration(days: 2))),
        equals('2 days ago'),
      );

      expect(
        DownloadFilterHelper.formatTimeAgo(now.subtract(const Duration(days: 45))),
        equals('1 month ago'),
      );

      expect(
        DownloadFilterHelper.formatTimeAgo(now.subtract(const Duration(days: 400))),
        equals('1 year ago'),
      );
    });

    test('3. groupVideosByDate groups items into Today, Yesterday, and date keys', () {
      final groups = DownloadFilterHelper.groupVideosByDate(testVideos);

      expect(groups.containsKey('Today'), isTrue);
      expect(groups['Today']!.first.id, equals('v1'));

      expect(groups.containsKey('Yesterday'), isTrue);
      expect(groups['Yesterday']!.first.id, equals('a1'));

      expect(groups.length, equals(3));
    });
  });

  group('DownloadResolutionManager Unit Tests', () {
    test('4. inferHeightFromLabel parses resolution numbers accurately', () {
      expect(DownloadResolutionManager.inferHeightFromLabel('1080p'), equals(1080));
      expect(DownloadResolutionManager.inferHeightFromLabel('720p HD'), equals(720));
      expect(DownloadResolutionManager.inferHeightFromLabel('480p'), equals(480));
      expect(DownloadResolutionManager.inferHeightFromLabel('360p'), equals(360));
      expect(DownloadResolutionManager.inferHeightFromLabel('240p'), equals(240));
      expect(DownloadResolutionManager.inferHeightFromLabel('144p'), equals(144));
      expect(DownloadResolutionManager.inferHeightFromLabel('Standard'), equals(720));
    });

    test('5. getResolutionBadge returns appropriate quality tiers', () {
      expect(DownloadResolutionManager.getResolutionBadge('1080p', 1080), equals('Full HD'));
      expect(DownloadResolutionManager.getResolutionBadge('720p', 720), equals('HD'));
      expect(DownloadResolutionManager.getResolutionBadge('480p', 480), equals('SD'));
      expect(DownloadResolutionManager.getResolutionBadge('360p', 360), equals('Medium'));
      expect(DownloadResolutionManager.getResolutionBadge('240p', 240), equals('Low'));
      expect(DownloadResolutionManager.getResolutionBadge('144p', 144), equals('Data Saver'));
    });

    test('6. getAvailableResolutionsForVideo guarantees complete ladder down to 144p when video has only 1080p and 720p', () async {
      final video = Video(
        id: 'vid_download_ladder_test',
        ownerId: 'owner_1',
        title: 'Download Ladder Test Video',
        description: 'Test Description',
        category: 'Education',
        tags: const ['test'],
        videoUrl: 'https://example.com/source.mp4',
        thumbnailUrl: '',
        channelId: 'ch_1',
        channelName: 'Channel 1',
        channelAvatarUrl: '',
        createdAt: DateTime.now(),
        adaptiveResolutions: [
          VideoResolutionV2(
            label: '1080p',
            url: 'https://example.com/1080p.mp4',
            width: 1920,
            height: 1080,
            bitrate: 4500000,
          ),
          VideoResolutionV2(
            label: '720p',
            url: 'https://example.com/720p.mp4',
            width: 1280,
            height: 720,
            bitrate: 2500000,
          ),
        ],
      );

      final resolutions = await DownloadResolutionManager.getAvailableResolutionsForVideo(video);
      expect(resolutions.length, 6);
      expect(
        resolutions.map((r) => r.label).toList(),
        ['1080p', '720p', '480p', '360p', '240p', '144p'],
      );
    });
  });

  group('DownloadsController State & Sorting Tests', () {
    late TestDownloadsController controller;

    setUp(() {
      controller = TestDownloadsController();
      controller.videos.value = [
        OfflineVideo(
          id: 'v1',
          title: 'Zebra Fact Check',
          channelName: 'Channel A',
          channelImage: '',
          views: '10',
          thumbnailUrl: '',
          downloadedAt: DateTime(2026),
        ),
        OfflineVideo(
          id: 'v2',
          title: 'Alpha Truth Analysis',
          channelName: 'Channel B',
          channelImage: '',
          views: '20',
          thumbnailUrl: '',
          downloadedAt: DateTime(2026, 1, 2),
        ),
      ];
    });

    test('6. setSortBy toggles title and recent sorting directions', () {
      // Sort by title
      controller.setSortBy('title');
      expect(controller.sortBy.value, equals('title'));
      expect(controller.isAscending.value, isFalse);
      expect(controller.videos.first.title, equals('Zebra Fact Check'));

      // Toggle title ascending
      controller.setSortBy('title');
      expect(controller.isAscending.value, isTrue);
      expect(controller.videos.first.title, equals('Alpha Truth Analysis'));

      // Sort by recent descending
      controller.setSortBy('recent');
      expect(controller.sortBy.value, equals('recent'));
      expect(controller.isAscending.value, isFalse);
      expect(controller.videos.first.id, equals('v2'));
    });

    test('7. Search, category, and view toggle interact predictably', () {
      expect(controller.isSearching.value, isFalse);
      controller.toggleSearching();
      expect(controller.isSearching.value, isTrue);

      controller.setSearchQuery('Zebra');
      expect(controller.searchQuery.value, equals('Zebra'));
      expect(controller.filteredVideos.length, equals(1));
      expect(controller.filteredVideos.first.id, equals('v1'));

      controller.toggleSearching();
      expect(controller.isSearching.value, isFalse);
      expect(controller.searchQuery.value, isEmpty);

      expect(controller.isListView.value, isTrue);
      controller.toggleView();
      expect(controller.isListView.value, isFalse);
    });
  });

  group('Active Downloads & Offline Guard Tests', () {
    late TestDownloadsController controller;

    setUp(() {
      controller = TestDownloadsController();
    });

    test('8. isVideoDownloaded correctly reflects saved offline videos', () {
      expect(controller.isVideoDownloaded('v1'), isFalse);

      controller.videos.add(
        OfflineVideo(
          id: 'v1',
          title: 'Christian songs Redx Media',
          channelName: 'Ebenezer Vampu',
          channelImage: '',
          views: '0',
          thumbnailUrl: '',
          downloadedAt: DateTime.now(),
        ),
      );

      expect(controller.isVideoDownloaded('v1'), isTrue);
      expect(controller.isVideoDownloaded('v2'), isFalse);
    });

    test('9. ActiveDownloadTask tracks progress and status dynamically', () {
      final dummyVideo = Video(
        id: 'v_active',
        ownerId: 'user1',
        title: 'How ISRO Does More in Space for Less',
        description: 'Test Description',
        videoUrl: 'https://example.com/video.mp4',
        thumbnailUrl: 'https://example.com/thumb.jpg',
        channelId: 'ch1',
        channelName: 'Ebenezer Vampu',
        channelAvatarUrl: '',
        duration: '05:34',
        category: 'Science',
        tags: const ['space', 'isro'],
        createdAt: DateTime.now(),
      );

      final task = ActiveDownloadTask(
        video: dummyVideo,
        isAudioOnly: false,
        quality: '720p HD',
      );

      controller.activeDownloads['v_active'] = task;
      controller.downloadProgressMap['v_active'] = 0.0;

      expect(controller.isVideoDownloading('v_active'), isTrue);
      expect(controller.activeDownloads.length, equals(1));
      expect(controller.activeDownloads['v_active']!.quality, equals('720p HD'));

      // Progress update
      task.progress.value = 0.45;
      task.status.value = 'Downloading 45%';

      expect(controller.activeDownloads['v_active']!.progress.value, equals(0.45));
      expect(controller.activeDownloads['v_active']!.status.value, equals('Downloading 45%'));

      // Cancel task
      controller.cancelDownload('v_active');
      expect(controller.isVideoDownloading('v_active'), isFalse);
      expect(controller.activeDownloads.isEmpty, isTrue);
      expect(controller.downloadProgressMap.containsKey('v_active'), isFalse);
    });

    test('10. OfflineVideo.fromJson safely parses null and non-string numbers without throwing', () {
      final safeItem = OfflineVideo.fromJson({
        'id': 'v_robust',
        'title': null,
        'channelName': null,
        'channelImage': null,
        'views': 12345, // int instead of String
        'thumbnailUrl': null,
        'downloadedAt': null,
        'isAudioOnly': null,
        'quality': null,
        'isEncrypted': null,
      });

      expect(safeItem.id, equals('v_robust'));
      expect(safeItem.title, equals(''));
      expect(safeItem.channelName, equals(''));
      expect(safeItem.views, equals('12345'));
      expect(safeItem.thumbnailUrl, equals(''));
      expect(safeItem.isAudioOnly, isFalse);
      expect(safeItem.isEncrypted, isTrue);
      expect(safeItem.downloadedAt, isNotNull);
    });
  });

  group('Download Quality Premium Gating Tests', () {
    test('11. isPremiumResolution correctly gates resolutions > 720p', () {
      final res2160 = VideoResolutionV2(
        label: '2160p',
        url: 'https://example.com/2160.mp4',
        width: 3840,
        height: 2160,
        bitrate: 15000000,
      );
      final res1440 = VideoResolutionV2(
        label: '1440p',
        url: 'https://example.com/1440.mp4',
        width: 2560,
        height: 1440,
        bitrate: 10000000,
      );
      final res1080 = VideoResolutionV2(
        label: '1080p',
        url: 'https://example.com/1080.mp4',
        width: 1920,
        height: 1080,
        bitrate: 4500000,
      );
      final res720 = VideoResolutionV2(
        label: '720p',
        url: 'https://example.com/720.mp4',
        width: 1280,
        height: 720,
        bitrate: 2500000,
      );
      final res480 = VideoResolutionV2(
        label: '480p',
        url: 'https://example.com/480.mp4',
        width: 854,
        height: 480,
        bitrate: 1200000,
      );

      // > 720p requires premium
      expect(DownloadQualityDialog.isPremiumResolution(res2160), isTrue);
      expect(DownloadQualityDialog.isPremiumResolution(res1440), isTrue);
      expect(DownloadQualityDialog.isPremiumResolution(res1080), isTrue);

      // <= 720p does not require premium
      expect(DownloadQualityDialog.isPremiumResolution(res720), isFalse);
      expect(DownloadQualityDialog.isPremiumResolution(res480), isFalse);
    });

    test('12. downloadVideoOffline rejects resolutions > 720p for non-premium users', () async {
      final controller = TestDownloadsController();
      final video = Video(
        id: 'test_vid_premium',
        ownerId: 'owner_free',
        title: 'High Definition Test Video',
        description: 'Test Description',
        category: 'Education',
        tags: const ['test'],
        channelId: 'channel_free',
        channelName: 'Free Channel',
        videoUrl: 'https://example.com/base.mp4',
        originalUrl: 'https://example.com/base.mp4',
        thumbnailUrl: '',
      );

      final res1080 = VideoResolutionV2(
        label: '1080p',
        url: 'https://example.com/1080.mp4',
        width: 1920,
        height: 1080,
        bitrate: 4500000,
      );

      final result = await controller.downloadVideoOffline(
        video: video,
        resolution: res1080,
      );

      expect(result, isFalse);
      expect(controller.isVideoDownloading('test_vid_premium'), isFalse);
    });
  });
}


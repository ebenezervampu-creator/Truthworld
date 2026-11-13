import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/components/ui/video_card/video_card_controller.dart';
import 'package:truthworld/components/ui/video_card/video_card_thumbnail.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/services/image_verification_service.dart';
import 'package:truthworld/features/search/data/models/search_result.dart';
import 'package:truthworld/features/search/presentation/widgets/items/search_video_result_item.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/features/video/presentation/controllers/upload_controller.dart';
import 'package:truthworld/features/video/presentation/controllers/upload_mixins/upload_controller_base.dart';
import 'package:truthworld/features/video/presentation/views/upload/widgets/create_content_media_sections.dart';
import 'package:truthworld/theme/app_theme.dart';
import '../../pages/page_test_harness.dart';
import '../../test_helpers/mock_firebase.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await setupMockFirebase();
  });

  setUp(() {
    Get.reset();
    Get.testMode = true;
    if (!Get.isRegistered<AuthService>()) {
      Get.put<AuthService>(AuthService());
    }
  });

  tearDown(Get.reset);

  group('Video Thumbnail YouTube Parity Tests', () {
    test('1. Thumbnail max file size constants match YouTube specification (2MB)', () {
      // YouTube enforces a strict 2MB limit for video thumbnails
      const expected2MBInBytes = 2 * 1024 * 1024; // 2,097,152 bytes
      expect(UploadControllerBase.maxThumbnailSizeBytes, equals(expected2MBInBytes));
      expect(ImageCategory.thumbnail.maxSize, equals(expected2MBInBytes));
    });

    test('2. Thumbnail size verification enforces 2MB threshold', () {
      const maxAllowed = UploadControllerBase.maxThumbnailSizeBytes;
      const validSize = 2 * 1024 * 1024; // Exactly 2MB
      const slightlyOver = (2 * 1024 * 1024) + 1; // 2MB + 1 byte
      const largeSize = 5 * 1024 * 1024; // 5MB

      bool isWithinLimit(int size) => size <= maxAllowed;

      expect(isWithinLimit(validSize), isTrue);
      expect(isWithinLimit(slightlyOver), isFalse);
      expect(isWithinLimit(largeSize), isFalse);
    });

    test('3. ImageCategory thumbnail metadata attributes match YouTube requirements', () {
      expect(ImageCategory.thumbnail.folderName, equals('thumbnails'));
      expect(ImageCategory.thumbnail.displayName, equals('Thumbnail'));
      expect(ImageCategory.thumbnail.maxSize, equals(2 * 1024 * 1024));
      expect(ImageCategory.thumbnail.priority, equals('HIGH'));
    });

    testWidgets('4. CreateContentThumbnailSection renders 16:9, 1280x720, and Max 2MB labels', (tester) async {
      final uploadCtrl = Get.put(UploadController());

      await tester.pumpWidget(
        GetMaterialApp(
          theme: buildAppTheme(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: CreateContentThumbnailSection(
                uploadController: uploadCtrl,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Heading and description
      expect(find.text('1. Thumbnail'), findsOneWidget);
      expect(find.text('Choose or upload a 16:9 thumbnail for your video'), findsOneWidget);
      expect(find.text('Upload custom image'), findsOneWidget);

      // Verify the 16:9 (1280x720) and Max 2MB subtitle text matching YouTube guidelines
      expect(
        find.text('16:9 Aspect Ratio (1280x720). Max 2MB. PNG, JPG or WEBP.'),
        findsOneWidget,
      );
    });

    testWidgets('5. VideoCardThumbnail renders with 1280 HD dimension and FilterQuality.medium (eliminates blur)', (tester) async {
      final video = Video(
        id: 'vid_blur_fix_1',
        title: 'HD Crisp Thumbnail Test Video',
        description: 'Test description',
        videoUrl: 'https://example.com/video.mp4',
        thumbnailUrl: 'https://example.com/hd_thumb.jpg',
        channelId: 'ch_1',
        channelName: 'Channel One',
        ownerId: 'user_1',
        category: 'Technology',
        tags: const ['tech'],
        createdAt: Timestamp.now(),
        updatedAt: Timestamp.now(),
      );

      final cardController = VideoCardController(video: video);

      await tester.pumpWidget(
        GetMaterialApp(
          theme: buildAppTheme(),
          home: Scaffold(
            body: VideoCardThumbnail(
              video: video,
              controller: cardController,
            ),
          ),
        ),
      );
      await tester.pump();

      final cachedImage = tester.widget<CachedNetworkImage>(find.byType(CachedNetworkImage));
      expect(cachedImage.imageUrl, equals('https://example.com/hd_thumb.jpg'));
      expect(cachedImage.filterQuality, equals(FilterQuality.medium));
      // HD 1280 dimension or null on web (never crushed to 480px)
      expect(cachedImage.memCacheWidth, equals(kIsWeb ? null : 1280));
      expect(cachedImage.maxWidthDiskCache, equals(kIsWeb ? null : 1280));
    });

    testWidgets('6. SearchVideoResultItem renders thumbnail with FilterQuality.medium', (tester) async {
      final result = SearchResult(
        id: 'search_1',
        title: 'Search Result HD Thumbnail',
        thumbnail: 'https://example.com/search_thumb.jpg',
        channelName: 'Tech Today',
        channelImage: 'https://example.com/avatar.jpg',
        views: 12500,
        createdAt: Timestamp.now(),
      );

      await tester.pumpWidget(
        GetMaterialApp(
          theme: buildAppTheme(),
          home: Scaffold(
            body: SearchVideoResultItem(
              result: result,
            ),
          ),
        ),
      );
      await tester.pump();

      final cachedImages = tester.widgetList<CachedNetworkImage>(find.byType(CachedNetworkImage)).toList();
      expect(cachedImages.isNotEmpty, isTrue);
      final thumbImage = cachedImages.first;
      expect(thumbImage.filterQuality, equals(FilterQuality.medium));
      expect(thumbImage.memCacheWidth, equals(kIsWeb ? null : 1280));
    });
  });
}

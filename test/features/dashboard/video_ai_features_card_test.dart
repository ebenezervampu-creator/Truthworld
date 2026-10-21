import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/video_management.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/widgets/video_ai_features_card.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/features/video/data/models/video_media.dart';
import 'package:truthworld/features/video/data/services/video_media_service.dart';
import 'package:truthworld/theme/app_theme.dart';
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
      Get.put<AuthService>(AuthService(), permanent: true);
    }
  });

  tearDown(() {
    VideoMediaService().clearAllCaches();
    Get.reset();
  });

  Widget createHarness(Widget child) {
    return GetMaterialApp(
      theme: buildAppTheme(),
      home: Scaffold(
        body: SingleChildScrollView(child: child),
      ),
    );
  }

  group('VideoAIFeaturesOverviewCard Fact-Check Tests', () {
    testWidgets(
      'renders Not Fact-Checked and Run Fact-Check for video with trustScore 100 but no fact-checking',
      (tester) async {
        final controller = Get.put(VideoManagementController());

        final nonFactCheckedVideo = Video.fromMap({
          'id': 'video_unverified_1',
          'title': 'Are Eggs Vegetarian or Non-Vegetarian?',
          'channelId': 'chan_1',
          'channelName': 'Test Channel',
          'videoUrl': 'https://example.com/video.mp4',
          'status': 'ready',
          'description': 'Description about eggs',
          'isFactChecked': false,
          'factCheckUrl': '',
          'trustScore': 100, // Moderation approval score, not fact-check
          'aiFeatures': {
            'factChecking': false,
            'factCheckTier': 'full_ground',
          },
        });

        // Ensure cache is empty for this video
        VideoMediaService.credibilityCache[nonFactCheckedVideo.id] =
            const VideoMediaCredibility();

        await tester.pumpWidget(
          createHarness(
            VideoAIFeaturesOverviewCard(
              video: nonFactCheckedVideo,
              isDarkMode: true,
              controller: controller,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Must display un-fact-checked state
        expect(find.text('Not Fact-Checked'), findsOneWidget);
        expect(find.text('NOT CHECKED'), findsOneWidget);
        expect(find.text('Run Fact-Check'), findsOneWidget);

        // Must NOT falsely claim High Trust or provide View Full Report
        expect(find.text('View Full Report'), findsNothing);
        expect(find.text('HIGH TRUST'), findsNothing);
        expect(find.textContaining('0 Claims Evaluated'), findsNothing);
      },
    );

    testWidgets(
      'renders High Trust and View Full Report when video is legitimately fact-checked',
      (tester) async {
        final controller = Get.put(VideoManagementController());

        final factCheckedVideo = Video.fromMap({
          'id': 'video_verified_2',
          'title': 'Grounded Scientific Study',
          'channelId': 'chan_2',
          'channelName': 'Truth Science',
          'videoUrl': 'https://example.com/study.mp4',
          'status': 'ready',
          'description': 'Peer-reviewed claim analysis',
          'isFactChecked': true,
          'factCheckUrl': 'https://storage.googleapis.com/test-bucket/factchecks/report.json',
          'trustScore': 92.0,
        });

        // Populate credibility cache with claims
        VideoMediaService.credibilityCache[factCheckedVideo.id] =
            const VideoMediaCredibility(
          trustScore: 92.0,
          claims: [
            {'text': 'Claim verified by source', 'verdict': 'verified'},
          ],
          factCheckUrl:
              'https://storage.googleapis.com/test-bucket/factchecks/report.json',
        );

        await tester.pumpWidget(
          createHarness(
            VideoAIFeaturesOverviewCard(
              video: factCheckedVideo,
              isDarkMode: true,
              controller: controller,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Must display verified credibility state
        expect(find.text('View Full Report'), findsOneWidget);
        expect(find.text('HIGH TRUST'), findsOneWidget);
        expect(find.textContaining('92% Trust Score'), findsOneWidget);
        expect(find.textContaining('1 Claims Evaluated'), findsOneWidget);
        expect(find.text('Run Fact-Check'), findsNothing);
      },
    );
  });
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/services/connectivity_service.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/features/video/presentation/views/widgets/video_recommendation_card.dart';
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
    if (!Get.isRegistered<ConnectivityService>()) {
      Get.put<ConnectivityService>(ConnectivityService(), permanent: true);
    }
  });

  tearDown(Get.reset);

  final sampleVideo = Video.fromMap({
    'title': 'Patanjali Red Chilli Powder Exposed',
    'channelId': 'chan_test_1',
    'channelName': 'Trustified',
    'videoUrl': 'https://example.com/video.mp4',
    'thumbnailUrl': 'https://example.com/thumb.jpg',
    'duration': '7:37',
    'views': 211000,
    'uploadedAt': Timestamp.fromDate(DateTime.now().subtract(const Duration(days: 3))),
  }, 'vid_rec_101');

  group('RecommendationVideoCard Widget Tests', () {
    testWidgets('renders 16:9 thumbnail, duration badge, title, subtitle, and more_horiz menu',
        (tester) async {
      var tapped = false;

      await tester.pumpWidget(
        GetMaterialApp(
          home: Scaffold(
            body: RecommendationVideoCard(
              video: sampleVideo,
              heroPrefix: 'test_rec',
              onTap: () {
                tapped = true;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check title
      expect(find.text('Patanjali Red Chilli Powder Exposed'), findsOneWidget);

      // Check duration badge
      expect(find.text('7:37'), findsOneWidget);

      // Check subtitle format: contains channel, \u25B7211K, 3d ago
      expect(find.textContaining('Trustified'), findsWidgets);
      expect(find.textContaining('\u25B7211K'), findsOneWidget);
      expect(find.textContaining('3d ago'), findsOneWidget);

      // Check horizontal three-dots menu icon (more_horiz)
      expect(find.byIcon(Icons.more_horiz), findsOneWidget);

      // Check tap interaction
      await tester.tap(find.text('Patanjali Red Chilli Powder Exposed'));
      expect(tapped, isTrue);
    });

    testWidgets('renders verified badge icon before duration when video is fact-checked',
        (tester) async {
      final factCheckedVideo = Video.fromMap({
        'title': 'Fact Checked Video',
        'channelId': 'chan_test_2',
        'channelName': 'Trustified',
        'videoUrl': 'https://example.com/video2.mp4',
        'thumbnailUrl': 'https://example.com/thumb2.jpg',
        'duration': '14:20',
        'views': 50000,
        'isFactChecked': true,
        'uploadedAt': Timestamp.now(),
      }, 'vid_rec_102');

      await tester.pumpWidget(
        GetMaterialApp(
          home: Scaffold(
            body: RecommendationVideoCard(
              video: factCheckedVideo,
              heroPrefix: 'test_rec_fc',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('14:20'), findsOneWidget);
      expect(find.byIcon(Icons.verified_rounded), findsOneWidget);
    });
  });
}


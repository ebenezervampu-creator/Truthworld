import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/services/connectivity_service.dart';
import 'package:truthworld/features/analytics/data/services/video_presence_service.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/truth_verification/truth_verification_full_inspector_page.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/truth_verification/truth_verification_models.dart';
import 'package:truthworld/features/video/data/models/fact_check_data_parser.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/features/video/presentation/controllers/video_controller.dart';
import 'package:truthworld/features/video/presentation/widgets/analysis/video_analysis_empty_fallback.dart';
import '../../test_helpers/mock_firebase.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await setupMockFirebase();
    if (!Get.isRegistered<AuthService>()) {
      Get.put<AuthService>(AuthService(), permanent: true);
    }
    if (!Get.isRegistered<ConnectivityService>()) {
      Get.put<ConnectivityService>(ConnectivityService(), permanent: true);
    }
  });

  group('Fact-Checked Video with Zero Empirical Claims', () {
    test('FactCheckDataParser.parse returns non-empty parsed result when isVideoFactChecked is true', () {
      final parsed = FactCheckDataParser.parse(
        null,
        isVideoFactChecked: true,
      );

      expect(parsed.isEmpty, isFalse);
      expect(parsed.isVideoFactChecked, isTrue);
      expect(parsed.analysisState, 'VERIFIED');
    });

    test('Video.hasTruthIntelligence and hasAiCredibility return true for isFactChecked video even with 0 trustScore', () {
      final video = Video(
        id: 'zero_claims_vid',
        title: 'Dark side of Gandhi',
        description: 'Historical commentary and perspectives.',
        thumbnailUrl: '',
        ownerId: 'u1',
        channelId: 'ch1',
        channelName: 'History Channel',
        category: 'History',
        tags: const [],
        isFactChecked: true,
      );

      expect(video.isFactChecked, isTrue);
      expect(video.hasTruthIntelligence, isTrue);
      expect(video.hasAiCredibility, isTrue);
    });

    testWidgets('VideoAnalysisEmptyFallback displays No Empirical Claims Evaluated and hides upgrade button when video is fact-checked', (tester) async {
      final factCheckedVideo = Video(
        id: 'v_fc',
        title: 'Dark side of Gandhi',
        description: 'Philosophical discussion',
        thumbnailUrl: '',
        ownerId: 'u1',
        channelId: 'ch1',
        channelName: 'History Channel',
        category: 'History',
        tags: const [],
        isFactChecked: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VideoAnalysisEmptyFallback(video: factCheckedVideo),
          ),
        ),
      );

      expect(find.text('No Empirical Claims Evaluated'), findsOneWidget);
      expect(find.text('Not Fact-Checked Yet'), findsNothing);
      expect(find.text('Fact-Check This Video'), findsNothing);
      expect(
        find.textContaining('Truth verification was completed for this video'),
        findsOneWidget,
      );
    });

    testWidgets('TruthVerificationFullInspectorPage displays verification tabs and never displays Not Fact-Checked Yet', (tester) async {
      final item = VideoFactCheckItem(
        id: 'v_zero_claims',
        title: 'Dark side of Gandhi',
        thumbnailUrl: '',
        factCheckReviewMode: 'open_to_users',
        isFactCheckApproved: true,
        claims: [],
        summary: 'Fact-checking analysis is complete for "Dark side of Gandhi". Verification results are now visible to viewers.',
        domain: 'History',
        createdAt: DateTime.now(),
      );

      await tester.pumpWidget(
        GetMaterialApp(
          home: Scaffold(
            body: TruthVerificationFullInspectorPage(
              videoItem: item,
              channelId: 'ch1',
              isDarkMode: true,
              onToggleApproval: (_, _) {},
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Header should show title and approved status
      expect(find.text('Fact-Check & Verification Report'), findsOneWidget);
      expect(find.text('Dark side of Gandhi'), findsWidgets);
      expect(find.text('Approved (Visible to Viewers)'), findsWidgets);
      expect(find.textContaining('0 assertions'), findsOneWidget);

      // Body must NOT show "Not Fact-Checked Yet" or "Fact-Check This Video"
      expect(find.text('Not Fact-Checked Yet'), findsNothing);
      expect(find.text('Fact-Check This Video'), findsNothing);

      // Body should render the claims tab with the empty claims message
      expect(find.text('No Fact-Checked Claims'), findsOneWidget);
      expect(
        find.textContaining('No verifiable empirical claims were found in this video'),
        findsOneWidget,
      );

      // Clean up controllers
      if (Get.isRegistered<VideoController>(tag: 'v_zero_claims')) {
        Get.delete<VideoController>(tag: 'v_zero_claims', force: true);
      }
      await VideoPresenceService.to.stopWatching(immediate: true);
    });
  });
}

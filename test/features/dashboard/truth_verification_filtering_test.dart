import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/services/connectivity_service.dart';
import 'package:truthworld/features/analytics/data/services/video_presence_service.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/truth_verification_dashboard_page.dart';
import 'package:truthworld/features/video/presentation/views/video_analysis_screen.dart';
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
  group('TruthVerificationDashboardPage.hasFactChecking', () {
    test('returns true when isFactChecked is explicitly true', () {
      final data = <String, dynamic>{
        'title': 'Investigative Fact Check',
        'isFactChecked': true,
      };
      expect(TruthVerificationDashboardPage.hasFactChecking(data), isTrue);
    });

    test('returns true when aiFeatures has factChecking enabled', () {
      final data = <String, dynamic>{
        'title': 'AI Verification in Progress',
        'aiFeatures': {'factChecking': true},
      };
      expect(TruthVerificationDashboardPage.hasFactChecking(data), isTrue);
    });

    test('returns true when credibility is verified or present in aiFeatures', () {
      final dataWithFactChecking = <String, dynamic>{
        'title': 'Fact Checked Video',
        'isFactChecked': true,
      };
      expect(
        TruthVerificationDashboardPage.hasFactChecking(dataWithFactChecking),
        isTrue,
      );
    });

    test('returns true when video has extracted claims', () {
      final data = <String, dynamic>{'title': 'Video with Claims'};
      final dummyClaim = RealExtractedClaim(
        id: 'c1',
        videoId: 'v1',
        videoTitle: 'Video with Claims',
        text: 'Eggs contain 6 grams of protein',
        timestamp: '01:20',
        timestampSeconds: 80.0,
        category: 'Nutrition',
        confidenceScore: 0.95,
        sourceCitation: 'USDA Database',
        tier: ClaimEvidenceTier.verified,
      );
      expect(
        TruthVerificationDashboardPage.hasFactChecking(
          data,
          claims: [dummyClaim],
        ),
        isTrue,
      );
    });

    test('returns true when uiReport contains key claims or summary', () {
      final data = <String, dynamic>{
        'title': 'Report Video',
        'uiReport': {
          'keyClaims': [
            {'text': 'Claim 1', 'verdict': 'verified'},
          ],
        },
      };
      expect(TruthVerificationDashboardPage.hasFactChecking(data), isTrue);
    });

    test('returns true when reverification is requested or disputed', () {
      final reverifyData = <String, dynamic>{
        'title': 'Reverification Video',
        'reverificationRequested': true,
      };
      expect(
        TruthVerificationDashboardPage.hasFactChecking(reverifyData),
        isTrue,
      );

      final disputeData = <String, dynamic>{
        'title': 'Disputed Video',
        'disputeStatus': 'under_review',
      };
      expect(
        TruthVerificationDashboardPage.hasFactChecking(disputeData),
        isTrue,
      );
    });

    test('returns false for routine video without fact-checking enabled', () {
      // Models routine upload such as "Mahonathuda song by Raj prakash paul worship conference"
      final routineData = <String, dynamic>{
        'title': 'Mahonathuda song by Raj prakash paul worship conference',
        'factCheckReviewMode': 'open_to_users',
        'isFactCheckApproved': true,
                'claims': <dynamic>[],
        'aiFeatures': {
          'factChecking': false,
          'factCheckTier': 'full_ground',
        },
      };
      expect(
        TruthVerificationDashboardPage.hasFactChecking(
          routineData,
          claims: [],
        ),
        isFalse,
      );
    });

    test('returns false for video where factChecking is disabled', () {
      // Models video such as "Are Eggs Vegetarian or Non-Vegetarian?" where fact-checking was not requested
      final eggsVideoData = <String, dynamic>{
        'title': 'Are Eggs Vegetarian or Non-Vegetarian? 🥚 The Science & Truth Explained',
        'factCheckReviewMode': 'open_to_users',
        'isFactCheckApproved': true,
        'isFactChecked': false,
        'claims': <dynamic>[],
        'factCheckUrl': '',
        'aiFeatures': {
          'factChecking': false,
          'factCheckTier': 'full_ground',
        },
      };
      expect(
        TruthVerificationDashboardPage.hasFactChecking(
          eggsVideoData,
          claims: [],
        ),
        isFalse,
      );
    });
  });

  group('VideoFactCheckItem epistemic accuracy & audit structure', () {
    test('correctly handles zero assertions analyzed (opinion/philosophical discourse)', () {
      final item = VideoFactCheckItem(
        id: '014FDF6E-8648-47E0-B83A-D5815DC145A2',
        title: "If a language can be misinterpreted so easily, how can it be a great language? Isn't it useless?",
        thumbnailUrl: '',
        factCheckReviewMode: 'open_to_users',
        isFactCheckApproved: true,
        claims: [],
        summary: 'Philosophical inquiry on language semantics.',
        domain: 'Linguistics',
        createdAt: DateTime.now(),
      );

      expect(item.hasClaims, isFalse);
      expect(item.factualAccuracyScore, isNull);
      expect(item.factualAccuracyLabel, 'Not Assessed (No empirical assertions)');
      expect(item.verificationState, 'INSUFFICIENT_EVIDENCE');
      expect(
        item.consensusValidationStatus,
        'INSUFFICIENT_EVIDENCE_FOR_FACTUAL_CONSENSUS (Media Provenance Verified)',
      );
      expect(item.isPubliclyVisible, isTrue);
    });

    test('correctly computes factual accuracy when empirical claims are present', () {
      final verifiedClaim = RealExtractedClaim(
        id: 'c1',
        videoId: 'v1',
        videoTitle: 'Test Video',
        text: 'Water boils at 100C at standard atmospheric pressure',
        timestamp: '00:10',
        timestampSeconds: 10.0,
        category: 'Science',
        confidenceScore: 0.99,
        sourceCitation: 'IUPAC Database',
        tier: ClaimEvidenceTier.verified,
      );

      final item = VideoFactCheckItem(
        id: 'v1',
        title: 'Test Video',
        thumbnailUrl: '',
        factCheckReviewMode: 'open_to_users',
        isFactCheckApproved: true,
        claims: [verifiedClaim],
        summary: 'Scientific analysis.',
        domain: 'Physics',
        createdAt: DateTime.now(),
      );

      expect(item.hasClaims, isTrue);
      expect(item.factualAccuracyScore, 1.0);
      expect(item.factualAccuracyLabel, '100%');
      expect(item.verificationState, 'VERIFIED_MULTIMODAL_CONSENSUS');
      expect(item.consensusValidationStatus, 'VERIFIED_MULTIMODAL_CONSENSUS');
    });

    testWidgets('TruthVerificationVideoCard renders without category, without media authenticity, without export dossier, and with more vertical button', (tester) async {
      final item = VideoFactCheckItem(
        id: 'v1',
        title: 'Test Verification Video',
        thumbnailUrl: '',
        factCheckReviewMode: 'open_to_users',
        isFactCheckApproved: true,
        claims: [],
        summary: 'Summary text',
        domain: 'Linguistics',
        createdAt: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TruthVerificationVideoCard(
              video: item,
              channelId: 'ch1',
              isDarkMode: false,
              onToggleApproval: (_, _) {},
              onApprove: (_) {},
            ),
          ),
        ),
      );

      // Verify "Export Dossier" is not present
      expect(find.text('Export Dossier'), findsNothing);

      // Verify "Media Authenticity Verified" is not present
      expect(find.text('Media Authenticity Verified'), findsNothing);

      // Verify "Truth Score" is never present or displayed anywhere
      expect(find.textContaining('Truth Score'), findsNothing);
      expect(find.textContaining('truth score'), findsNothing);

      // Verify video category/domain "Linguistics" is not present
      expect(find.text('Linguistics'), findsNothing);

      // Verify more vertical button (PopupMenuButton) is present
      expect(find.byIcon(Icons.more_vert_rounded), findsOneWidget);

      // Verify Inspect Full Report is present
      expect(find.text('Inspect Full Report'), findsOneWidget);

      // Tap more vertical button and verify options
      await tester.tap(find.byIcon(Icons.more_vert_rounded));
      await tester.pumpAndSettle();

      expect(
        find.widgetWithText(
          PopupMenuItem<String>,
          'Approved (Visible to Viewers)',
        ),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(PopupMenuItem<String>, 'Make Private'),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(
          PopupMenuItem<String>,
          'Talk to AI (Add Sources)',
        ),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(PopupMenuItem<String>, 'Dispute'),
        findsOneWidget,
      );
    });

    testWidgets('Tapping Inspect Full Report opens VideoAnalysisScreen on a separate page', (tester) async {
      final item = VideoFactCheckItem(
        id: 'v_inspect_1',
        title: 'Deep-dive Analysis Video',
        thumbnailUrl: '',
        factCheckReviewMode: 'open_to_users',
        isFactCheckApproved: true,
        claims: [],
        summary: 'Detailed summary',
        domain: 'Science',
        createdAt: DateTime.now(),
      );

      await tester.pumpWidget(
        GetMaterialApp(
          home: Scaffold(
            body: TruthVerificationVideoCard(
              video: item,
              channelId: 'ch1',
              isDarkMode: false,
              onToggleApproval: (_, _) {},
              onApprove: (_) {},
            ),
          ),
        ),
      );

      // Verify Inspect Full Report button is displayed
      final inspectButton = find.text('Inspect Full Report');
      expect(inspectButton, findsOneWidget);

      // Tap Inspect Full Report
      await tester.tap(inspectButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      // Verify VideoAnalysisScreen (Ai Check) is opened on a separate page
      expect(find.byType(VideoAnalysisScreen), findsOneWidget);
      expect(find.text('Ai Check'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back_ios_new_rounded), findsOneWidget);

      // Tap back button and verify returning to video card list
      await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      await VideoPresenceService.to.stopWatching(immediate: true);
      await tester.pumpAndSettle();

      expect(find.byType(VideoAnalysisScreen), findsNothing);
      expect(find.text('Inspect Full Report'), findsOneWidget);
    });
  });
}

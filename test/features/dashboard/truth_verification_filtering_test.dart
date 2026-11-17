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
        isFactChecked: true,
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
        isFactChecked: true,
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

      // Verify "Ai check" button is present for ready fact-checks
      expect(find.text('Ai check'), findsOneWidget);

      // Verify unwanted clutter is NOT present
      expect(find.text('Inspect Full Report'), findsNothing);
      expect(find.textContaining('Step 1/5'), findsNothing);
      expect(find.textContaining('Not Yet Available to Users'), findsNothing);

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

    testWidgets('Tapping Ai check opens VideoAnalysisScreen on a separate page', (tester) async {
      final item = VideoFactCheckItem(
        id: 'v_inspect_1',
        title: 'Deep-dive Analysis Video',
        thumbnailUrl: '',
        factCheckReviewMode: 'open_to_users',
        isFactCheckApproved: true,
        isFactChecked: true,
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

      // Verify "Ai check" text button is displayed
      final aiCheckButton = find.text('Ai check');
      expect(aiCheckButton, findsOneWidget);

      // Tap "Ai check"
      await tester.tap(aiCheckButton);
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
      expect(find.text('Ai check'), findsOneWidget);
    });

    testWidgets('renders animated Fact-check in Progress (50%) for in-progress video without unwanted clutter', (tester) async {
      final inProgressItem = VideoFactCheckItem(
        id: 'v_progress_50',
        title: 'Video Analysis In Progress',
        thumbnailUrl: '',
        factCheckReviewMode: 'open_to_users',
        isFactCheckApproved: false,
        isFactChecked: false,
        factCheckStatus: 'running',
        factCheckProgress: 50,
        claims: [],
        summary: '',
        domain: 'History',
        durationSeconds: 462.0, // 07:42
        createdAt: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TruthVerificationVideoCard(
              video: inProgressItem,
              channelId: 'ch1',
              isDarkMode: true,
              onToggleApproval: (_, _) {},
              onApprove: (_) {},
            ),
          ),
        ),
      );

      // Settle progress animation (TweenAnimationBuilder)
      await tester.pump(const Duration(milliseconds: 700));

      // Verify thumbnail timestamp "07:42" is rendered
      expect(find.text('07:42'), findsOneWidget);

      // Verify title is rendered
      expect(find.text('Video Analysis In Progress'), findsOneWidget);

      // Verify animated progress badge renders "Fact-check in Progress (50%)"
      expect(find.text('Fact-check in Progress (50%)'), findsOneWidget);

      // Verify more vertical icon is rendered
      expect(find.byIcon(Icons.more_vert_rounded), findsOneWidget);

      // Verify unwanted clutter is removed
      expect(find.text('Inspect Full Report'), findsNothing);
      expect(find.text('Ai check'), findsNothing);
      expect(find.textContaining('Step 1/5'), findsNothing);
      expect(find.textContaining('remaining'), findsNothing);
      expect(find.textContaining('Not Yet Available to Users'), findsNothing);
      expect(find.textContaining('AI Verification Running'), findsNothing);
      expect(find.textContaining('Extracting claims'), findsNothing);
    });

    test('calculateStagePacedProgress produces continuous granular progress 1%, 2%, 6%, 17%... 100%', () {
      final baseTime = DateTime(2026, 11, 14, 12, 0, 0);

      // Stage 1: Initial backend queue (backendProgress: 5)
      // At t = 0s
      final p0 = TruthVerificationVideoCard.calculateStagePacedProgress(
        backendProgress: 5,
        durationSeconds: 462.0,
        isReady: false,
        stageUpdatedAt: baseTime,
        now: baseTime,
      );
      expect(p0, 1); // Starts at 1%

      // At t = 2s -> 2%
      final p2 = TruthVerificationVideoCard.calculateStagePacedProgress(
        backendProgress: 5,
        durationSeconds: 462.0,
        isReady: false,
        stageUpdatedAt: baseTime,
        now: baseTime.add(const Duration(seconds: 2)),
      );
      expect(p2, 1); // 1%

      // At t = 12s -> 6%
      final p12 = TruthVerificationVideoCard.calculateStagePacedProgress(
        backendProgress: 5,
        durationSeconds: 462.0,
        isReady: false,
        stageUpdatedAt: baseTime,
        now: baseTime.add(const Duration(seconds: 12)),
      );
      expect(p12, 6); // 6%

      // Stage 2: Audio/transcript ready (backendProgress: 10)
      // At t = 8s -> 17%
      final p17 = TruthVerificationVideoCard.calculateStagePacedProgress(
        backendProgress: 10,
        durationSeconds: 462.0,
        isReady: false,
        stageUpdatedAt: baseTime,
        now: baseTime.add(const Duration(seconds: 8)),
      );
      expect(p17, 17); // 17%

      // Stage 3: Grounding against authoritative sources (backendProgress: 50)
      final p50 = TruthVerificationVideoCard.calculateStagePacedProgress(
        backendProgress: 50,
        durationSeconds: 462.0,
        isReady: false,
        stageUpdatedAt: baseTime,
        now: baseTime,
      );
      expect(p50, 50); // 50%

      // Completed stage
      final p100 = TruthVerificationVideoCard.calculateStagePacedProgress(
        backendProgress: 100,
        durationSeconds: 462.0,
        isReady: true,
        stageUpdatedAt: baseTime,
        now: baseTime,
      );
      expect(p100, 100); // 100%
    });

    testWidgets('mounting TruthVerificationDashboardPage with initialVideoId inside Obx does not trigger setState during build',
        (tester) async {
      final dummyRx = 0.obs;

      await tester.pumpWidget(
        GetMaterialApp(
          home: Scaffold(
            body: Obx(() {
              // Read an observable to simulate an Obx parent build phase
              dummyRx.value;
              return TruthVerificationDashboardPage(
                channelId: 'test_channel_obx',
                isDarkMode: true,
                initialVideoId: 'video_deep_linked_123',
              );
            }),
          ),
        ),
      );

      // Verify no exception was thrown during Obx build phase
      expect(tester.takeException(), isNull);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(TruthVerificationDashboardPage), findsOneWidget);
    });

    testWidgets(
        'renders Re-trigger Fact-Check button when fact-check is not ready and invokes callback',
        (tester) async {
      String? retriggeredVideoId;

      final unverifiedVideo = VideoFactCheckItem(
        id: 'v_unverified_1',
        title: 'Video Needing Fact Check',
        thumbnailUrl: '',
        factCheckReviewMode: 'open_to_users',
        isFactCheckApproved: false,
        isFactChecked: false,
        claims: [],
        summary: 'Not assessed',
        domain: 'General',
        createdAt: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TruthVerificationVideoCard(
              video: unverifiedVideo,
              channelId: 'ch1',
              isDarkMode: false,
              onToggleApproval: (_, _) {},
              onApprove: (_) {},
              onRetrigger: (id) {
                retriggeredVideoId = id;
              },
            ),
          ),
        ),
      );

      // Verify status badge shows "Needs Fact-Check"
      expect(find.text('Needs Fact-Check'), findsOneWidget);

      // Verify "Re-trigger Fact-Check" button is rendered
      final retriggerBtn = find.text('Re-trigger Fact-Check');
      expect(retriggerBtn, findsWidgets);

      // Tap the primary Re-trigger Fact-Check button
      await tester.tap(retriggerBtn.first);
      await tester.pump();
      expect(retriggeredVideoId, 'v_unverified_1');

      // Reset tracker
      retriggeredVideoId = null;

      // Open popup menu
      await tester.tap(find.byIcon(Icons.more_vert_rounded));
      await tester.pumpAndSettle();

      // Find the menu option
      final menuItem =
          find.widgetWithText(PopupMenuItem<String>, 'Re-trigger Fact-Check');
      expect(menuItem, findsOneWidget);

      // Tap menu item
      await tester.tap(menuItem);
      await tester.pumpAndSettle();
      expect(retriggeredVideoId, 'v_unverified_1');
    });
  });
}

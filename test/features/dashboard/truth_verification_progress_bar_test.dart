import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truthworld/theme/app_theme.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/truth_verification/truth_verification_models.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/truth_verification/truth_verification_progress_bar.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/truth_verification/truth_verification_video_card.dart';
import '../../test_helpers/mock_firebase.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await setupMockFirebase();
  });

  group('TruthVerificationProgressBar & Studio Factcheck Tab Progress Tests', () {
    testWidgets('renders 100% complete and "Available to Users" when fact-check is ready & approved', (tester) async {
      final readyItem = VideoFactCheckItem(
        id: 'v_ready_1',
        title: 'Completed Fact-Check Video',
        thumbnailUrl: '',
        factCheckReviewMode: 'open_to_users',
        isFactCheckApproved: true,
        isFactChecked: true,
        claims: [
          RealExtractedClaim(
            id: 'c1',
            videoId: 'v_ready_1',
            videoTitle: 'Completed Fact-Check Video',
            text: 'Photosynthesis converts light energy into chemical energy.',
            timestamp: '00:15',
            timestampSeconds: 15.0,
            category: 'Biology',
            confidenceScore: 0.99,
            sourceCitation: 'Nature Biology 2024',
            tier: ClaimEvidenceTier.verified,
          ),
        ],
        summary: 'Fully verified video analysis.',
        domain: 'Science',
        createdAt: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TruthVerificationProgressBar(
              video: readyItem,
              isDarkMode: true,
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 500));

      // Verify progress title & 100% label
      expect(find.text('Factcheck Ready: 100%'), findsOneWidget);

      // Verify availability badge
      expect(find.text('Available to Users'), findsOneWidget);

      // Verify subtitle explanation
      expect(
        find.text('Available to Users: Credibility badges & verified claims are live on player.'),
        findsOneWidget,
      );

      // Verify LinearProgressIndicator is at 100% (value 1.0)
      final progressIndicator = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(progressIndicator.value, 1.0);
    });

    testWidgets('renders 100% complete and "Pending Approval (Private)" with "Approve for Users" button when review first', (tester) async {
      String? approvedVideoId;

      final pendingItem = VideoFactCheckItem(
        id: 'v_pending_1',
        title: 'Pending Review Fact-Check Video',
        thumbnailUrl: '',
        factCheckReviewMode: 'first_to_creator',
        isFactCheckApproved: false,
        isFactChecked: true,
        claims: [
          RealExtractedClaim(
            id: 'c1',
            videoId: 'v_pending_1',
            videoTitle: 'Pending Review Fact-Check Video',
            text: 'Water boils at 100 degrees Celsius at sea level.',
            timestamp: '00:05',
            timestampSeconds: 5.0,
            category: 'Physics',
            confidenceScore: 0.98,
            sourceCitation: 'IUPAC Standards',
            tier: ClaimEvidenceTier.verified,
          ),
        ],
        summary: 'Awaiting creator confirmation before publishing.',
        domain: 'Physics',
        createdAt: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TruthVerificationProgressBar(
              video: pendingItem,
              isDarkMode: true,
              onApprove: (id) {
                approvedVideoId = id;
              },
            ),
          ),
        ),
      );

      // Verify 100% ready label
      expect(find.text('Factcheck Ready: 100%'), findsOneWidget);

      // Verify pending review badge
      expect(find.text('Pending Approval (Private)'), findsOneWidget);

      // Verify "Approve for Users" action button
      final approveButton = find.widgetWithText(ElevatedButton, 'Approve for Users');
      expect(approveButton, findsOneWidget);

      // Tap "Approve for Users" button and verify callback
      await tester.tap(approveButton);
      await tester.pump();
      expect(approvedVideoId, 'v_pending_1');
    });

    testWidgets('renders real progress percentage (45%) and stage description when in progress', (tester) async {
      final inProgressItem = VideoFactCheckItem(
        id: 'v_progress_1',
        title: 'Actively Processing Video',
        thumbnailUrl: '',
        factCheckReviewMode: 'open_to_users',
        isFactCheckApproved: true,
        isFactChecked: false,
        factCheckProgress: 45,
        factCheckStatus: 'running',
        claims: const [],
        summary: '',
        domain: 'General',
        createdAt: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TruthVerificationProgressBar(
              video: inProgressItem,
              isDarkMode: true,
            ),
          ),
        ),
      );

      // Wait for TweenAnimationBuilder
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Verify real progress percentage label
      expect(find.text('Factcheck In Progress: 45%'), findsOneWidget);

      // Verify availability badge indicates not yet available
      expect(find.text('Not Yet Available to Users'), findsOneWidget);

      // Verify stage description
      expect(
        find.textContaining('Step 3/5: Querying knowledge registries'),
        findsOneWidget,
      );
    });

    testWidgets('TruthVerificationVideoCard renders clean animated progress without unwanted clutter', (tester) async {
      final item = VideoFactCheckItem(
        id: 'v_card_1',
        title: 'Video with Integrated Progress Bar',
        thumbnailUrl: '',
        factCheckReviewMode: 'first_to_creator',
        isFactCheckApproved: false,
        isFactChecked: false,
        factCheckProgress: 70,
        factCheckStatus: 'running',
        claims: const [],
        summary: '',
        domain: 'Economics',
        createdAt: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TruthVerificationVideoCard(
              video: item,
              channelId: 'ch_test',
              isDarkMode: true,
              onToggleApproval: (_, _) {},
              onApprove: (_) {},
            ),
          ),
        ),
      );

      // Pump animation
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));

      // Verify animated progress badge is present
      expect(find.text('Fact-check in Progress (70%)'), findsOneWidget);

      // Verify more vertical menu is present
      expect(find.byIcon(Icons.more_vert_rounded), findsOneWidget);

      // Verify unwanted clutter is removed
      expect(find.byType(TruthVerificationProgressBar), findsNothing);
      expect(find.textContaining('AI Verification Running'), findsNothing);
      expect(find.textContaining('Step 1/5'), findsNothing);
    });

    testWidgets('renders "Held Private" state with "Publish to Users" button', (tester) async {
      String? toggledVideoId;
      bool? currentStatusPassed;

      final privateItem = VideoFactCheckItem(
        id: 'v_private_1',
        title: 'Held Private Fact-Check Video',
        thumbnailUrl: '',
        factCheckReviewMode: 'open_to_users',
        isFactCheckApproved: false, // Explicitly held private by creator
        isFactChecked: true,
        claims: const [],
        summary: 'Completed report held private',
        domain: 'General',
        createdAt: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TruthVerificationProgressBar(
              video: privateItem,
              isDarkMode: true,
              onToggleApproval: (id, status) {
                toggledVideoId = id;
                currentStatusPassed = status;
              },
            ),
          ),
        ),
      );

      expect(find.text('Factcheck Ready: 100%'), findsOneWidget);
      expect(find.text('Held Private'), findsOneWidget);

      final publishButton = find.widgetWithText(ElevatedButton, 'Publish to Users');
      expect(publishButton, findsOneWidget);

      await tester.tap(publishButton);
      await tester.pump();
      expect(toggledVideoId, 'v_private_1');
      expect(currentStatusPassed, isFalse);
    });

    test('calculates realistic estimated time remaining (ETA) according to industry standards', () {
      final now = DateTime(2026, 11, 13, 22, 0, 0);

      // 1. Ready video -> 'Ready'
      final readyItem = VideoFactCheckItem(
        id: 'v1',
        title: 'Ready Video',
        thumbnailUrl: '',
        factCheckReviewMode: 'open_to_users',
        isFactCheckApproved: true,
        isFactChecked: true,
        claims: const [],
        summary: '',
        domain: 'General',
        createdAt: now.subtract(const Duration(minutes: 5)),
      );
      expect(readyItem.calculateEstimatedTimeRemaining(now: now), 'Ready');

      // 2. High progress (96%) -> 'Finalizing shortly...'
      final almostDoneItem = VideoFactCheckItem(
        id: 'v2',
        title: 'Almost Done Video',
        thumbnailUrl: '',
        factCheckReviewMode: 'open_to_users',
        isFactCheckApproved: true,
        isFactChecked: false,
        factCheckProgress: 96,
        factCheckStatus: 'running',
        claims: const [],
        summary: '',
        domain: 'General',
        createdAt: now.subtract(const Duration(seconds: 40)),
      );
      expect(almostDoneItem.calculateEstimatedTimeRemaining(now: now), 'Finalizing shortly...');

      // 3. 3-minute video (180s) at 30% progress with 12s elapsed
      final standardVideo = VideoFactCheckItem(
        id: 'v3',
        title: 'Standard Video',
        thumbnailUrl: '',
        factCheckReviewMode: 'open_to_users',
        isFactCheckApproved: true,
        isFactChecked: false,
        durationSeconds: 180.0,
        factCheckProgress: 30,
        factCheckStatus: 'running',
        startedAt: now.subtract(const Duration(seconds: 12)),
        claims: const [],
        summary: '',
        domain: 'Science',
        createdAt: now.subtract(const Duration(seconds: 15)),
      );
      final eta3 = standardVideo.calculateEstimatedTimeRemaining(now: now);
      expect(eta3, contains('remaining'));

      // 4. Long video (600s) deep tier at 10% progress
      final deepLongVideo = VideoFactCheckItem(
        id: 'v4',
        title: 'Deep Long Video',
        thumbnailUrl: '',
        factCheckReviewMode: 'open_to_users',
        isFactCheckApproved: true,
        isFactChecked: false,
        durationSeconds: 600.0,
        factCheckTier: 'deep',
        factCheckProgress: 10,
        factCheckStatus: 'running',
        startedAt: now.subtract(const Duration(seconds: 10)),
        claims: const [],
        summary: '',
        domain: 'History',
        createdAt: now.subtract(const Duration(seconds: 12)),
      );
      final eta4 = deepLongVideo.calculateEstimatedTimeRemaining(now: now);
      expect(eta4, contains('remaining'));
    });

    testWidgets('displays ETA chip and subtitle in TruthVerificationProgressBar during active verification', (tester) async {
      final now = DateTime.now();
      final inProgressItem = VideoFactCheckItem(
        id: 'v_eta_test',
        title: 'Video with Live ETA',
        thumbnailUrl: '',
        factCheckReviewMode: 'open_to_users',
        isFactCheckApproved: true,
        isFactChecked: false,
        durationSeconds: 180.0,
        factCheckProgress: 50,
        factCheckStatus: 'running',
        startedAt: now.subtract(const Duration(seconds: 20)),
        claims: const [],
        summary: '',
        domain: 'General',
        createdAt: now.subtract(const Duration(seconds: 25)),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TruthVerificationProgressBar(
              video: inProgressItem,
              isDarkMode: true,
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Verify timer icon is displayed in the ETA chip
      expect(find.byIcon(Icons.timer_outlined), findsOneWidget);

      // Verify subtitle includes estimated time
      expect(find.textContaining('Est.'), findsOneWidget);
    });
  });
}

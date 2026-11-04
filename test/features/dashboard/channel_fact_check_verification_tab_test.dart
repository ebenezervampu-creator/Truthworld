import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/services/connectivity_service.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/truth_verification/truth_verification_ai_coach_tab.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/truth_verification/truth_verification_conclusion_tab.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/truth_verification/truth_verification_models.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/truth_verification/truth_verification_opinions_tab.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/truth_verification/truth_verification_overview_tab.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/truth_verification/truth_verification_sources_tab.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/truth_verification/truth_verification_tab_bar.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/truth_verification_dashboard_page.dart';
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

  void setDesktopSize(WidgetTester tester) {
    tester.view.physicalSize = const Size(1600, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  group('Channel Fact-Check & Verification Tab Suite', () {
    final sampleVerifiedClaim = RealExtractedClaim(
      id: 'c1',
      videoId: 'v1',
      videoTitle: 'Nutrition Science & Truth',
      text: 'Whole eggs provide 6 to 7 grams of complete bioavailable protein.',
      timestamp: '01:15',
      timestampSeconds: 75.0,
      category: 'Nutrition',
      confidenceScore: 0.98,
      sourceCitation: 'USDA FoodData Central Registry',
      tier: ClaimEvidenceTier.verified,
      nature: 'FACT',
      sourceUrl: 'https://fdc.nal.usda.gov',
    );

    final sampleCautionClaim = RealExtractedClaim(
      id: 'c2',
      videoId: 'v1',
      videoTitle: 'Nutrition Science & Truth',
      text: 'Eating 3 eggs every morning doubles metabolic efficiency.',
      timestamp: '03:40',
      timestampSeconds: 220.0,
      category: 'Metabolism',
      confidenceScore: 0.65,
      sourceCitation: 'Unverified Blog Claim',
      tier: ClaimEvidenceTier.needsSource,
      nature: 'FACT',
    );

    final sampleOpinionClaim = RealExtractedClaim(
      id: 'c3',
      videoId: 'v1',
      videoTitle: 'Nutrition Science & Truth',
      text: 'Poached eggs taste infinitely superior to fried eggs.',
      timestamp: '05:10',
      timestampSeconds: 310.0,
      category: 'Culinary Commentary',
      confidenceScore: 0.90,
      sourceCitation: 'Personal Perspective',
      tier: ClaimEvidenceTier.verified,
      nature: 'OPINION',
      verdict: 'opinion',
    );

    final sampleVideo = VideoFactCheckItem(
      id: 'v1',
      title: 'Nutrition Science & Truth',
      thumbnailUrl: '',
      factCheckReviewMode: 'first_to_creator',
      isFactCheckApproved: false,
      claims: [sampleVerifiedClaim, sampleCautionClaim, sampleOpinionClaim],
      summary: 'Empirical analysis of egg nutrition and metabolic claims.',
      domain: 'Health & Nutrition',
      createdAt: DateTime.now(),
      sources: [
        {
          'title': 'USDA FoodData Central',
          'url': 'https://fdc.nal.usda.gov',
          'domain': 'fdc.nal.usda.gov',
          'publisher': 'US Department of Agriculture',
        },
      ],
    );

    testWidgets('TruthVerificationTabBar renders all 8 consumer-inspired tabs and handles selection', (tester) async {
      setDesktopSize(tester);
      int selectedIdx = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return TruthVerificationTabBar(
                  selectedTab: selectedIdx,
                  onTabSelected: (idx) => setState(() => selectedIdx = idx),
                  claimsCount: 3,
                  videosCount: 1,
                  opinionsCount: 1,
                  sourcesCount: 1,
                  isDarkMode: true,
                );
              },
            ),
          ),
        ),
      );

      // Verify all 8 tab labels are rendered
      expect(find.text('Fact Claims'), findsOneWidget);
      expect(find.text('Overview'), findsOneWidget);
      expect(find.text('Video Reports'), findsOneWidget);
      expect(find.text('Opinions & Context'), findsOneWidget);
      expect(find.text('Sources & Citations'), findsOneWidget);
      expect(find.text('Conclusion & Insights'), findsOneWidget);
      expect(find.text('Audit & Transparency'), findsOneWidget);
      expect(find.text('Ask AI Truth Coach'), findsOneWidget);

      // Tap on Overview tab
      await tester.tap(find.text('Overview'));
      await tester.pumpAndSettle();
      expect(selectedIdx, 1);

      // Tap on Ask AI Truth Coach tab
      await tester.ensureVisible(find.text('Ask AI Truth Coach'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ask AI Truth Coach'));
      await tester.pumpAndSettle();
      expect(selectedIdx, 7);
    });

    testWidgets('TruthVerificationOverviewTab renders executive overview, summary cards, and factors', (tester) async {
      setDesktopSize(tester);
      int switchedTab = -1;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: TruthVerificationOverviewTab(
                videos: [sampleVideo],
                allClaims: [sampleVerifiedClaim, sampleCautionClaim],
                isDarkMode: true,
                onSwitchToTab: (idx) => switchedTab = idx,
              ),
            ),
          ),
        ),
      );

      // Verify Executive Overview
      expect(find.text('Channel Truth Intelligence & Epistemic Audit'), findsOneWidget);
      expect(find.text('IFCN Standard Compliance'), findsOneWidget);
      expect(find.text('15-20% Discovery Boost Active'), findsOneWidget);

      // Verify Verification Summary Card
      expect(find.text('Verification Summary'), findsOneWidget);
      expect(find.text('Total Claims'), findsOneWidget);
      expect(find.text('Needs Evidence'), findsOneWidget);

      // Verify Multi-Dimensional Credibility Factors
      expect(find.text('Multi-Dimensional Credibility Factors'), findsOneWidget);
      expect(find.text('Empirical Evidence Grounding'), findsOneWidget);
      expect(find.text('Primary Source Independence'), findsOneWidget);

      // Verify Transparent Methodology Section
      expect(find.text('Transparent AI Verification Methodology'), findsOneWidget);

      // Verify Creator Advice
      expect(find.text('Creator Advice: Maximizing Your Algorithmic Distribution'), findsOneWidget);
    });

    testWidgets('TruthVerificationOpinionsTab renders demarcation banner and excludes opinions from penalty', (tester) async {
      setDesktopSize(tester);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: TruthVerificationOpinionsTab(
                opinionClaims: [sampleOpinionClaim],
                isDarkMode: true,
              ),
            ),
          ),
        ),
      );

      // Verify Epistemic Fairness banner
      expect(find.text('Epistemic Fairness: Opinions & Creative Expression'), findsOneWidget);
      expect(find.textContaining('TruthWorld\'s Credibility Engine does not penalize subjective viewpoints'), findsOneWidget);

      // Verify Opinion statement
      expect(find.text('"Poached eggs taste infinitely superior to fried eggs."'), findsOneWidget);
      expect(find.text('Excluded from Penalty'), findsOneWidget);
      expect(find.text('OPINION'), findsOneWidget);
    });

    testWidgets('TruthVerificationSourcesTab extracts sources and renders trust tier badges', (tester) async {
      setDesktopSize(tester);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: TruthVerificationSourcesTab(
                videos: [sampleVideo],
                allClaims: [sampleVerifiedClaim],
                isDarkMode: true,
              ),
            ),
          ),
        ),
      );

      // Verify Source Title & Tier
      expect(find.textContaining('Indexed Authorities & Citations'), findsOneWidget);
      expect(find.text('USDA FoodData Central'), findsOneWidget);
      expect(find.text('Government Registry (Tier 1)'), findsOneWidget);
    });

    testWidgets('TruthVerificationConclusionTab renders verdict hero and algorithmic boost details', (tester) async {
      setDesktopSize(tester);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: TruthVerificationConclusionTab(
                videos: [sampleVideo],
                allClaims: [sampleVerifiedClaim],
                isDarkMode: true,
                onSwitchToTab: (_) {},
              ),
            ),
          ),
        ),
      );

      // Verify Verdict Hero
      expect(find.text('Consensus Grounded (Grade A)'), findsOneWidget);
      expect(find.textContaining('TruthScore Metric: 100%'), findsOneWidget);

      // Verify Algorithmic Advantage Card
      expect(find.text('15% to 20% Algorithmic Discovery Advantage'), findsOneWidget);
      expect(find.textContaining('Home Feed Unexplored Tab: Priority placement'), findsOneWidget);
      expect(find.text('Actionable AI Recommendations for Your Channel'), findsOneWidget);
    });

    testWidgets('TruthVerificationAiCoachTab renders coach header, prompt chips, and handles interactive query', (tester) async {
      setDesktopSize(tester);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: TruthVerificationAiCoachTab(
                channelId: 'ch1',
                allClaims: [sampleVerifiedClaim],
                videos: [sampleVideo],
                isDarkMode: true,
              ),
            ),
          ),
        ),
      );

      // Verify Coach Header
      expect(find.text('Truth Intelligence AI Creator Coach'), findsOneWidget);
      expect(find.textContaining('Hello Creator! I am your Truth Intelligence Coach'), findsOneWidget);

      // Verify Prompt Chip
      final promptChip = find.text('How do I turn caution flags into verified claims?');
      expect(promptChip, findsOneWidget);

      // Tap prompt chip
      await tester.tap(promptChip);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));

      // Verify coach responded with guidance
      expect(find.textContaining('To maintain this status on future uploads'), findsOneWidget);
    });
  });
}

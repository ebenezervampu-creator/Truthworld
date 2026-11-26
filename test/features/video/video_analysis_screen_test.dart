import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/services/connectivity_service.dart';
import 'package:truthworld/data/models/channel.dart';
import 'package:truthworld/features/video/data/models/credibility_report.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/features/video/presentation/controllers/video_controller.dart';
import 'package:truthworld/features/video/presentation/views/video_analysis_screen.dart';
import 'package:truthworld/features/video/presentation/widgets/analysis/video_analysis_widgets.dart';

import '../../test_helpers/mock_firebase.dart';

class FakeConnectivityService extends GetxService implements ConnectivityService {
  @override
  ConnectivityResult get connectionStatus => ConnectivityResult.wifi;
  @override
  bool get isConnected => true;
  @override
  bool get isWifi => true;
  @override
  Stream<List<ConnectivityResult>> get onConnectivityChanged => const Stream.empty();
  @override
  Stream<ConnectivityResult> get onConnectivityRestored => const Stream.empty();
  @override
  Future<ConnectivityService> init() async => this;
}

class _MockAuthService extends GetxService implements AuthService {
  @override
  String get uid => 'user_123';
  @override
  Channel? get userChannel => null;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await setupMockFirebase();
  });

  setUp(() {
    Get.reset();
    Get.put<AuthService>(_MockAuthService());
    Get.put<ConnectivityService>(FakeConnectivityService());
  });

  tearDown(Get.reset);

  final testUiReport = UIReport.fromMap({
    'summary': 'Scientific analysis of eggs.',
    'quickVerdict': 'Verified Scientific Consensus',
    'narrative': 'Biological and culinary consensus distinguishes unfertilized commercial eggs from fertilized embryonic tissue.',
    'riskNote': 'None',
    'positiveDrivers': [],
    'negativeDrivers': [],
    'conclusion':
        'Commercially produced unfertilized eggs contain no embryo or cellular life, rendering them scientifically vegetarian from a biological reproduction standpoint.',
    'conclusionSources': [
      {
        'type': 'journal',
        'title': 'Poultry Science Journal',
        'domain': 'poultryscience.org',
        'url': 'https://poultryscience.org/egg-biology',
        'trustLevel': 'High',
      },
      {
        'type': 'website',
        'title': 'Indian Council of Medical Research',
        'domain': 'icmr.gov.in',
        'url': 'https://icmr.gov.in/dietary-guidelines',
        'trustLevel': 'High',
      },
    ],
    'sources': [
      {
        'type': 'website',
        'title': 'Food and Agriculture Organization',
        'domain': 'fao.org',
        'url': 'https://fao.org/poultry',
        'trustLevel': 'High',
      },
    ],
  });

  final testVideo = Video(
    id: 'test_video_egg',
    ownerId: 'owner_egg',
    title: 'Are Eggs Vegetarian or Non-Vegetarian?',
    description: 'Scientific and biological analysis of unfertilized eggs.',
    videoUrl: 'https://example.com/egg.mp4',
    thumbnailUrl: 'https://example.com/egg.jpg',
    channelId: 'channel_egg',
    channelName: 'Science Truth',
    channelAvatarUrl: '',
    duration: 320,
    viewCount: 2000,
    likeCount: 150,
    dislikeCount: 2,
    commentCount: 45,
    createdAt: Timestamp.now(),
    updatedAt: Timestamp.now(),
    tags: const ['science', 'food'],
    category: 'Science',
    visibility: 'public',
    uiReport: testUiReport,
  );

  group('VideoAnalysisScreen Separate Page Tests', () {
    testWidgets('renders dedicated page with AppBar, video context card, and 3 tabs', (tester) async {
      final controller = Get.put(VideoController(), tag: testVideo.id);
      controller.factCheckData.value = {
        'state': 'COMPLETED',
        'truthScore': 88.0,
        'trustScore': 88.0,
        'confidence': 0.94,
        'claimCount': 1,
        'verifiedCount': 1,
        'cautionCount': 0,
        'falseCount': 0,
        'tierBadge': 'VERIFIED FACT-CHECK',
        'isNotScored': false,
        'conclusion':
            'Commercially produced unfertilized eggs contain no embryo or cellular life, rendering them scientifically vegetarian from a biological reproduction standpoint.',
        'conclusionSources': [
          {
            'type': 'journal',
            'title': 'Poultry Science Journal',
            'domain': 'poultryscience.org',
            'url': 'https://poultryscience.org/egg-biology',
            'trustLevel': 'High',
          },
          {
            'type': 'website',
            'title': 'Indian Council of Medical Research',
            'domain': 'icmr.gov.in',
            'url': 'https://icmr.gov.in/dietary-guidelines',
            'trustLevel': 'High',
          },
        ],
        'claims': [
          {
            'claim': 'Unfertilized commercial eggs do not possess embryonic viability.',
            'verdict': 'verified',
            'confidence': 0.96,
            'explanation': 'Confirmed by poultry biological reproduction guidelines.',
          },
        ],
        'uiReport': testUiReport.toMap(),
      };

      await tester.pumpWidget(
        GetMaterialApp(
          home: VideoAnalysisScreen(
            video: testVideo,
            controller: controller,
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // 1. Verify Page AppBar with back button & title
      expect(find.text('Ai Check'), findsOneWidget);
      expect(find.text('Independent Empirical Verification'), findsNothing);
      expect(find.byIcon(Icons.arrow_back_ios_new_rounded), findsOneWidget);
      expect(find.byIcon(Icons.refresh_rounded), findsNothing);
      expect(find.byIcon(Icons.chat_bubble_outline_rounded), findsOneWidget);

      // 2. Verify Video Context Card at top of the page
      expect(find.text('Are Eggs Vegetarian or Non-Vegetarian?'), findsNothing);
      expect(find.text('Science Truth'), findsNothing);

      // 3. Verify Four Tab Bar is present on the page
      expect(find.byKey(const Key('tab_claims')), findsOneWidget);
      expect(find.byKey(const Key('tab_overview')), findsOneWidget);
      expect(find.byKey(const Key('tab_sources')), findsOneWidget);
      expect(find.byKey(const Key('tab_conclusion')), findsOneWidget);

      // 4. Default tab is Fact-Claims (index 0) with VerificationSummaryCard and Claims Section
      expect(find.byType(VerificationSummaryCard), findsOneWidget);
      expect(find.text('Fact-Checked Claims (1)'), findsOneWidget);
    });

    testWidgets('navigates to Conclusion tab on the dedicated page', (tester) async {
      final controller = Get.put(VideoController(), tag: testVideo.id);
      controller.factCheckData.value = {
        'state': 'COMPLETED',
        'truthScore': 88.0,
        'trustScore': 88.0,
        'confidence': 0.94,
        'claimCount': 1,
        'verifiedCount': 1,
        'cautionCount': 0,
        'falseCount': 0,
        'tierBadge': 'VERIFIED FACT-CHECK',
        'isNotScored': false,
        'conclusion':
            'Commercially produced unfertilized eggs contain no embryo or cellular life, rendering them scientifically vegetarian from a biological reproduction standpoint.',
        'conclusionSources': [
          {
            'type': 'journal',
            'title': 'Poultry Science Journal',
            'domain': 'poultryscience.org',
            'url': 'https://poultryscience.org/egg-biology',
            'trustLevel': 'High',
          },
          {
            'type': 'website',
            'title': 'Indian Council of Medical Research',
            'domain': 'icmr.gov.in',
            'url': 'https://icmr.gov.in/dietary-guidelines',
            'trustLevel': 'High',
          },
        ],
        'claims': [
          {
            'claim': 'Unfertilized commercial eggs do not possess embryonic viability.',
            'verdict': 'verified',
            'confidence': 0.96,
            'explanation': 'Confirmed by poultry biological reproduction guidelines.',
          },
        ],
        'uiReport': testUiReport.toMap(),
      };

      await tester.pumpWidget(
        GetMaterialApp(
          home: VideoAnalysisScreen(
            video: testVideo,
            controller: controller,
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Tap Conclusion tab
      await tester.tap(find.byKey(const Key('tab_conclusion')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('VERIFIED CONCLUSION'), findsOneWidget);
      expect(
        find.textContaining('Commercially produced unfertilized eggs contain no embryo or cellular life'),
        findsOneWidget,
      );
      // Sources are no longer dumped in conclusion tab; verify they are absent from conclusion
      expect(find.text('SUPPORTING SOURCES & CITATIONS (2)'), findsNothing);
      expect(find.textContaining('Fact-Claims'), findsOneWidget);
    });

    testWidgets('navigates to Overview tab and verifies multi-tab switching on page', (tester) async {
      final controller = Get.put(VideoController(), tag: testVideo.id);
      controller.factCheckData.value = {
        'state': 'COMPLETED',
        'truthScore': 88.0,
        'trustScore': 88.0,
        'confidence': 0.94,
        'claimCount': 1,
        'verifiedCount': 1,
        'cautionCount': 0,
        'falseCount': 0,
        'tierBadge': 'VERIFIED FACT-CHECK',
        'isNotScored': false,
        'claims': [
          {
            'claim': 'Unfertilized commercial eggs do not possess embryonic viability.',
            'verdict': 'verified',
            'confidence': 0.96,
            'explanation': 'Confirmed by poultry biological reproduction guidelines.',
          },
        ],
        'uiReport': testUiReport.toMap(),
      };

      await tester.pumpWidget(
        GetMaterialApp(
          home: VideoAnalysisScreen(
            video: testVideo,
            controller: controller,
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Tap Overview tab
      await tester.tap(find.byKey(const Key('tab_overview')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('EXECUTIVE OVERVIEW'), findsOneWidget);
      expect(find.text('CLAIMS OVERVIEW & KEY FINDINGS'), findsOneWidget);

      // Tap Fact-Claims tab
      await tester.tap(find.byKey(const Key('tab_claims')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Fact-Checked Claims (1)'), findsOneWidget);
    });

    testWidgets('renders dedicated Desktop 2-column layout on widescreen desktop viewports', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final controller = Get.put(VideoController(), tag: testVideo.id);
      controller.factCheckData.value = {
        'state': 'COMPLETED',
        'truthScore': 88.0,
        'trustScore': 88.0,
        'confidence': 0.94,
        'claimCount': 1,
        'verifiedCount': 1,
        'cautionCount': 0,
        'falseCount': 0,
        'tierBadge': 'VERIFIED FACT-CHECK',
        'isNotScored': false,
        'conclusion':
            'Commercially produced unfertilized eggs contain no embryo or cellular life, rendering them scientifically vegetarian from a biological reproduction standpoint.',
        'conclusionSources': [
          {
            'type': 'journal',
            'title': 'Poultry Science Journal',
            'domain': 'poultryscience.org',
            'url': 'https://poultryscience.org/egg-biology',
            'trustLevel': 'High',
          },
        ],
        'claims': [
          {
            'claim': 'Unfertilized commercial eggs do not possess embryonic viability.',
            'verdict': 'verified',
            'confidence': 0.96,
            'explanation': 'Confirmed by poultry biological reproduction guidelines.',
          },
        ],
        'uiReport': testUiReport.toMap(),
      };

      await tester.pumpWidget(
        GetMaterialApp(
          home: VideoAnalysisScreen(
            video: testVideo,
            controller: controller,
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // 1. Verify Desktop Layout is rendered
      expect(find.byType(VideoAnalysisDesktopLayout), findsOneWidget);

      // 2. Verify Left Sidebar features (Video details, Back to Video button, Authenticity Index)
      expect(find.text('Back to Video'), findsOneWidget);
      expect(find.byType(VerificationSummaryCard), findsOneWidget);
      expect(find.text('Truth Intelligence Takeaway'), findsOneWidget);

      // 3. Verify Right Pane features (Desktop Search, Sort menu, Filter pills, Claims)
      expect(find.text('Search claims...'), findsOneWidget);
      expect(find.text('Fact-Checked Claims (1)'), findsOneWidget);
      expect(find.text('All (1)'), findsOneWidget);
      expect(find.text('Verified (1)'), findsOneWidget);

      // 4. Test desktop tab switching to Conclusion
      await tester.tap(find.byKey(const Key('tab_conclusion')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('VERIFIED CONCLUSION'), findsOneWidget);
      // Conclusion tab is clean of sources dump
      expect(find.text('SUPPORTING SOURCES & CITATIONS (1)'), findsNothing);

      // 5. Test desktop tab switching to Overview (where Most Valuable Sources are rendered)
      await tester.tap(find.byKey(const Key('tab_overview')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('CLAIMS OVERVIEW & KEY FINDINGS'), findsOneWidget);
      expect(find.text('MOST VALUABLE SOURCES & CITATIONS'), findsOneWidget);
      expect(find.text('Poultry Science Journal'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.byType(VideoAnalysisConfidenceBar),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.byType(VideoAnalysisConfidenceBar), findsOneWidget);
    });

    testWidgets('does not use Desktop Layout on mobile viewports (< 1024px)', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final controller = Get.put(VideoController(), tag: testVideo.id);
      controller.factCheckData.value = {
        'state': 'COMPLETED',
        'truthScore': 88.0,
        'trustScore': 88.0,
        'confidence': 0.94,
        'claimCount': 1,
        'verifiedCount': 1,
        'cautionCount': 0,
        'falseCount': 0,
        'claims': [
          {
            'claim': 'Unfertilized commercial eggs do not possess embryonic viability.',
            'verdict': 'verified',
            'confidence': 0.96,
            'explanation': 'Confirmed by poultry biological reproduction guidelines.',
          },
        ],
        'uiReport': testUiReport.toMap(),
      };

      await tester.pumpWidget(
        GetMaterialApp(
          home: VideoAnalysisScreen(
            video: testVideo,
            controller: controller,
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // On mobile viewports, VideoAnalysisDesktopLayout MUST NOT be rendered
      expect(find.byType(VideoAnalysisDesktopLayout), findsNothing);
      expect(find.byType(VideoAnalysisView), findsOneWidget);

      // On mobile sized devices / web mobiles, VerificationSummaryCard MUST be hidden
      expect(find.byType(VerificationSummaryCard), findsNothing);
    });

    testWidgets('hides VerificationSummaryCard on mobile sized devices across all tabs', (tester) async {
      tester.view.physicalSize = const Size(412, 892); // Standard mobile phone & web mobile
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final controller = Get.put(VideoController(), tag: testVideo.id);
      controller.factCheckData.value = {
        'state': 'COMPLETED',
        'truthScore': 88.0,
        'trustScore': 88.0,
        'confidence': 0.94,
        'claimCount': 2,
        'verifiedCount': 1,
        'cautionCount': 1,
        'falseCount': 0,
        'conclusion': 'Scientific consensus verifies these findings.',
        'claims': [
          {
            'claim': 'Claim 1 statement',
            'verdict': 'verified',
            'status': 'verified',
          },
          {
            'claim': 'Claim 2 statement',
            'verdict': 'partially_verified',
            'status': 'partially_verified',
          },
        ],
        'uiReport': testUiReport.toMap(),
      };

      await tester.pumpWidget(
        GetMaterialApp(
          home: VideoAnalysisScreen(
            video: testVideo,
            controller: controller,
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // 1. Fact-Claims Tab on mobile size: VerificationSummaryCard is NOT rendered
      expect(find.byType(VerificationSummaryCard), findsNothing);
      expect(find.text('Fact-Checked Claims (2)'), findsOneWidget);

      // 2. Switch to Overview Tab on mobile size: VerificationSummaryCard is NOT rendered
      await tester.tap(find.byKey(const Key('tab_overview')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.byType(VerificationSummaryCard), findsNothing);
      expect(find.text('EXECUTIVE OVERVIEW'), findsOneWidget);

      // 3. Switch to Conclusion Tab on mobile size: VerificationSummaryCard is NOT rendered
      await tester.tap(find.byKey(const Key('tab_conclusion')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.byType(VerificationSummaryCard), findsNothing);
    });

    testWidgets('renders professional verdict pill colors for partially verified, mostly verified, false, and caution', (tester) async {
      tester.view.physicalSize = const Size(412, 892);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final controller = Get.put(VideoController(), tag: testVideo.id);
      controller.factCheckData.value = {
        'state': 'COMPLETED',
        'truthScore': 65.0,
        'trustScore': 65.0,
        'confidence': 0.90,
        'claimCount': 5,
        'verifiedCount': 2,
        'cautionCount': 2,
        'falseCount': 1,
        'claims': [
          {
            'claim': 'Fully confirmed claim',
            'verdict': 'verified',
            'status': 'verified',
          },
          {
            'claim': 'Mostly verified claim',
            'verdict': 'mostly_true',
            'status': 'mostly_true',
          },
          {
            'claim': 'Partially verified claim with nuances',
            'verdict': 'partially_verified',
            'status': 'partially_verified',
          },
          {
            'claim': 'Cautionary disputed claim',
            'verdict': 'caution',
            'status': 'caution',
          },
          {
            'claim': 'False claim debunked by evidence',
            'verdict': 'false',
            'status': 'false',
          },
        ],
        'uiReport': testUiReport.toMap(),
      };

      await tester.pumpWidget(
        GetMaterialApp(
          home: VideoAnalysisScreen(
            video: testVideo,
            controller: controller,
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Verify all professional verdict labels are present and correctly rendered
      expect(find.text('Verified'), findsWidgets);
      expect(find.text('Mostly Verified'), findsOneWidget);
      expect(find.text('Partially Verified'), findsOneWidget);
      expect(find.text('Caution'), findsWidgets);
      expect(find.text('False'), findsWidgets);
    });

    testWidgets('renders Overview tab on narrow 320px viewport without RenderFlex overflow', (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final controller = Get.put(VideoController(), tag: testVideo.id);
      controller.factCheckData.value = {
        'state': 'COMPLETED',
        'truthScore': 85.0,
        'trustScore': 85.0,
        'confidence': 0.95,
        'claimCount': 2,
        'verifiedCount': 1,
        'cautionCount': 1,
        'falseCount': 0,
        'claims': [
          {
            'claim': 'Verified historical assertion',
            'verdict': 'verified',
            'status': 'verified',
            'explanation': 'Supported by authoritative archived records.',
          },
          {
            'claim': 'Disputed estimate',
            'verdict': 'caution',
            'status': 'caution',
            'explanation': 'Requires further statistical verification.',
          },
        ],
        'sources': [
          {
            'name': 'Primary Source One',
            'url': 'https://example.com/one',
            'authorityScore': 0.9,
          },
          {
            'name': 'Primary Source Two',
            'url': 'https://example.com/two',
            'authorityScore': 0.85,
          },
        ],
        'uiReport': testUiReport.toMap(),
      };

      await tester.pumpWidget(
        GetMaterialApp(
          home: VideoAnalysisScreen(
            video: testVideo,
            controller: controller,
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Switch to Overview tab where _buildMostValuableSourcesCard and _buildClaimsOverviewCard render
      await tester.tap(find.text('Overview'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(tester.takeException(), isNull);
      expect(find.text('MOST VALUABLE SOURCES & CITATIONS', skipOffstage: false), findsOneWidget);
      expect(find.text('CLAIMS OVERVIEW & KEY FINDINGS', skipOffstage: false), findsOneWidget);
    });
  });
}


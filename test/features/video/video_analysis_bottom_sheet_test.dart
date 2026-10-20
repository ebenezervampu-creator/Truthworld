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
import 'package:truthworld/features/video/presentation/widgets/video_analysis_bottom_sheet.dart';

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
    'conclusion': 'Commercially produced unfertilized eggs contain no embryo or cellular life, classifying them as vegetarian biologically while culturally contested.',
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
    trustScore: 88.0,
    visibility: 'public',
    uiReport: testUiReport,
  );

  group('VideoAnalysisBottomSheet Three-Tab Navigation Tests', () {
    testWidgets('renders Fact-Claims, Overview, and Conclusion tabs in tab bar', (tester) async {
      final controller = Get.put(VideoController(), tag: testVideo.id);
      controller.factCheckData.value = {
        'trustScore': 88.0,
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
          home: Scaffold(
            body: VideoAnalysisBottomSheet(
              video: testVideo,
              controller: controller,
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Verify all 3 tabs are present in the tab bar
      expect(find.byKey(const Key('tab_claims')), findsOneWidget);
      expect(find.byKey(const Key('tab_overview')), findsOneWidget);
      expect(find.byKey(const Key('tab_conclusion')), findsOneWidget);

      // Default tab is Fact-Claims (index 0)
      expect(find.text('Fact-Checked Claims (1)'), findsOneWidget);
    });

    testWidgets('navigates to Conclusion tab and renders conclusion with supporting sources', (tester) async {
      final controller = Get.put(VideoController(), tag: testVideo.id);
      controller.factCheckData.value = {
        'trustScore': 88.0,
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
          home: Scaffold(
            body: VideoAnalysisBottomSheet(
              video: testVideo,
              controller: controller,
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Tap the Conclusion tab (index 2)
      await tester.tap(find.byKey(const Key('tab_conclusion')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Verify Conclusion tab content
      expect(find.text('VERIFIED CONCLUSION'), findsOneWidget);
      expect(
        find.textContaining('Commercially produced unfertilized eggs contain no embryo or cellular life'),
        findsOneWidget,
      );
      // Sources are housed in dedicated Sources tab; verify they are absent from conclusion tab
      expect(find.text('SUPPORTING SOURCES & CITATIONS (2)'), findsNothing);
      expect(find.textContaining('Fact-Claims'), findsOneWidget);
      expect(find.text('Overview'), findsWidgets);
    });

    testWidgets('navigates to Overview tab and verifies seamless multi-tab switching', (tester) async {
      final controller = Get.put(VideoController(), tag: testVideo.id);
      controller.factCheckData.value = {
        'trustScore': 88.0,
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
          home: Scaffold(
            body: VideoAnalysisBottomSheet(
              video: testVideo,
              controller: controller,
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Switch to Overview tab (index 1)
      await tester.tap(find.byKey(const Key('tab_overview')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('EXECUTIVE OVERVIEW'), findsOneWidget);

      // Switch back to Fact-Claims (index 0)
      await tester.tap(find.byKey(const Key('tab_claims')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Fact-Checked Claims (1)'), findsOneWidget);
    });

    testWidgets('renders and navigates to Opinions & Beliefs tab when opinion claims are present', (tester) async {
      final controller = Get.put(VideoController(), tag: testVideo.id);
      controller.factCheckData.value = {
        'trustScore': 88.0,
        'claims': [
          {
            'claim': 'Unfertilized commercial eggs do not possess embryonic viability.',
            'verdict': 'verified',
            'confidence': 0.96,
            'explanation': 'Confirmed by poultry biological reproduction guidelines.',
          },
          {
            'claim': 'A purely lacto-vegetarian diet brings inner spiritual tranquility.',
            'verdict': 'opinion',
            'nature': 'OPINION',
            'confidence': 0.90,
            'explanation': 'Personal philosophical conviction and lifestyle perspective.',
          },
        ],
        'uiReport': testUiReport.toMap(),
      };

      await tester.pumpWidget(
        GetMaterialApp(
          home: Scaffold(
            body: VideoAnalysisBottomSheet(
              video: testVideo,
              controller: controller,
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Verify Opinions tab is present
      expect(find.byKey(const Key('tab_opinions')), findsOneWidget);

      // Tap Opinions tab
      await tester.tap(find.byKey(const Key('tab_opinions')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Verify Opinions tab content
      expect(find.text('Subjective Perspectives & Beliefs'), findsOneWidget);
      expect(find.text('A purely lacto-vegetarian diet brings inner spiritual tranquility.'), findsOneWidget);
    });

    testWidgets('renders and navigates to Chapters & Topics tab when chapters are present', (tester) async {
      final controller = Get.put(VideoController(), tag: testVideo.id);
      controller.factCheckData.value = {
        'trustScore': 88.0,
        'claims': [
          {
            'claim': 'Unfertilized commercial eggs do not possess embryonic viability.',
            'verdict': 'verified',
            'confidence': 0.96,
            'explanation': 'Confirmed by poultry biological reproduction guidelines.',
          },
        ],
        'chapters': [
          {
            'title': 'Biological Criteria of Eggs',
            'timestamp': 0,
            'description': 'Cellular composition and fertilization science.',
          },
          {
            'title': 'Culinary & Cultural Classifications',
            'timestamp': 120,
            'description': 'Perspectives across global culinary traditions.',
          },
        ],
        'uiReport': testUiReport.toMap(),
      };

      await tester.pumpWidget(
        GetMaterialApp(
          home: Scaffold(
            body: VideoAnalysisBottomSheet(
              video: testVideo,
              controller: controller,
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Verify Chapters tab is present
      expect(find.byKey(const Key('tab_chapters')), findsOneWidget);

      // Tap Chapters tab
      await tester.tap(find.byKey(const Key('tab_chapters')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Verify Chapters tab content
      expect(find.text('Interactive Timeline Chapters'), findsOneWidget);
      expect(find.text('Biological Criteria of Eggs'), findsOneWidget);
      expect(find.text('Culinary & Cultural Classifications'), findsOneWidget);
    });
  });
}

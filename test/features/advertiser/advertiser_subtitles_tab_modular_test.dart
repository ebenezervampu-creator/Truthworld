import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/ad_service.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/features/advertiser/presentation/controllers/advertiser_portal_controller.dart';
import 'package:truthworld/features/advertiser/presentation/views/tabs/advertiser_subtitles_tab.dart';
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
    if (!Get.isRegistered<AdService>()) {
      Get.put<AdService>(AdService(), permanent: true);
    }
    final uid = AuthService.to.uid;
    final ad = AdItem(
      id: 'test_ad_1',
      userId: uid,
      title: 'Acme Super Ad',
      advertiser: 'Acme Corp',
      description: 'Amazing products',
      imageUrl: 'https://example.com/img.jpg',
      ctaText: 'Buy Now',
      ctaTarget: 'https://example.com',
      gradientColors: const [Color(0xFF2563EB), Color(0xFF7C3AED)],
      videoUrl: 'https://example.com/video.mp4',
      isSkippableAd: true,
      subtitles: const {
        'en': 'https://example.com/en.vtt',
        'es': 'https://example.com/es.vtt',
      },
    );
    AdService.to.customCampaigns.assignAll([ad]);
  });

  tearDown(Get.reset);

  void setDesktopSize(WidgetTester tester) {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  void setMobileSize(WidgetTester tester) {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  AdItem getTestAd() => AdService.to.customCampaigns.first;

  group('AdvertiserSubtitlesSidebar Tests', () {
    testWidgets('renders campaign list and selects ad on tap', (tester) async {
      setDesktopSize(tester);
      final controller = Get.put(AdvertiserPortalController());

      await tester.pumpWidget(
        GetMaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 300,
              child: AdvertiserSubtitlesSidebar(
                controller: controller,
                campaigns: [getTestAd()],
              ),
            ),
          ),
        ),
      );

      expect(find.text('Select Video Ad to Translate'), findsOneWidget);
      expect(find.text('Acme Super Ad'), findsOneWidget);
      expect(find.text('2 Language tracks'), findsOneWidget);

      await tester.tap(find.text('Acme Super Ad'));
      await tester.pumpAndSettle();

      expect(controller.selectedAdForSubtitles.value?.id, equals('test_ad_1'));
    });
  });

  group('AdvertiserSubtitleCueRow Tests', () {
    testWidgets('renders cue inputs and responds to text changes', (tester) async {
      final controller = Get.put(AdvertiserPortalController());
      controller.currentSubtitleCues.value = [
        {
          'id': 'cue_1',
          'startTime': '00:00:01.000',
          'endTime': '00:00:05.000',
          'text': 'Initial subtitle text',
        },
      ];

      await tester.pumpWidget(
        GetMaterialApp(
          home: Scaffold(
            body: AdvertiserSubtitleCueRow(
              controller: controller,
              index: 0,
              cue: controller.currentSubtitleCues.first,
            ),
          ),
        ),
      );

      expect(find.text('Start Time'), findsOneWidget);
      expect(find.text('End Time'), findsOneWidget);
      expect(find.text('Initial subtitle text'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();

      expect(controller.currentSubtitleCues.isEmpty, isTrue);
    });
  });

  group('AdvertiserSubtitlesEditor Tests', () {
    testWidgets('renders empty placeholder when no ad is selected', (tester) async {
      final controller = Get.put(AdvertiserPortalController());
      controller.selectedAdForSubtitles.value = null;

      await tester.pumpWidget(
        GetMaterialApp(
          home: Scaffold(
            body: AdvertiserSubtitlesEditor(controller: controller),
          ),
        ),
      );

      expect(
        find.text('Select a video campaign from the list to begin editing subtitles.'),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.subtitles_outlined), findsOneWidget);
    });

    testWidgets('renders editor with selected ad and adds cue', (tester) async {
      setDesktopSize(tester);
      final controller = Get.put(AdvertiserPortalController());
      controller.selectedAdForSubtitles.value = getTestAd();
      controller.currentSubtitleCues.clear();

      await tester.pumpWidget(
        GetMaterialApp(
          home: Scaffold(
            body: AdvertiserSubtitlesEditor(controller: controller),
          ),
        ),
      );

      expect(find.text('Acme Super Ad'), findsOneWidget);
      expect(find.text('Upload Subtitles'), findsOneWidget);
      expect(find.text('Save Track'), findsOneWidget);
      expect(find.text('No subtitle cues defined.'), findsOneWidget);

      await tester.tap(find.text('Add Cue'));
      await tester.pumpAndSettle();

      expect(controller.currentSubtitleCues.length, equals(1));
      expect(find.byType(AdvertiserSubtitleCueRow), findsOneWidget);
    });
  });

  group('AdvertiserSubtitlesTab Responsive Tests', () {
    testWidgets('renders desktop side-by-side layout', (tester) async {
      setDesktopSize(tester);
      final controller = Get.put(AdvertiserPortalController());

      await tester.pumpWidget(
        GetMaterialApp(
          home: Scaffold(
            body: AdvertiserSubtitlesTab(controller: controller),
          ),
        ),
      );

      expect(find.byType(AdvertiserSubtitlesSidebar), findsOneWidget);
      expect(find.byType(AdvertiserSubtitlesEditor), findsOneWidget);
    });

    testWidgets('renders mobile stack and handles back button navigation', (tester) async {
      setMobileSize(tester);
      final controller = Get.put(AdvertiserPortalController());
      controller.selectedAdForSubtitles.value = getTestAd();

      await tester.pumpWidget(
        GetMaterialApp(
          home: Scaffold(
            body: AdvertiserSubtitlesTab(controller: controller),
          ),
        ),
      );

      expect(find.text('Back to Ads List'), findsOneWidget);
      expect(find.byType(AdvertiserSubtitlesEditor), findsOneWidget);

      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      expect(controller.selectedAdForSubtitles.value, isNull);
      expect(find.byType(AdvertiserSubtitlesSidebar), findsOneWidget);
    });
  });
}

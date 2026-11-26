import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/services/connectivity_service.dart';
import 'package:truthworld/data/models/channel.dart';
import 'package:truthworld/features/channel/presentation/controllers/channel_controller_unified.dart';
import 'package:truthworld/features/channel/presentation/views/channel/channel_description_screen.dart';
import 'package:truthworld/features/channel/presentation/views/channel/details/channel_header_widget.dart';
import 'package:truthworld/routes/app_routes.dart';

import '../../test_helpers/mock_firebase.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
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

  final sampleChannel = Channel.fromMap({
    'name': 'TruthWorld Central',
    'nameLowercase': 'truthworld central',
    'handle': '@truthcentral',
    'handleLowercase': '@truthcentral',
    'description':
        'Official TruthWorld broadcast channel bringing verified reporting and deep investigations.\nVisit https://truthworld.ai and follow us on Twitter.',
    'avatarUrl': 'https://example.com/avatar.jpg',
    'bannerUrl': 'https://example.com/banner.jpg',
    'subscriberCount': 125000,
    'videoCount': 84,
    'isVerified': true,
    'country': 'United States',
    'customUrl': 'https://truthworld.ai/@truthcentral',
    'socialLinks': {
      'website': 'https://truthworld.ai',
      'twitter': 'https://twitter.com/truthcentral',
      'youtube': 'https://youtube.com/@truthcentral',
    },
    'customLinks': [
      {'title': 'Community Forum', 'url': 'https://forum.truthworld.ai'},
    ],
    'metrics': {
      'totalViews': 1420000,
    },
    'createdAt': Timestamp.fromDate(DateTime(2024, 5, 15)),
  }, 'ch_test_999');

  group('ChannelHeaderWidget & ChannelDescriptionScreen Mobile Page Tests', () {
    testWidgets('1. isMobileSized returns true on narrow viewports and false when isDesktop is true',
        (tester) async {
      await tester.pumpWidget(
        GetMaterialApp(
          home: Builder(
            builder: (context) {
              final isMobileNarrow = ChannelHeaderWidget.isMobileSized(context, isDesktop: false);
              final isDesktopExplicit = ChannelHeaderWidget.isMobileSized(context, isDesktop: true);

              expect(isMobileNarrow, isTrue);
              expect(isDesktopExplicit, isFalse);

              return const SizedBox();
            },
          ),
        ),
      );
    });

    test('2. parseChannelLinks parses website, social links and custom links correctly', () {
      final links = ChannelHeaderWidget.parseChannelLinks(sampleChannel);

      expect(links.length, equals(4)); // website, twitter, youtube, community forum
      expect(links.any((l) => l['title'] == 'Website'), isTrue);
      expect(links.any((l) => l['title'] == 'Twitter / X'), isTrue);
      expect(links.any((l) => l['title'] == 'YouTube'), isTrue);
      expect(links.any((l) => l['title'] == 'Community Forum'), isTrue);
    });

    testWidgets('3. ChannelDescriptionScreen renders channel identity, stats, full description and links',
        (tester) async {
      final controller = Get.put(ChannelController());
      controller.selectedChannel.value = sampleChannel;

      await tester.pumpWidget(
        GetMaterialApp(
          initialRoute: AppRoutes.channelDescription,
          getPages: [
            GetPage(
              name: AppRoutes.channelDescription,
              page: () => ChannelDescriptionScreen(
                channel: sampleChannel,
                controller: controller,
              ),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // Verify Header Title 'About'
      expect(find.text('About'), findsOneWidget);

      // Verify Channel Name and Handle
      expect(find.text('TruthWorld Central'), findsWidgets);
      expect(find.text('@truthcentral'), findsWidgets);

      // Verify Metrics (Subscribers, Videos, Views)
      expect(find.text('125.0K'), findsWidgets);
      expect(find.text('84'), findsWidgets);
      expect(find.text('1.4M'), findsWidgets);

      // Verify Full Description Text
      expect(
        find.textContaining('Official TruthWorld broadcast channel bringing verified reporting'),
        findsOneWidget,
      );

      // Verify Links section is present
      expect(find.text('LINKS'), findsOneWidget);
      expect(find.text('Website'), findsOneWidget);
      expect(find.text('Community Forum'), findsOneWidget);

      // Verify Channel URL / More Info section
      expect(find.text('MORE INFO'), findsOneWidget);
      expect(find.text('United States'), findsOneWidget);
    });

    testWidgets('4. Tapping description in ChannelHeaderWidget on mobile opens ChannelDescriptionScreen',
        (tester) async {
      final controller = Get.put(ChannelController());
      controller.selectedChannel.value = sampleChannel;

      await tester.pumpWidget(
        GetMaterialApp(
          initialRoute: '/',
          getPages: [
            GetPage(
              name: '/',
              page: () => Scaffold(
                body: SingleChildScrollView(
                  child: ChannelHeaderWidget(
                    channel: sampleChannel,
                    controller: controller,
                    isDesktop: false,
                  ),
                ),
              ),
            ),
            GetPage(
              name: AppRoutes.channelDescription,
              page: () => ChannelDescriptionScreen(
                channel: sampleChannel,
                controller: controller,
              ),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // Find the "...more" text or description
      final moreFinder = find.text('...more');
      expect(moreFinder, findsOneWidget);

      await tester.tap(moreFinder);
      await tester.pumpAndSettle();

      // Expect ChannelDescriptionScreen is opened (showing 'About' in AppBar)
      expect(find.text('About'), findsOneWidget);
      expect(find.text('LINKS'), findsOneWidget);
      expect(find.text('MORE INFO'), findsOneWidget);
    });

    testWidgets('5. ChannelDescriptionScreen does not overflow with long category and country on narrow screen',
        (tester) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final longChannel = Channel.fromMap({
        'name': 'Channel With Very Long Category Information',
        'nameLowercase': 'channel with very long category information',
        'handle': '@longchannel_handle_super_extended',
        'handleLowercase': '@longchannel_handle_super_extended',
        'description': 'Channel description for overflow regression test.',
        'avatarUrl': 'https://example.com/avatar.jpg',
        'bannerUrl': 'https://example.com/banner.jpg',
        'subscriberCount': 500,
        'videoCount': 10,
        'isVerified': true,
        'country': 'United Kingdom of Great Britain and Northern Ireland',
        'category': 'Investigative Journalism, Geopolitics, OSINT Fact-Checking, Science, Technology, and World News',
        'metrics': {
          'totalViews': 50000,
        },
        'createdAt': Timestamp.fromDate(DateTime(2023, 1, 1)),
      }, 'ch_test_overflow');

      final controller = Get.put(ChannelController());
      controller.selectedChannel.value = longChannel;

      await tester.pumpWidget(
        GetMaterialApp(
          home: ChannelDescriptionScreen(
            channel: longChannel,
            controller: controller,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.textContaining('Investigative Journalism'), findsOneWidget);
      expect(find.text('United Kingdom of Great Britain and Northern Ireland'), findsOneWidget);
    });
  });
}
